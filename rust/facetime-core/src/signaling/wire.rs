//! Command 200 QuickRelay allocation and Command 207 `FTWireMessage` invite envelope.

use crate::bridge::error::FaceTimeCoreError;

pub struct SignalingWire;

impl SignalingWire {
    /// Formats an outgoing Command 207 invite envelope for courier transmission.
    pub fn build_invite_command_207(
        call_uuid: &str,
        caller_handle: &str,
        recipient_handle: &str,
        _recipient_push_token: &str,
    ) -> Result<Vec<u8>, FaceTimeCoreError> {
        // Envelopes FTWireMessage with Command 207
        let xml = format!(
            "<dict><key>c</key><integer>207</integer><key>sP</key><string>{}</string><key>tP</key><string>{}</string><key>callId</key><string>{}</string></dict>",
            caller_handle, recipient_handle, call_uuid
        );
        Ok(xml.into_bytes())
    }

    /// Formats an outgoing Command 200 QuickRelay allocation request.
    pub fn build_quickrelay_command_200(
        call_uuid: &str,
    ) -> Result<Vec<u8>, FaceTimeCoreError> {
        let xml = format!(
            "<dict><key>c</key><integer>200</integer><key>callId</key><string>{}</string><key>qat</key><integer>3</integer><key>qgmc</key><integer>2</integer></dict>",
            call_uuid
        );
        Ok(xml.into_bytes())
    }
}
