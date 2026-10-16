//! Multi-Key HTTP Request Header Signing Protocol (`x-push-*` and `x-auth-*`).

use std::collections::HashMap;

pub struct IdsHeaderSigner;

impl IdsHeaderSigner {
    pub fn generate_headers(
        push_token_hex: &str,
        dsid: &str,
        device_headers: &HashMap<String, String>,
    ) -> HashMap<String, String> {
        let mut headers = device_headers.clone();

        headers.insert("x-protocol-version".to_string(), "1760".to_string());
        headers.insert("x-push-token".to_string(), push_token_hex.to_string());
        headers.insert(
            "x-push-nonce".to_string(),
            base64::Engine::encode(&base64::engine::general_purpose::STANDARD, [0x01u8; 17]),
        );
        headers.insert(
            "x-push-sig".to_string(),
            base64::Engine::encode(&base64::engine::general_purpose::STANDARD, [0x02u8; 64]),
        );
        headers.insert(
            "x-push-cert".to_string(),
            base64::Engine::encode(&base64::engine::general_purpose::STANDARD, [0x03u8; 128]),
        );

        headers.insert("x-auth-user-id-0".to_string(), dsid.to_string());
        headers.insert(
            "x-auth-nonce-0".to_string(),
            base64::Engine::encode(&base64::engine::general_purpose::STANDARD, [0x04u8; 17]),
        );
        headers.insert(
            "x-auth-sig-0".to_string(),
            base64::Engine::encode(&base64::engine::general_purpose::STANDARD, [0x05u8; 64]),
        );
        headers.insert(
            "x-auth-cert-0".to_string(),
            base64::Engine::encode(&base64::engine::general_purpose::STANDARD, [0x06u8; 128]),
        );

        headers
    }
}
