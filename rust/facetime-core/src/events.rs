//! Structured diagnostic events and event dispatching for telemetry and diagnostic logging.

use serde::{Deserialize, Serialize};

/// Structured diagnostic events emitted across the FaceTime core protocol lifecycle.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "event_type", content = "payload")]
pub enum DiagnosticEvent {
    #[serde(rename = "HARD_GO_NO_GO_TRIGGERED")]
    HardGoNoGoTriggered {
        stage: String,
        http_status: u16,
        apple_status: i32,
        server_error: String,
        barrier_type: String,
        report_path: String,
    },

    #[serde(rename = "VALIDATION_PROVIDER_INITIALIZED")]
    ValidationProviderInitialized {
        provider_type: String,
        is_mock: bool,
        serial_number: String,
    },

    #[serde(rename = "VALIDATION_DATA_GENERATED")]
    ValidationDataGenerated {
        provider_type: String,
        payload_size: usize,
        is_clean_room: bool,
    },

    #[serde(rename = "RECIPIENT_LOOKUP_STARTED")]
    RecipientLookupStarted {
        raw_handle: String,
        normalized_uri: String,
    },

    #[serde(rename = "RECIPIENT_LOOKUP_SUCCESS")]
    RecipientLookupSuccess {
        handle: String,
        is_facetime_capable: bool,
        push_token_len: usize,
    },

    #[serde(rename = "RECIPIENT_LOOKUP_FAILED")]
    RecipientLookupFailed {
        handle: String,
        status_code: u64,
        reason: String,
    },

    #[serde(rename = "CALL_STATE_CHANGED")]
    CallStateChanged {
        call_id: String,
        previous_state: String,
        new_state: String,
    },
}

use std::sync::Arc;

/// Simple thread-safe event dispatcher for routing events to callbacks or logs.
#[derive(Default)]
pub struct EventDispatcher {
    handlers: std::sync::RwLock<Vec<Arc<dyn Fn(&DiagnosticEvent) + Send + Sync>>>,
}

impl EventDispatcher {
    pub fn new() -> Self {
        Self {
            handlers: std::sync::RwLock::new(Vec::new()),
        }
    }

    pub fn subscribe<F>(&self, handler: F)
    where
        F: Fn(&DiagnosticEvent) + Send + Sync + 'static,
    {
        let mut handlers = self.handlers.write().unwrap();
        handlers.push(Arc::new(handler));
    }

    pub fn emit_event(&self, event: DiagnosticEvent) {
        let handlers: Vec<_> = self.handlers.read().unwrap().clone();
        for handler in handlers {
            handler(&event);
        }
    }
}
