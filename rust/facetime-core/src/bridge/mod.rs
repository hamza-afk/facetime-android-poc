//! UniFFI Bridge module consolidating types, listener, and errors.

pub mod error;
pub mod listener;
pub mod types;

pub use error::FaceTimeCoreError;
pub use listener::FaceTimeCoreEventListener;
pub use types::{
    AppleCredentials, ApsStatus, AuthSession, AuthState, CallSession, CallState, CoreConfig,
    DiagnosticEventJsonl, IdsRegistrationResult, RecipientCapabilities,
};
