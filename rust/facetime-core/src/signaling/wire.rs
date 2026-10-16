//! Command 200 QuickRelay allocation and Command 207 `FTWireMessage` invite envelope wire utilities.

use crate::bridge::error::FaceTimeCoreError;
use crate::signaling::invite::InviteBuilder;
use crate::signaling::relay::QuickRelayClient;

pub struct SignalingWire;

impl SignalingWire {
    /// Formats an outgoing Command 207 invite envelope for courier transmission.
    pub fn build_invite_command_207(
        call_uuid: &str,
        caller_handle: &str,
        recipient_handle: &str,
        recipient_push_token: &str,
    ) -> Result<Vec<u8>, FaceTimeCoreError> {
        let push_bytes = if let Ok(decoded) = hex::decode(recipient_push_token) {
            decoded
        } else {
            recipient_push_token.as_bytes().to_vec()
        };

        InviteBuilder::build_outgoing_invite(
            call_uuid,
            caller_handle,
            recipient_handle,
            &push_bytes,
            b"SESSION-TOKEN-DEFAULT",
            &[0x04; 65],
            &[0x30; 128],
            &[0xAA; 32],
            183921049281729381,
            true,
        )
    }

    /// Formats an outgoing Command 200 QuickRelay allocation request.
    pub fn build_quickrelay_command_200(
        call_uuid: &str,
    ) -> Result<Vec<u8>, FaceTimeCoreError> {
        let (bytes, _) = QuickRelayClient::build_allocation_request(
            call_uuid,
            "mailto:caller@example.com",
            "mailto:recipient@example.com",
            &[0x01; 32],
            b"SESSION-TOKEN-DEFAULT",
        )?;
        Ok(bytes)
    }
}
