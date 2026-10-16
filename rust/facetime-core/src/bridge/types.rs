//! UniFFI-exported data models, records, and enum states.

use serde::{Deserialize, Serialize};
use crate::ids::stages::IdsStage;
use crate::validation::traits::ValidationProviderType;

/// Engine initialization configuration.
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct CoreConfig {
    pub environment: String,
    pub user_agent: String,
    pub courier_host: Option<String>,
    pub default_provider: ValidationProviderType,
}

/// User credentials submitted during Apple Account authentication.
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct AppleCredentials {
    pub username: String,
    pub password: String,
}

/// Active authenticated Apple Account session tokens.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, uniffi::Record)]
pub struct AuthSession {
    pub dsid: String,
    pub adsid: String,
    pub pet: String,
    pub ids_auth_token: Option<String>,
    pub ids_profile_id: Option<String>,
    pub requires_2fa: bool,
}

/// Result of executing the 7-stage IDS registration pipeline.
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct IdsRegistrationResult {
    pub stage: IdsStage,
    pub is_success: bool,
    pub is_halted_by_gate: bool,
    pub message: String,
    pub push_token: String,
    pub handles: Vec<String>,
    pub registered_services: Vec<String>,
}

/// Resolved recipient capabilities from Apple Directory (`id-query`).
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct RecipientCapabilities {
    pub handle: String,
    pub is_facetime_capable: bool,
    pub push_token: String,
    pub session_token: String,
    pub public_key_der: Vec<u8>,
    pub prekey_data: Vec<u8>,
}

/// Active FaceTime call session details.
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct CallSession {
    pub call_id: String,
    pub conversation_id: String,
    pub recipient_handle: String,
    pub state: CallState,
    pub quick_relay_ip: Option<String>,
    pub quick_relay_port: Option<u16>,
}

/// Apple Account authentication state.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, uniffi::Enum)]
pub enum AuthState {
    Idle,
    Authenticating,
    TwoFactorRequired { challenge: String },
    Authenticated { dsid: String, adsid: String },
    AuthFailed { error: String },
    LoggedOut,
}

/// APS courier persistent connection state.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, uniffi::Enum)]
pub enum ApsStatus {
    Disconnected,
    Connecting,
    Connected { host: String, push_token: String },
    ConnectionFailed { error: String },
}

/// Outgoing FaceTime call signaling session state.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, uniffi::Enum)]
pub enum CallState {
    Idle,
    Resolving { handle: String },
    QuickRelayAllocating,
    InviteSending { call_id: String },
    RemoteRinging { call_id: String },
    Connected { call_id: String },
    Declined { call_id: String, reason: String },
    Ended { call_id: String },
    Failed { call_id: String, error: String },
}

/// Structured JSONL diagnostic event record passed over FFI.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, uniffi::Record)]
pub struct DiagnosticEventJsonl {
    pub timestamp: String,
    pub subsystem: String,
    pub severity: String,
    pub event_name: String,
    pub payload_json: String,
}

impl DiagnosticEventJsonl {
    pub fn new(subsystem: &str, severity: &str, event_name: &str, payload_json: &str) -> Self {
        Self {
            timestamp: chrono::Utc::now().to_rfc3339(),
            subsystem: subsystem.to_string(),
            severity: severity.to_string(),
            event_name: event_name.to_string(),
            payload_json: payload_json.to_string(),
        }
    }
}
