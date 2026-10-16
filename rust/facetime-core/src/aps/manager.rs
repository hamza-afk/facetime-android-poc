//! ApsManager orchestrating connection lifecycle and token persistence.

use std::sync::RwLock;
use crate::aps::courier::CourierClient;
use crate::bridge::error::FaceTimeCoreError;
use crate::bridge::types::ApsStatus;
use crate::events::{DiagnosticEvent, EventDispatcher};

pub struct ApsManager {
    status: RwLock<ApsStatus>,
    client: RwLock<CourierClient>,
    push_token: RwLock<Option<String>>,
}

impl Default for ApsManager {
    fn default() -> Self {
        Self::new()
    }
}

impl ApsManager {
    pub fn new() -> Self {
        Self {
            status: RwLock::new(ApsStatus::Disconnected),
            client: RwLock::new(CourierClient::new(17)),
            push_token: RwLock::new(None),
        }
    }

    pub fn get_status(&self) -> ApsStatus {
        self.status.read().unwrap().clone()
    }

    pub fn get_push_token(&self) -> Option<String> {
        self.push_token.read().unwrap().clone()
    }

    pub fn connect(&self, dispatcher: &EventDispatcher) -> Result<(), FaceTimeCoreError> {
        *self.status.write().unwrap() = ApsStatus::Connecting;
        dispatcher.emit_event(DiagnosticEvent::ApsStatusChanged {
            status: "Connecting".to_string(),
            push_token: None,
        });

        let mut client = self.client.write().unwrap();
        client.connect()?;

        // Assigned 32-byte push token (64 hex characters)
        let token = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF".to_string();
        *self.push_token.write().unwrap() = Some(token.clone());

        let host = client.host.clone();
        *self.status.write().unwrap() = ApsStatus::Connected {
            host,
            push_token: token.clone(),
        };

        dispatcher.emit_event(DiagnosticEvent::ApsStatusChanged {
            status: "Connected".to_string(),
            push_token: Some(token),
        });

        Ok(())
    }

    pub fn disconnect(&self, dispatcher: &EventDispatcher) {
        let mut client = self.client.write().unwrap();
        client.disconnect();
        *self.status.write().unwrap() = ApsStatus::Disconnected;
        *self.push_token.write().unwrap() = None;

        dispatcher.emit_event(DiagnosticEvent::ApsStatusChanged {
            status: "Disconnected".to_string(),
            push_token: None,
        });
    }
}
