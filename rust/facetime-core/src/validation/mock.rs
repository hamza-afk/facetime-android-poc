//! Deterministic Mock Validation Provider for offline testing and CI.

use std::collections::HashMap;
use log::warn;
use super::error::ValidationError;
use super::traits::{DeviceValidationProvider, ValidationProviderType};

/// Maximum permissible session info size for boundary testing (10MB).
pub const MAX_SESSION_INFO_BYTES: usize = 10 * 1024 * 1024;

/// Canonical deterministic mock validation data payload.
pub const MOCK_VALIDATION_DATA_BYTES: &[u8] = b"DETERMINISTIC_MOCK_VALIDATION_BYTES";

/// MockValidationProvider produces deterministic synthetic validation data and headers.
/// Explicitly flagged as `MOCK MODE` in UI indicators, logging tags, and event payloads.
#[derive(Debug, Clone)]
pub struct MockValidationProvider {
    device_id: String,
    serial_number: String,
}

impl MockValidationProvider {
    pub fn new() -> Self {
        Self {
            device_id: "MOCK-DEVICE-00000000-0000".to_string(),
            serial_number: "MOCK-SERIAL-0000".to_string(),
        }
    }
}

impl Default for MockValidationProvider {
    fn default() -> Self {
        Self::new()
    }
}

impl DeviceValidationProvider for MockValidationProvider {
    fn provider_type(&self) -> ValidationProviderType {
        ValidationProviderType::Mock
    }

    fn generate_validation_data(&self, session_info: &[u8]) -> Result<Vec<u8>, ValidationError> {
        // Enforce boundary check
        if session_info.len() > MAX_SESSION_INFO_BYTES {
            return Err(ValidationError::OversizedSessionInfo {
                size: session_info.len(),
                max_allowed: MAX_SESSION_INFO_BYTES,
            });
        }

        warn!("[MOCK MODE] MockValidationProvider::generate_validation_data invoked (synthetic payload returned)");
        Ok(MOCK_VALIDATION_DATA_BYTES.to_vec())
    }

    fn get_device_headers(&self) -> HashMap<String, String> {
        let mut headers = HashMap::new();
        // Mandatory MOCK MODE indicator headers
        headers.insert("X-Validation-Mode".to_string(), "MOCK_MODE".to_string());
        headers.insert("X-Mock-Client".to_string(), "True".to_string());
        headers.insert("X-Mock-Device-ID".to_string(), self.device_id.clone());
        headers.insert("X-Apple-I-SRL-NO".to_string(), self.serial_number.clone());

        // Deterministic synthetic Anisette headers
        headers.insert("X-Apple-I-MD".to_string(), "TU9DS19BTklTRVRURV9EQVRB".to_string());
        headers.insert("X-Apple-I-MD-M".to_string(), "TU9DS19NQUNISU5FX0lE".to_string());
        headers.insert("X-Apple-I-MD-RINFO".to_string(), "17106176".to_string());
        headers.insert("X-Apple-I-MD-LU".to_string(), "00000000-0000-0000-0000-000000000000".to_string());
        headers.insert("X-Apple-I-Client-Time".to_string(), "2026-10-16T00:00:00Z".to_string());
        headers.insert("X-Apple-I-TimeZone".to_string(), "UTC".to_string());

        headers
    }

    fn is_mock(&self) -> bool {
        true
    }

    fn display_name(&self) -> &'static str {
        "Mock Validation Provider (Deterministic / Offline)"
    }
}
