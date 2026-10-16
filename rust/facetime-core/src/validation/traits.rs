//! DeviceValidationProvider trait definition and provider enum.

use std::collections::HashMap;
use std::fmt;
use std::str::FromStr;
use serde::{Deserialize, Serialize};

use super::error::ValidationError;

/// Identifies the device validation provider variant.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, uniffi::Enum)]
pub enum ValidationProviderType {
    /// Deterministic synthetic provider for offline CI and unit tests (flagged MOCK MODE).
    Mock,
    /// Reference provider utilizing upstream Rustpush logic for baseline parity auditing.
    ExistingRustpush,
    /// Clean-room Android experimental provider with zero Apple hardware, zero donor certs, zero external APIs.
    AndroidExperimental,
}

impl fmt::Display for ValidationProviderType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Mock => write!(f, "Mock"),
            Self::ExistingRustpush => write!(f, "ExistingRustpush"),
            Self::AndroidExperimental => write!(f, "AndroidExperimental"),
        }
    }
}

impl FromStr for ValidationProviderType {
    type Err = ValidationError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_lowercase().as_str() {
            "mock" => Ok(Self::Mock),
            "existingrustpush" | "rustpush" | "existing_rustpush" | "reference" => Ok(Self::ExistingRustpush),
            "androidexperimental" | "android" | "android_experimental" | "cleanroom" => Ok(Self::AndroidExperimental),
            other => Err(ValidationError::UnsupportedProviderType(format!(
                "Unsupported provider type: {}",
                other
            ))),
        }
    }
}

/// Abstract contract for device attestation, validation payload generation, and hardware header synthesis.
///
/// Implementations must be thread-safe (`Send + Sync`) and object-safe for dynamic dispatch (`Box<dyn DeviceValidationProvider>`).
pub trait DeviceValidationProvider: Send + Sync {
    /// Identifies the provider variant for telemetry, UI indicators, and logging.
    fn provider_type(&self) -> ValidationProviderType;

    /// Generates the binary `validation-data` payload submitted in Apple IDS `id-register`.
    ///
    /// # Arguments
    /// * `session_info` - Cryptographic session token or challenge received from Apple's `id-initialize-validation`.
    ///
    /// # Returns
    /// * `Ok(Vec<u8>)` - The binary validation blob.
    /// * `Err(ValidationError)` - If generation or signing fails.
    fn generate_validation_data(&self, session_info: &[u8]) -> Result<Vec<u8>, ValidationError>;

    /// Synthesizes Anisette, machine, and hardware headers required for HTTP GSA and IDS requests.
    fn get_device_headers(&self) -> HashMap<String, String>;

    /// Returns whether this provider is running in mock mode.
    /// Defaults to checking if `provider_type() == ValidationProviderType::Mock`.
    fn is_mock(&self) -> bool {
        self.provider_type() == ValidationProviderType::Mock
    }

    /// User-facing display name for diagnostic logs and Compose UI badges.
    fn display_name(&self) -> &'static str;
}
