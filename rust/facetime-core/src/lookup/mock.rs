//! Deterministic Mock Simulation Fixtures for Apple Directory Recipient Lookup.

use std::collections::HashMap;
use crate::lookup::model::{IDSDeliveryData, IDSLookupResp, IDSLookupUser, ParsedClientData};

pub struct MockLookupResponder;

impl MockLookupResponder {
    /// Simulates genuine Apple Directory returning an enrolled, FaceTime-capable iPhone.
    pub fn simulate_facetime_capable(uri: &str) -> IDSLookupResp {
        let mut results = HashMap::new();

        // 32-byte deterministic APS push token
        let push_token = vec![
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
        ];

        // Apple relay session token
        let session_token = b"MOCK-RELAY-SESSION-TOKEN-998811".to_vec();

        // RSA 1280 DER public key mock bytes (SubjectPublicKeyInfo header + key)
        let mut rsa_der = vec![0x30, 0x82, 0x01, 0x22, 0x30, 0x0D, 0x06, 0x09];
        rsa_der.resize(162, 0x7F);

        // NGM P-256 prekey Protobuf mock
        let prekey_bytes = vec![0x0A, 0x20, 0x04; 22];

        let delivery = IDSDeliveryData {
            push_token,
            session_token,
            session_token_expires_seconds: 2592000,
            session_token_refresh_seconds: 1296000,
            client_data: ParsedClientData {
                public_message_identity_key: rsa_der,
                public_message_ngm_device_prekey_data_key: Some(prekey_bytes),
                ngm_public_identity: Some(vec![0x04; 65]),
                supports_certified_delivery_v1: true,
            },
        };

        results.insert(
            uri.to_string(),
            IDSLookupUser {
                identities: vec![delivery],
                sender_correlation_identifier: Some("UUID-CORR-778899".to_string()),
            },
        );

        IDSLookupResp {
            status: 0,
            results: Some(results),
        }
    }

    /// Simulates un-enrolled Apple Account (Status 0 with empty identities list).
    pub fn simulate_not_registered(uri: &str) -> IDSLookupResp {
        let mut results = HashMap::new();
        results.insert(
            uri.to_string(),
            IDSLookupUser {
                identities: Vec::new(),
                sender_correlation_identifier: None,
            },
        );
        IDSLookupResp {
            status: 0,
            results: Some(results),
        }
    }

    /// Simulates WebTunnel error 5206 (Response Too Large).
    pub fn simulate_webtunnel_5206_oversized() -> u16 {
        5206
    }

    /// Simulates expired session requiring re-registration (Status 6005).
    pub fn simulate_error_6005() -> IDSLookupResp {
        IDSLookupResp {
            status: 6005,
            results: None,
        }
    }
}
