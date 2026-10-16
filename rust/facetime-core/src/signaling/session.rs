//! CallSession lifecycle and state machine progression for outgoing FaceTime calls.

use std::sync::RwLock;
use uuid::Uuid;
use crate::bridge::error::FaceTimeCoreError;
use crate::bridge::types::{CallSession, CallState, RecipientCapabilities};
use crate::events::{DiagnosticEvent, EventDispatcher};
use crate::signaling::invite::InviteBuilder;
use crate::signaling::lookup::RecipientResolver;
use crate::signaling::relay::{QuickRelayClient, QuickRelayResponse};

pub struct SignalingManager {
    active_session: RwLock<Option<ActiveSessionContext>>,
}

pub struct ActiveSessionContext {
    pub session: CallSession,
    pub session_uuid: String,
    pub caller_handle: String,
    pub recipient_capabilities: RecipientCapabilities,
    pub caller_participant_id: u64,
    pub relay_response: Option<QuickRelayResponse>,
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

    /// Initiates outgoing FaceTime call with default caller handle
    pub fn start_call_simple(
        &self,
        recipient_handle: &str,
        dispatcher: &EventDispatcher,
    ) -> Result<CallSession, FaceTimeCoreError> {
        self.start_call(recipient_handle, "mailto:caller@example.com", dispatcher)
    }

    /// Initiates outgoing FaceTime call: Lookup -> QuickRelay -> Command 207 Invite -> RemoteRinging
    pub fn start_call(
        &self,
        recipient_handle: &str,
        caller_handle: &str,
        dispatcher: &EventDispatcher,
    ) -> Result<CallSession, FaceTimeCoreError> {
        let clean_recipient = recipient_handle.trim();
        let clean_caller = caller_handle.trim();

        if clean_recipient.is_empty() {
            return Err(FaceTimeCoreError::CallError {
                message: "Recipient handle cannot be empty".to_string(),
            });
        }
        if clean_recipient.eq_ignore_ascii_case(clean_caller) {
            return Err(FaceTimeCoreError::CallError {
                message: "Cannot initiate FaceTime call to self".to_string(),
            });
        }

        let call_uuid = Uuid::new_v4().to_string().to_uppercase();
        let call_id = format!("CALL-{}", Uuid::new_v4().simple());
        let conv_id = format!("CONV-{}", Uuid::new_v4().simple());

        // Step 1: Resolving Handle
        dispatcher.emit_event(DiagnosticEvent::CallStateChanged {
            call_id: call_id.clone(),
            previous_state: "Idle".to_string(),
            new_state: "Resolving".to_string(),
        });

        let caps = RecipientResolver::lookup(clean_recipient, dispatcher)?;
        if !caps.is_facetime_capable {
            return Err(FaceTimeCoreError::CallError {
                message: format!("Handle {} is not registered for FaceTime", clean_recipient),
            });
        }

        // Step 2: QuickRelay Allocating (Command 200)
        dispatcher.emit_event(DiagnosticEvent::CallStateChanged {
            call_id: call_id.clone(),
            previous_state: "Resolving".to_string(),
            new_state: "QuickRelayAllocating".to_string(),
        });

        let qr = QuickRelayClient::simulate_quickrelay_allocation(&call_uuid, clean_caller, clean_recipient);
        let qr_ip = "17.253.144.10".to_string();
        let qr_port = 3478u16;
        let caller_pid = qr.my_participant_id as u64;

        // Step 3: Invite Sending (Command 207)
        dispatcher.emit_event(DiagnosticEvent::CallStateChanged {
            call_id: call_id.clone(),
            previous_state: "QuickRelayAllocating".to_string(),
            new_state: "InviteSending".to_string(),
        });

        let _invite_pdu = InviteBuilder::build_outgoing_invite(
            &call_uuid,
            clean_caller,
            clean_recipient,
            caps.push_token.as_bytes(),
            caps.session_token.as_bytes(),
            &caps.prekey_data,
            &caps.public_key_der,
            &[0xAA; 32], // Caller device private key
            caller_pid,
            true, // Video call
        )?;

        // Step 4: Remote Ringing
        let ringing_state = CallState::RemoteRinging { call_id: call_id.clone() };
        let session = CallSession {
            call_id: call_id.clone(),
            conversation_id: conv_id,
            recipient_handle: clean_recipient.to_string(),
            state: ringing_state,
            quick_relay_ip: Some(qr_ip),
            quick_relay_port: Some(qr_port),
        };

        *self.active_session.write().unwrap() = Some(ActiveSessionContext {
            session: session.clone(),
            session_uuid: call_uuid,
            caller_handle: clean_caller.to_string(),
            recipient_capabilities: caps,
            caller_participant_id: caller_pid,
            relay_response: Some(qr),
        });

        dispatcher.emit_event(DiagnosticEvent::CallStateChanged {
            call_id: call_id.clone(),
            previous_state: "InviteSending".to_string(),
            new_state: "RemoteRinging".to_string(),
        });

        Ok(session)
    }

