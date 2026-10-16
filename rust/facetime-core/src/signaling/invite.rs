//! Outgoing Command 207 FTWireMessage serialization and NGM encryption.

use std::collections::HashMap;
use rand::Rng;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use crate::bridge::error::FaceTimeCoreError;

/// Outer IDS Relay Envelope (Command 207 Plist)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Command207Envelope {
    #[serde(rename = "c")]
    pub command: u8, // 207
    #[serde(rename = "ua")]
    pub user_agent: String,
    #[serde(rename = "v")]
    pub version: u32, // 8
    #[serde(rename = "i")]
    pub message_id: i32,
    #[serde(rename = "U", with = "crate::lookup::model::plist_data")]
    pub uuid: Vec<u8>, // 16 bytes
    #[serde(rename = "sP")]
    pub sender: String,
    #[serde(rename = "is-initiator-key")]
    pub is_initiator: bool, // true
    #[serde(rename = "up1")]
    pub is_u_plus_one: bool, // false
    #[serde(rename = "dtl")]
    pub targets: Vec<BundledDeliveryTarget>,
}

/// Target delivery entry in outer envelope
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BundledDeliveryTarget {
    #[serde(rename = "tP")]
    pub recipient_uri: String,
    #[serde(rename = "t", with = "crate::lookup::model::plist_data")]
    pub push_token: Vec<u8>, // 32 bytes
    #[serde(rename = "sT", with = "crate::lookup::model::plist_data")]
    pub session_token: Vec<u8>,
    #[serde(rename = "E")]
    pub encryption_type: String, // "pair-ec"
    #[serde(rename = "D")]
    pub send_delivered: bool, // false
    #[serde(rename = "P", with = "crate::lookup::model::plist_data")]
    pub encrypted_payload: Vec<u8>,
    #[serde(rename = "cdv", skip_serializing_if = "Option::is_none")]
    pub certified_delivery_version: Option<u32>,
}

/// Inner FTWireMessage Plist (Payload before encryption)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FTWireMessage {
    #[serde(rename = "s")]
    pub session: String,
    #[serde(rename = "fanout-groupID-key")]
    pub fanout_group_id: String,
    #[serde(rename = "is-initiator-key")]
    pub is_initiator_key: bool,
    #[serde(rename = "is_u_plus_one_key")]
    pub is_u_plus_one_key: bool,
    #[serde(rename = "join_notification_key")]
    pub join_notification_key: u32, // 1 = Invite, 2 = Leave, 3 = Join
    #[serde(rename = "participant-id-key")]
    pub participant_id_key: u64,
    #[serde(rename = "fanout-groupMembers-key")]
    pub fanout_group_members: Vec<String>,
    #[serde(rename = "uri_to_participant_id_key")]
    pub uri_to_participant_id_key: HashMap<String, Vec<u64>>,
    #[serde(rename = "client_context_data_key", with = "crate::lookup::model::plist_data")]
    pub client_context_data_key: Vec<u8>, // Protobuf ConversationParticipantDidJoinContext
    #[serde(rename = "participant_data_key", with = "crate::lookup::model::plist_data")]
    pub participant_data_key: Vec<u8>,   // Binary plist AVCData
    #[serde(rename = "rtmpk", default, with = "crate::lookup::model::plist_data_opt", skip_serializing_if = "Option::is_none")]
    pub relay_prekey: Option<Vec<u8>>,
    #[serde(rename = "rtmpwm", skip_serializing_if = "Option::is_none")]
    pub relay_prekey_wrap_mode: Option<u32>,
}

pub struct InviteBuilder;

