//! UniFFI callback interface for event listening.

use super::types::{ApsStatus, AuthState, CallState, DiagnosticEventJsonl};
use crate::ids::stages::IdsStage;

/// Callback interface implemented in Kotlin to receive asynchronous engine events.
#[uniffi::export(callback_interface)]
pub trait FaceTimeCoreEventListener: Send + Sync + 'static {
    /// Dispatched when Apple Account authentication state transitions.
    fn on_auth_state_changed(&self, state: AuthState);

    /// Dispatched when APS courier connection status changes.
    fn on_aps_state_changed(&self, status: ApsStatus);

    /// Dispatched when the 7-stage IDS registration stepper advances or halts.
    fn on_ids_state_changed(&self, stage: IdsStage);

    /// Dispatched when an active FaceTime call session transitions.
    fn on_call_state_changed(&self, call_id: String, state: CallState);

    /// Dispatched for every structured diagnostic telemetry event.
    fn on_diagnostic_event(&self, event: DiagnosticEventJsonl);
}
