//! Authoritative FaceTimeCoreEngine implementing the UniFFI API.

use std::sync::{Arc, RwLock};
use crate::aps::ApsManager;
use crate::auth::AuthManager;
use crate::bridge::error::FaceTimeCoreError;
use crate::bridge::listener::FaceTimeCoreEventListener;
use crate::bridge::types::{
    AppleCredentials, ApsStatus, AuthSession, AuthState, CallSession, CallState, CoreConfig,
    DiagnosticEventJsonl, IdsRegistrationResult, RecipientCapabilities,
};
use crate::events::EventDispatcher;
use crate::ids::pipeline::IdsRegistrationStepper;
use crate::ids::stages::IdsStage;
use crate::signaling::SignalingManager;
use crate::validation::traits::ValidationProviderType;

pub struct EngineState {
    pub config: RwLock<Option<CoreConfig>>,
    pub listener: RwLock<Option<Arc<Box<dyn FaceTimeCoreEventListener>>>>,
    pub dispatcher: Arc<EventDispatcher>,
    pub auth_manager: Arc<AuthManager>,
    pub aps_manager: Arc<ApsManager>,
    pub ids_stepper: Arc<IdsRegistrationStepper>,
    pub signaling_manager: Arc<SignalingManager>,
}

#[derive(uniffi::Object)]
pub struct FaceTimeCoreEngine {
    state: Arc<EngineState>,
}

impl Default for FaceTimeCoreEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[uniffi::export]
impl FaceTimeCoreEngine {
    #[uniffi::constructor]
    pub fn new() -> Self {
        let dispatcher = Arc::new(EventDispatcher::new());
        let auth_manager = Arc::new(AuthManager::new());
        let aps_manager = Arc::new(ApsManager::new());
        let ids_stepper = Arc::new(IdsRegistrationStepper::new());
        let signaling_manager = Arc::new(SignalingManager::new());

        let state = Arc::new(EngineState {
            config: RwLock::new(None),
            listener: RwLock::new(None),
            dispatcher,
            auth_manager,
            aps_manager,
            ids_stepper,
            signaling_manager,
        });

        Self { state }
    }

    pub fn init_engine(
        &self,
        config: CoreConfig,
        listener: Box<dyn FaceTimeCoreEventListener>,
    ) -> Result<(), FaceTimeCoreError> {
        *self.state.config.write().unwrap() = Some(config);

        let listener_arc = Arc::new(listener);
        let cb_listener = Arc::clone(&listener_arc);
        self.state.dispatcher.subscribe(move |event| {
            let json = serde_json::to_string(event).unwrap_or_default();
            let jsonl = DiagnosticEventJsonl::new("ENGINE", "INFO", "DIAGNOSTIC_EVENT", &json);
            cb_listener.on_diagnostic_event(jsonl);
        });

        *self.state.listener.write().unwrap() = Some(listener_arc);
        Ok(())
    }

    pub fn authenticate_apple_account(
        &self,
        credentials: AppleCredentials,
    ) -> Result<AuthSession, FaceTimeCoreError> {
        let res = self.state.auth_manager.authenticate(credentials, &self.state.dispatcher)?;
        if let Some(ref l) = *self.state.listener.read().unwrap() {
            l.on_auth_state_changed(self.state.auth_manager.get_state());
        }
        Ok(res)
    }

    pub fn submit_two_factor_code(
        &self,
        code: String,
    ) -> Result<AuthSession, FaceTimeCoreError> {
        let res = self.state.auth_manager.submit_2fa(code, &self.state.dispatcher)?;
        if let Some(ref l) = *self.state.listener.read().unwrap() {
            l.on_auth_state_changed(self.state.auth_manager.get_state());
        }
        Ok(res)
    }

    pub fn connect_aps_courier(&self) -> Result<(), FaceTimeCoreError> {
        self.state.aps_manager.connect(&self.state.dispatcher)?;
        if let Some(ref l) = *self.state.listener.read().unwrap() {
            l.on_aps_state_changed(self.state.aps_manager.get_status());
        }
        Ok(())
    }

    pub fn register_ids_pipeline(
        &self,
        provider: ValidationProviderType,
    ) -> Result<IdsRegistrationResult, FaceTimeCoreError> {
        let dsid = self.state.auth_manager.get_session().map(|s| s.dsid).unwrap_or_else(|| "1892837492".to_string());
        let push_token = self.state.aps_manager.get_push_token().unwrap_or_default();

        let res = self.state.ids_stepper.execute_pipeline(provider, &dsid, &push_token, &self.state.dispatcher)?;
        if let Some(ref l) = *self.state.listener.read().unwrap() {
            l.on_ids_state_changed(res.stage.clone());
        }
        Ok(res)
    }

    pub fn lookup_recipient(
        &self,
        handle: String,
    ) -> Result<RecipientCapabilities, FaceTimeCoreError> {
        crate::signaling::lookup::RecipientResolver::lookup(&handle, &self.state.dispatcher)
    }

    pub fn start_facetime_call(
        &self,
        recipient_handle: String,
    ) -> Result<CallSession, FaceTimeCoreError> {
        let session = self.state.signaling_manager.start_call(&recipient_handle, &self.state.dispatcher)?;
        if let Some(ref l) = *self.state.listener.read().unwrap() {
            l.on_call_state_changed(session.call_id.clone(), session.state.clone());
        }
        Ok(session)
    }

    pub fn end_facetime_call(&self, call_id: String) -> Result<(), FaceTimeCoreError> {
        self.state.signaling_manager.end_call(&call_id, &self.state.dispatcher)?;
        if let Some(ref l) = *self.state.listener.read().unwrap() {
            l.on_call_state_changed(call_id.clone(), CallState::Ended { call_id });
        }
        Ok(())
    }
}