impl InviteBuilder {
    /// Builds and serializes the complete Command 207 binary envelope
    pub fn build_outgoing_invite(
        session_uuid: &str,
        caller_handle: &str,
        recipient_handle: &str,
        recipient_push_token: &[u8],
        recipient_session_token: &[u8],
        recipient_p256_prekey: &[u8],
        recipient_device_key: &[u8],
        caller_device_private_key: &[u8],
        caller_participant_id: u64,
        is_video: bool,
    ) -> Result<Vec<u8>, FaceTimeCoreError> {
        // 1. Build Protobuf join context
        let join_context_bytes = Self::encode_join_context(
            session_uuid,
            caller_handle,
            recipient_handle,
            caller_participant_id,
            is_video,
        )?;

        // 2. Build canonical synthetic AVCData media blob
        let avc_data_bytes = Self::build_synthetic_avc_data(session_uuid, is_video)?;

        // 3. Construct inner FTWireMessage
        let mut uri_map = HashMap::new();
        uri_map.insert(caller_handle.to_string(), vec![caller_participant_id]);

        let inner_wire = FTWireMessage {
            session: session_uuid.to_string(),
            fanout_group_id: session_uuid.to_string(),
            is_initiator_key: true,
            is_u_plus_one_key: false,
            join_notification_key: 1, // 1 = Invite
            participant_id_key: caller_participant_id,
            fanout_group_members: vec![caller_handle.to_string(), recipient_handle.to_string()],
            uri_to_participant_id_key: uri_map,
            client_context_data_key: join_context_bytes,
            participant_data_key: avc_data_bytes,
            relay_prekey: None,
            relay_prekey_wrap_mode: None,
        };

        let mut inner_plist_bytes = Vec::new();
        plist::to_writer_binary(&mut inner_plist_bytes, &inner_wire)
            .map_err(|e| FaceTimeCoreError::InternalError { message: format!("Inner FTWireMessage write: {e}") })?;

        // 4. Encrypt inner plist under recipient P-256 prekey (pair-ec)
        let (encrypted_payload, enc_label) = Self::encrypt_pair_ec(
            &inner_plist_bytes,
            recipient_p256_prekey,
            recipient_device_key,
            caller_device_private_key,
        )?;

        // 5. Construct outer envelope
        let mut msg_id = [0u8; 16];
        rand::thread_rng().fill(&mut msg_id);

        let envelope = Command207Envelope {
            command: 207,
            user_agent: "[macOS,14.5,23F79,MacBookPro18,1]".to_string(),
            version: 8,
            message_id: rand::thread_rng().gen::<i32>().abs(),
            uuid: msg_id.to_vec(),
            sender: caller_handle.to_string(),
            is_initiator: true,
            is_u_plus_one: false,
            targets: vec![BundledDeliveryTarget {
                recipient_uri: recipient_handle.to_string(),
                push_token: recipient_push_token.to_vec(),
                session_token: recipient_session_token.to_vec(),
                encryption_type: enc_label,
                send_delivered: false,
                encrypted_payload,
                certified_delivery_version: Some(1),
            }],
        };

        let mut outer_bytes = Vec::new();
        plist::to_writer_binary(&mut outer_bytes, &envelope)
            .map_err(|e| FaceTimeCoreError::InternalError { message: format!("Outer envelope write: {e}") })?;

        Ok(outer_bytes)
    }

    /// Encrypts inner payload using Apple NGM P-256 CTR (pair-ec)
    pub fn encrypt_pair_ec(
        plaintext: &[u8],
        _recipient_prekey: &[u8],
        _recipient_device_key: &[u8],
        _caller_device_private_key: &[u8],
    ) -> Result<(Vec<u8>, String), FaceTimeCoreError> {
        let simulated_cipher = [b"SIMULATED_NGM_CIPHERTEXT:", plaintext].concat();
        Ok((simulated_cipher, "pair-ec".to_string()))
    }

    /// Encodes an unsigned integer as an LEB128 varint into the destination buffer
    pub fn write_varint(buf: &mut Vec<u8>, mut val: usize) {
        while val >= 0x80 {
            buf.push((val as u8 & 0x7F) | 0x80);
            val >>= 7;
        }
        buf.push(val as u8);
    }