    /// Handles incoming call control messages from recipient (e.g. Decline, Answer, Leave)
    pub fn handle_control_event(
        &self,
        command_code: u8,
        action_type: u32,
        dispatcher: &EventDispatcher,
    ) -> Result<(), FaceTimeCoreError> {
        let mut session_guard = self.active_session.write().unwrap();
        let ctx = session_guard.as_mut().ok_or(FaceTimeCoreError::CallError {
            message: "No active session".to_string(),
        })?;

        let call_id = ctx.session.call_id.clone();

        let mut clear_session = false;

        match (command_code, action_type) {
            // Command 210 or Command 207 (type 3): Recipient Answered
            (210, _) | (207, 3) => {
                if matches!(ctx.session.state, CallState::RemoteRinging { .. }) {
                    ctx.session.state = CallState::Connected { call_id: call_id.clone() };
                    dispatcher.emit_event(DiagnosticEvent::CallStateChanged {
                        call_id,
                        previous_state: "RemoteRinging".to_string(),
                        new_state: "Connected".to_string(),
                    });
                }
            }
            // Command 242 (type 9): Recipient Declined
            (242, 9) => {
                clear_session = true;
                ctx.session.state = CallState::Declined {
                    call_id: call_id.clone(),
                    reason: "Recipient declined call".to_string(),
                };
                dispatcher.emit_event(DiagnosticEvent::CallStateChanged {
                    call_id,
                    previous_state: "RemoteRinging".to_string(),
                    new_state: "Declined".to_string(),
                });
            }
            // Command 208: Leave / Hangup
            (208, _) => {
                clear_session = true;
                ctx.session.state = CallState::Ended { call_id: call_id.clone() };
                dispatcher.emit_event(DiagnosticEvent::CallStateChanged {
                    call_id,
                    previous_state: "Connected".to_string(),
                    new_state: "Ended".to_string(),
                });
            }
            _ => {}
        }

        if clear_session {
            *session_guard = None;
        }

        Ok(())
    }

    /// Ends active call session (Caller Hangup)
    pub fn end_call(&self, call_id: &str, dispatcher: &EventDispatcher) -> Result<(), FaceTimeCoreError> {
        let mut session_guard = self.active_session.write().unwrap();
        let mut matched = false;
        if let Some(ref mut ctx) = *session_guard {
            if ctx.session.call_id == call_id {
                let prev_state = format!("{:?}", ctx.session.state);
                ctx.session.state = CallState::Ended { call_id: call_id.to_string() };
                dispatcher.emit_event(DiagnosticEvent::CallStateChanged {
                    call_id: call_id.to_string(),
                    previous_state: prev_state,
                    new_state: "Ended".to_string(),
                });
                matched = true;
            }
        }
        if matched {
            *session_guard = None;
        }
        Ok(())
    }

    /// Returns a copy of the active session if one exists
    pub fn get_active_session(&self) -> Option<CallSession> {
        self.active_session.read().unwrap().as_ref().map(|ctx| ctx.session.clone())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::signaling::invite::Command207Envelope;

    #[test]
    fn test_ftwiremessage_invite_validation() {
        let session_uuid = "B6D55E02-8618-477D-9D22-C119E1552317";
        let caller = "mailto:caller@example.com";
        let recipient = "mailto:recipient@example.com";

        let envelope_bytes = InviteBuilder::build_outgoing_invite(
            session_uuid,
            caller,
            recipient,
            &[0x01; 32],
            &[0x02; 16],
            &[0x04; 65],
            &[0x30; 128],
            &[0xAA; 32],
            183921049281729381,
            true,
        ).expect("Failed to build invite envelope");

        let parsed: Command207Envelope = plist::from_bytes(&envelope_bytes)
            .expect("Envelope must be valid binary plist");

        assert_eq!(parsed.command, 207);
        assert_eq!(parsed.version, 8);
        assert!(parsed.is_initiator);
        assert_eq!(parsed.targets.len(), 1);
        assert_eq!(parsed.targets[0].recipient_uri, recipient);
        assert_eq!(parsed.targets[0].encryption_type, "pair-ec");
    }

    #[test]
    fn test_state_machine_remote_ringing_progression() {
        let mgr = SignalingManager::new();
        let dispatcher = EventDispatcher::new();

        let session = mgr.start_call("mailto:recipient@example.com", "mailto:caller@example.com", &dispatcher)
            .expect("Call initiation should succeed");

        assert!(matches!(session.state, CallState::RemoteRinging { .. }));
        assert_eq!(session.quick_relay_ip.as_deref(), Some("17.253.144.10"));
        assert_eq!(session.quick_relay_port, Some(3478));

        // Simulate Recipient Decline
        mgr.handle_control_event(242, 9, &dispatcher).expect("Handle decline");
        let active = mgr.active_session.read().unwrap();
        assert!(active.is_none(), "Active session must be cleared on terminal Declined state");
    }

    #[test]
    fn test_self_call_rejection() {
        let mgr = SignalingManager::new();
        let dispatcher = EventDispatcher::new();

        let err = mgr.start_call("mailto:user@icloud.com", "mailto:user@icloud.com", &dispatcher);
        assert!(err.is_err());
        assert!(err.unwrap_err().to_string().contains("self"));
    }
}
