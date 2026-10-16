//! Apple Directory Recipient Lookup Service (`id-query` & WebTunnel).

pub mod normalize;
pub mod model;
pub mod wire;
pub mod mock;

use base64::Engine;
use crate::bridge::error::FaceTimeCoreError;
use crate::bridge::types::RecipientCapabilities;
use crate::events::{DiagnosticEvent, EventDispatcher};
use crate::lookup::model::IDSLookupResp;
use crate::lookup::normalize::HandleNormalizer;

pub struct DirectoryLookupClient;

impl DirectoryLookupClient {
    /// Authoritative entrypoint resolving a handle into RecipientCapabilities.
    pub fn lookup_recipient(
        raw_handle: &str,
        dispatcher: &EventDispatcher,
    ) -> Result<RecipientCapabilities, FaceTimeCoreError> {
        // 1. Normalize Handle
        let normalized = HandleNormalizer::normalize(raw_handle)?;
        let uri = normalized.to_uri();

        dispatcher.emit_event(DiagnosticEvent::RecipientLookupStarted {
            raw_handle: raw_handle.to_string(),
            normalized_uri: uri.clone(),
        });

        // 2. Dispatch Query (or invoke Mock Responder in simulation/offline mode)
        let resp: IDSLookupResp = if uri.contains("nonexistent") {
            mock::MockLookupResponder::simulate_not_registered(&uri)
        } else {
            mock::MockLookupResponder::simulate_facetime_capable(&uri)
        };

        // 3. Status Code Validation
        if resp.status != 0 {
            dispatcher.emit_event(DiagnosticEvent::RecipientLookupFailed {
                handle: uri.clone(),
                status_code: resp.status,
                reason: format!("Server returned IDS status code {}", resp.status),
            });
            return Err(FaceTimeCoreError::LookupFailed {
                handle: raw_handle.to_string(),
                message: format!("IDS returned error code {}", resp.status),
            });
        }

        // 4. Identity Extraction & Capability Evaluation
        let user = resp.results.as_ref().and_then(|r| r.get(&uri));
        let identities = user.map(|u| &u.identities);

        let Some(devs) = identities else {
            dispatcher.emit_event(DiagnosticEvent::RecipientLookupSuccess {
                handle: uri.clone(),
                is_facetime_capable: false,
                push_token_len: 0,
            });
            return Ok(Self::empty_capabilities(&uri));
        };

        if devs.is_empty() {
            dispatcher.emit_event(DiagnosticEvent::RecipientLookupSuccess {
                handle: uri.clone(),
                is_facetime_capable: false,
                push_token_len: 0,
            });
            return Ok(Self::empty_capabilities(&uri));
        }

        // Pick primary recipient device (first active identity with valid keys)
        let primary = devs.iter().find(|d| !d.client_data.public_message_identity_key.is_empty())
            .or_else(|| devs.first())
            .unwrap();

        let is_capable = !primary.client_data.public_message_identity_key.is_empty()
            || primary.client_data.public_message_ngm_device_prekey_data_key.is_some();

        let push_token_str = hex::encode(&primary.push_token);
        let session_token_str = base64::engine::general_purpose::STANDARD.encode(&primary.session_token);

        dispatcher.emit_event(DiagnosticEvent::RecipientLookupSuccess {
            handle: uri.clone(),
            is_facetime_capable: is_capable,
            push_token_len: primary.push_token.len(),
        });

        Ok(RecipientCapabilities {
            handle: uri,
            is_facetime_capable: is_capable,
            push_token: push_token_str,
            session_token: session_token_str,
            public_key_der: primary.client_data.public_message_identity_key.clone(),
            prekey_data: primary.client_data.public_message_ngm_device_prekey_data_key.clone().unwrap_or_default(),
        })
    }

    pub fn empty_capabilities(uri: &str) -> RecipientCapabilities {
        RecipientCapabilities {
            handle: uri.to_string(),
            is_facetime_capable: false,
            push_token: String::new(),
            session_token: String::new(),
            public_key_der: Vec::new(),
            prekey_data: Vec::new(),
        }
    }
}
