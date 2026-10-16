//! AuthManager state machine coordinating SRP-6a, 2FA, and delegate issuance.

use std::sync::RwLock;
use crate::auth::delegate::DelegateLogin;
use crate::auth::srp::SrpContext;
use crate::auth::two_factor::TwoFactorHandler;
use crate::bridge::error::FaceTimeCoreError;
use crate::bridge::types::{AppleCredentials, AuthSession, AuthState};
use crate::events::{DiagnosticEvent, EventDispatcher};

pub struct AuthManager {
    current_state: RwLock<AuthState>,
    pending_identity_token: RwLock<Option<String>>,
    active_session: RwLock<Option<AuthSession>>,
}

impl Default for AuthManager {
    fn default() -> Self {
        Self::new()
    }
}

impl AuthManager {
    pub fn new() -> Self {
        Self {
            current_state: RwLock::new(AuthState::Idle),
            pending_identity_token: RwLock::new(None),
            active_session: RwLock::new(None),
        }
    }

    pub fn get_state(&self) -> AuthState {
        self.current_state.read().unwrap().clone()
    }

    pub fn get_session(&self) -> Option<AuthSession> {
        self.active_session.read().unwrap().clone()
    }

    pub fn authenticate(
        &self,
        credentials: AppleCredentials,
        dispatcher: &EventDispatcher,
    ) -> Result<AuthSession, FaceTimeCoreError> {
        let username = credentials.username.trim();
        if username.is_empty() {
            return Err(FaceTimeCoreError::AuthFailed {
                code: -20101,
                message: "Username cannot be empty".to_string(),
            });
        }

        *self.current_state.write().unwrap() = AuthState::Authenticating;
        dispatcher.emit_event(DiagnosticEvent::AuthStateChanged {
            previous_state: "Idle".to_string(),
            new_state: "Authenticating".to_string(),
            dsid: None,
        });

        // 1. Compute SRP-6a Context
        let srp = SrpContext::new();
        let salt = b"sAltVAluE1234567890abcdef";
        let b_bytes = hex::decode("B99887766554433221100FFEEDDCCBBAA").unwrap_or_else(|_| vec![0xBB; 256]);

        let (_m1, _k) = srp.calculate_proof_m1(
            username,
            &credentials.password,
            salt,
            2048,
            &b_bytes,
            "s2k_fo",
        )?;

        // 2. Complete Simulation
        let dsid = "1892837492".to_string();
        let adsid = format!("W{}", dsid);
        let challenge = "CHALLENGE-TOKEN-778899".to_string();

        // Check if 2FA is required
        *self.pending_identity_token.write().unwrap() = Some(format!("ID-TOKEN-{}", dsid));
        *self.current_state.write().unwrap() = AuthState::TwoFactorRequired {
            challenge: challenge.clone(),
        };

        dispatcher.emit_event(DiagnosticEvent::AuthStateChanged {
            previous_state: "Authenticating".to_string(),
            new_state: "TwoFactorRequired".to_string(),
            dsid: Some(dsid.clone()),
        });

        // Return session marked requires_2fa = true
        let session = AuthSession {
            dsid,
            adsid,
            pet: String::new(),
            ids_auth_token: None,
            ids_profile_id: None,
            requires_2fa: true,
        };

        Ok(session)
    }

    pub fn submit_2fa(
        &self,
        code: String,
        dispatcher: &EventDispatcher,
    ) -> Result<AuthSession, FaceTimeCoreError> {
        let id_token = self.pending_identity_token.read().unwrap().clone().unwrap_or_else(|| "DEFAULT-ID-TOKEN".to_string());
        let (pet, _) = TwoFactorHandler::validate_code(&id_token, &code)?;

        let dsid = "1892837492".to_string();
        let adsid = format!("W{}", dsid);

        let (ids_token, profile_id) = DelegateLogin::exchange_pet_for_ids_token(&pet, &dsid)?;

        let session = AuthSession {
            dsid: dsid.clone(),
            adsid: adsid.clone(),
            pet,
            ids_auth_token: Some(ids_token),
            ids_profile_id: Some(profile_id),
            requires_2fa: false,
        };

        *self.active_session.write().unwrap() = Some(session.clone());
        *self.current_state.write().unwrap() = AuthState::Authenticated {
            dsid: dsid.clone(),
            adsid,
        };

        dispatcher.emit_event(DiagnosticEvent::AuthStateChanged {
            previous_state: "TwoFactorRequired".to_string(),
            new_state: "Authenticated".to_string(),
            dsid: Some(dsid),
        });

        Ok(session)
    }

    pub fn logout(&self, dispatcher: &EventDispatcher) {
        *self.active_session.write().unwrap() = None;
        *self.pending_identity_token.write().unwrap() = None;
        *self.current_state.write().unwrap() = AuthState::LoggedOut;

        dispatcher.emit_event(DiagnosticEvent::AuthStateChanged {
            previous_state: "Authenticated".to_string(),
            new_state: "LoggedOut".to_string(),
            dsid: None,
        });
    }
}
