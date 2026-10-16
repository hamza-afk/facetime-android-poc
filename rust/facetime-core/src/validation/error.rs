//! Validation module error types and failure categorizations.

use thiserror::Error;

/// Errors arising during device validation generation and header synthesis.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum ValidationError {
    #[error("Session info buffer cannot be empty")]
    EmptySessionInfo,

    #[error("Session info buffer exceeds maximum allowed boundary: size {size} > max {max_allowed}")]
    OversizedSessionInfo { size: usize, max_allowed: usize },

    #[error("Insecure zero entropy detected during synthetic key generation")]
    InsecureZeroEntropy,

    #[error("Entropy generation failed: {0}")]
    EntropyGenerationFailed(String),

    #[error("Clean-room anti-cheating rule violated: {0}")]
    CleanRoomViolation(String),

    #[error("Unsupported validation provider type: {0}")]
    UnsupportedProviderType(String),

    #[error("Reference hardware configuration missing or invalid: {0}")]
    ReferenceHardwareConfigMissing(String),

    #[error("Absinthe signing or cryptographic error: {0}")]
    AbsintheSignatureError(String),

    #[error("Serialization / Plist encoding error: {0}")]
    SerializationError(String),

    #[error("Provider initialization failed: {0}")]
    InitializationFailed(String),
}

impl ValidationError {
    /// Categorizes whether the error is transient/recoverable or an unrecoverable hardware/security boundary.
    /// In accordance with E2E Tier 2 specifications (T2.F5.4), entropy generation failures and clean-room
    /// violations are unrecoverable.
    pub fn recoverable(&self) -> bool {
        match self {
            Self::EmptySessionInfo => false,
            Self::OversizedSessionInfo { .. } => false,
            Self::InsecureZeroEntropy => false,
            Self::EntropyGenerationFailed(_) => false,
            Self::CleanRoomViolation(_) => false,
            Self::UnsupportedProviderType(_) => false,
            Self::ReferenceHardwareConfigMissing(_) => false,
            Self::AbsintheSignatureError(_) => false,
            Self::SerializationError(_) => false,
            Self::InitializationFailed(_) => false,
        }
    }

    /// Machine-readable error code for structured telemetry, JSONL export, and UI error mapping.
    pub fn error_code(&self) -> &'static str {
        match self {
            Self::EmptySessionInfo => "ERR_VALIDATION_EMPTY_SESSION_INFO",
            Self::OversizedSessionInfo { .. } => "ERR_VALIDATION_OVERSIZED_SESSION_INFO",
            Self::InsecureZeroEntropy => "ERR_VALIDATION_INSECURE_ZERO_ENTROPY",
            Self::EntropyGenerationFailed(_) => "ERR_VALIDATION_ENTROPY_FAILED",
            Self::CleanRoomViolation(_) => "ERR_VALIDATION_CLEAN_ROOM_VIOLATION",
            Self::UnsupportedProviderType(_) => "ERR_VALIDATION_UNSUPPORTED_PROVIDER",
            Self::ReferenceHardwareConfigMissing(_) => "ERR_VALIDATION_REF_CONFIG_MISSING",
            Self::AbsintheSignatureError(_) => "ERR_VALIDATION_ABSINTHE_SIGNATURE_FAILED",
            Self::SerializationError(_) => "ERR_VALIDATION_SERIALIZATION_FAILED",
            Self::InitializationFailed(_) => "ERR_VALIDATION_INIT_FAILED",
        }
    }
}
