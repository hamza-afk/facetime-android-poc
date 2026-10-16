//! QuickRelay Command 200 allocation and candidate packaging.

use rand::Rng;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use crate::bridge::error::FaceTimeCoreError;

/// Outgoing Command 200 QuickRelay Allocation Request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuickRelayRequest {
    #[serde(rename = "c")]
    pub command: u8, // 200
    #[serde(rename = "ua")]
    pub user_agent: String,
    #[serde(rename = "i")]
    pub message_id: i32,
    #[serde(rename = "U", with = "crate::lookup::model::plist_data")]
    pub uuid: Vec<u8>,
    #[serde(rename = "sP")]
    pub sender: String,
    #[serde(rename = "qids", with = "crate::lookup::model::plist_data")]
    pub session_id_bytes: Vec<u8>,
    #[serde(rename = "qgid")]
    pub group_id_str: String,
    #[serde(rename = "qat")]
    pub allocation_type: u32, // 3 = Allocate Relay Node
    #[serde(rename = "qgmc")]
    pub member_count: u32,    // 2 (Caller + Recipient)
    #[serde(rename = "qv")]
    pub version: u32,         // 25
    #[serde(rename = "qr")]
    pub reason: u32,          // 0 = New Call Session
    #[serde(rename = "qai")]
    pub topic: String,        // "com.apple.private.alloy.facetime.multi"
    #[serde(rename = "dtl")]
    pub targets: Vec<QuickRelayTarget>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuickRelayTarget {
    #[serde(rename = "tP")]
    pub participant_uri: String,
    #[serde(rename = "t", with = "crate::lookup::model::plist_data")]
    pub push_token: Vec<u8>,
    #[serde(rename = "sT", with = "crate::lookup::model::plist_data")]
    pub session_token: Vec<u8>,
}

/// Incoming QuickRelay Allocation Response Plist
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuickRelayResponse {
    #[serde(rename = "U", with = "crate::lookup::model::plist_data")]
    pub for_id: Vec<u8>,
    #[serde(rename = "qrip", with = "crate::lookup::model::plist_data")]
    pub relay_ip: Vec<u8>, // 4 bytes IPv4
    #[serde(rename = "qrp")]
    pub relay_port: u16,
    #[serde(rename = "qrst", with = "crate::lookup::model::plist_data")]
    pub session_token: Vec<u8>,
    #[serde(rename = "qrsk", with = "crate::lookup::model::plist_data")]
    pub session_key: Vec<u8>, // 20 bytes
    #[serde(rename = "qids", with = "crate::lookup::model::plist_data")]
    pub session_id: Vec<u8>,
    #[serde(rename = "qrsi", with = "crate::lookup::model::plist_data")]
    pub relay_id: Vec<u8>,
    #[serde(rename = "qri")]
    pub my_participant_id: i64,
    #[serde(rename = "qal")]
    pub allocations: Vec<ParticipantAllocation>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParticipantAllocation {
    #[serde(rename = "qri")]
    pub participant_id: i64,
    #[serde(rename = "tP")]
    pub participant_uri: String,
    #[serde(rename = "t", with = "crate::lookup::model::plist_data")]
    pub push_token: Vec<u8>,
}

pub struct QuickRelayClient;

impl QuickRelayClient {
    /// Formats Command 200 request binary plist
    pub fn build_allocation_request(
        call_uuid: &str,
        caller_handle: &str,
        recipient_handle: &str,
        recipient_push_token: &[u8],
        recipient_session_token: &[u8],
    ) -> Result<(Vec<u8>, Uuid), FaceTimeCoreError> {
        let request_uuid = Uuid::new_v4();
        let session_uuid = Uuid::parse_str(call_uuid)
            .unwrap_or_else(|_| Uuid::new_v4());

        let request = QuickRelayRequest {
            command: 200,
            user_agent: "[macOS,14.5,23F79,MacBookPro18,1]".to_string(),
            message_id: rand::thread_rng().gen::<i32>().abs(),
            uuid: request_uuid.as_bytes().to_vec(),
            sender: caller_handle.to_string(),
            session_id_bytes: session_uuid.as_bytes().to_vec(),
            group_id_str: call_uuid.to_string(),
            allocation_type: 3,
            member_count: 2,
            version: 25,
            reason: 0,
            topic: "com.apple.private.alloy.facetime.multi".to_string(),
            targets: vec![QuickRelayTarget {
                participant_uri: recipient_handle.to_string(),
                push_token: recipient_push_token.to_vec(),
                session_token: recipient_session_token.to_vec(),
            }],
        };

        let mut bytes = Vec::new();
        plist::to_writer_binary(&mut bytes, &request)
            .map_err(|e| FaceTimeCoreError::InternalError { message: format!("QuickRelay request write: {e}") })?;

        Ok((bytes, request_uuid))
    }

    /// Parses Command 200 allocation response plist
    pub fn parse_allocation_response(payload: &[u8]) -> Result<QuickRelayResponse, FaceTimeCoreError> {
        plist::from_bytes(payload)
            .map_err(|e| FaceTimeCoreError::InternalError { message: format!("QuickRelay response parse: {e}") })
    }

    /// Simulates a deterministic QuickRelay allocation response for Apple relay cluster
    pub fn simulate_quickrelay_allocation(call_uuid: &str, caller_handle: &str, recipient_handle: &str) -> QuickRelayResponse {
        let session_uuid = Uuid::parse_str(call_uuid).unwrap_or_else(|_| Uuid::new_v4());
        let request_uuid = Uuid::new_v4();

        // 17.253.144.10 IPv4 bytes
        let relay_ip = vec![17, 253, 144, 10];
        let relay_port = 3478u16;

        let caller_pid = 183921049281729381i64;
        let recipient_pid = 928374819283746152i64;

        QuickRelayResponse {
            for_id: request_uuid.as_bytes().to_vec(),
            relay_ip,
            relay_port,
            session_token: b"QR-ALLOC-TOKEN-998811".to_vec(),
            session_key: vec![0x30; 20],
            session_id: session_uuid.as_bytes().to_vec(),
            relay_id: b"QR-NODE-01".to_vec(),
            my_participant_id: caller_pid,
            allocations: vec![
                ParticipantAllocation {
                    participant_id: caller_pid,
                    participant_uri: caller_handle.to_string(),
                    push_token: vec![0x01; 32],
                },
                ParticipantAllocation {
                    participant_id: recipient_pid,
                    participant_uri: recipient_handle.to_string(),
                    push_token: vec![0x02; 32],
                },
            ],
        }
    }
}