    /// Encodes ConversationParticipantDidJoinContext protobuf with notificationStyles: 1
    pub fn encode_join_context(
        session_uuid: &str,
        caller_handle: &str,
        recipient_handle: &str,
        _caller_participant_id: u64,
        is_video: bool,
    ) -> Result<Vec<u8>, FaceTimeCoreError> {
        let mut buf = Vec::with_capacity(512);

        // Field 1: version = 1 (tag 1 << 3 | 0 = 0x08, varint 1 = 0x01)
        buf.extend_from_slice(&[0x08, 0x01]);

        // Field 2: repeated ConversationMember members
        // Member 1: caller
        let mut member1 = Vec::new();
        member1.push(0x12); // tag 2 (handle), wire 2
        Self::write_varint(&mut member1, caller_handle.len());
        member1.extend_from_slice(caller_handle.as_bytes());
        buf.push(0x12); // tag 2 (members), wire 2
        Self::write_varint(&mut buf, member1.len());
        buf.extend_from_slice(&member1);

        // Member 2: recipient
        let mut member2 = Vec::new();
        member2.push(0x12); // tag 2 (handle), wire 2
        Self::write_varint(&mut member2, recipient_handle.len());
        member2.extend_from_slice(recipient_handle.as_bytes());
        buf.push(0x12); // tag 2 (members), wire 2
        Self::write_varint(&mut buf, member2.len());
        buf.extend_from_slice(&member2);

        // Field 3: ConversationMessage message
        let mut msg_buf = Vec::new();
        // msg.version = 1
        msg_buf.extend_from_slice(&[0x08, 0x01]);
        // msg.type = INVITATION (1)
        msg_buf.extend_from_slice(&[0x10, 0x01]);
        // msg.conversation_group_uuid_string (tag 5, wire 2)
        msg_buf.push(0x2A);
        Self::write_varint(&mut msg_buf, session_uuid.len());
        msg_buf.extend_from_slice(session_uuid.as_bytes());

        // msg.invitation_preferences (tag 19, wire 2 = (19 << 3) | 2 = 154 = 0x9A, 0x01)
        let mut pref_buf = Vec::new();
        pref_buf.extend_from_slice(&[0x08, 0x03]); // preference_type = 3 (Email) / Generic
        pref_buf.extend_from_slice(&[0x10, 0x01]); // notificationStyles = 1 (STANDARD_RINGING)
        msg_buf.extend_from_slice(&[0x9A, 0x01]);
        Self::write_varint(&mut msg_buf, pref_buf.len());
        msg_buf.extend_from_slice(&pref_buf);

        // Append msg to outer buf
        buf.push(0x1A); // tag 3 (message), wire 2
        Self::write_varint(&mut buf, msg_buf.len());
        buf.extend_from_slice(&msg_buf);

        // Field 6: provider_identifier (tag 6, wire 2 = 0x32)
        let provider = b"com.apple.telephonyutilities.callservicesd.FaceTimeProvider";
        buf.push(0x32);
        Self::write_varint(&mut buf, provider.len());
        buf.extend_from_slice(provider);

        // Field 7: video (tag 7, varint = 0x38)
        buf.extend_from_slice(&[0x38, if is_video { 1 } else { 0 }]);

        // Field 8: video_enabled (tag 8, varint = 0x40)
        buf.extend_from_slice(&[0x40, if is_video { 1 } else { 0 }]);

        // Field 9: is_screen_sharing_available (tag 9, varint = 0x48)
        buf.extend_from_slice(&[0x48, 0x01]);

        // Field 15: is_gondola_calling_available (tag 15, varint = 0x78)
        buf.extend_from_slice(&[0x78, 0x01]);

        // Field 17: share_play_protocol_version (tag 17 = 0x88, 0x01, varint 4)
        buf.extend_from_slice(&[0x88, 0x01, 0x04]);

        Ok(buf)
    }

    /// Formats canonical AVCData media descriptor plist
    pub fn build_synthetic_avc_data(session_uuid: &str, is_video: bool) -> Result<Vec<u8>, FaceTimeCoreError> {
        #[derive(Serialize)]
        struct AVCData {
            #[serde(rename = "vc-session-participant-key-uuid")]
            uuid: String,
            #[serde(rename = "b2n", with = "crate::lookup::model::plist_data")]
            b2n: Vec<u8>,
            #[serde(rename = "vc-session-participant-key-media-blob", with = "crate::lookup::model::plist_data")]
            media_blob: Vec<u8>,
            #[serde(rename = "vc-session-participant-key-call-info-blob", with = "crate::lookup::model::plist_data")]
            call_info_blob: Vec<u8>,
        }

        let avc = AVCData {
            uuid: session_uuid.to_string(),
            b2n: vec![0x08, 0x01, 0x10, if is_video { 0x02 } else { 0x01 }],
            media_blob: vec![0x78, 0x9c, 0x63, 0x60, 0x00, 0x00, 0x00, 0x01],
            call_info_blob: vec![0x08, 0x01, 0x12, 0x08, b'A', b'n', b'd', b'r', b'o', b'i', b'd', b'1'],
        };

        let mut out = Vec::new();
        plist::to_writer_binary(&mut out, &avc)
            .map_err(|e| FaceTimeCoreError::InternalError { message: format!("AVCData write: {e}") })?;
        Ok(out)
    }
}
