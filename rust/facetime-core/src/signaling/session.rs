//! CallSession state progression tracking.

use std::sync::RwLock;
use crate::bridge::error::FaceTimeCoreError;
use crate::bridge::types::{CallSession, CallState};
use crate::events::{DiagnosticEvent, EventDispatcher};
use crate::signaling::lookup::RecipientResolver;
use crate::signaling::wire::SignalingWire;

pub struct SignalingManager {
    active_session: RwLock<Option<CallSession>>,
}

impl Default for SignalingManager {
    fn default() -> Self {
        Self::new()
    }
}

impl SignalingManager {
    pub fn new() -> Self {
        Self {
            active_session: RwLock::new(None),
        }
    }

    pub fn start_call(
        &self,
        recipient_handle: &str,
        dispatcher: &EventDispatcher,
    ) -> Result<CallSession, FaceTimeCoreError> {
        let call_id = format!("CALL-{}", uuid::Uuid::new_v4().simple());
        let conv_id = format!("CONV-{}", uuid::Uuid::new_v4().simple());

        // 1. Resolve Recipient
        let capabilities = RecipientResolver::lookup(recipient_handle, dispatcher)?;
        if !capabilities.is_facetime_capable {
            return Err(FaceTimeCoreError::CallError {
                message: format!("Handle {} is not registered for FaceTime", recipient_handle),
            });
        }

        // 2. Pre-allocate QuickRelay
        let qr_ip = Some("17.253.144.10".to_string());
        let qr_port = Some(3478u16);

        // 3. Dispatch Command 207 Invite
        let _pdu = SignalingWire::build_invite_command_207(
            &call_id,
            "mailto:valid.user@icloud.com",
            recipient_handle,
            &capabilities.push_token,
        )?;

        // 4. Remote Ringing
        let state = CallState::RemoteRinging {
            call_id: call_id.clone(),
        };

        let session = CallSession {
            call_id: call_id.clone(),
            conversation_id: conv_id,
            recipient_handle: recipient_handle.to_string(),
            state,
            quick_relay_ip: qr_ip,
            quick_relay_port: qr_port,
        };

        *self.active_session.write().unwrap() = Some(session.clone());

        dispatcher.emit_event(DiagnosticEvent::CallStateChanged {
            call_id: call_id.clone(),
            previous_state: "Idle".to_string(),
            new_state: "RemoteRinging".to_string(),
        });

        Ok(session)
    }

    pub fn end_call(&self, call_id: &str, dispatcher: &EventDispatcher) -> Result<(), FaceTimeCoreError> {
        let mut session = self.active_session.write().unwrap();
        if let Some(ref mut s) = *session {
            if s.call_id == call_id {
                s.state = CallState::Ended {
                    call_id: call_id.to_string(),
                };

                dispatcher.emit_event(DiagnosticEvent::CallStateChanged {
                    call_id: call_id.to_string(),
                    previous_state: "RemoteRinging".to_string(),
                    new_state: "Ended".to_string(),
                });
            }
        }
        *session = None;
        Ok(())
    }
}
