//! UniFFI error taxonomy mapping Rust Results to Kotlin Exceptions.

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum FaceTimeCoreError {
    #[error("FaceTime engine is not initialized. Call initEngine() first.")]
    EngineNotInitialized,

    #[error("Authentication failed (code {code}): {message}")]
    AuthFailed { code: i32, message: String },

    #[error("Two-factor authentication required for challenge: {challenge}")]
    TwoFactorRequired { challenge: String },

    #[error("2FA validation failed: {message}")]
    TwoFactorFailed { message: String },

    #[error("APS courier error: {message}")]
    ApsError { message: String },

    #[error("IDS registration error at stage '{stage}': {message}")]
    IdsRegistrationError { stage: String, message: String },

    #[error("IDS HARD HARDWARE BLOCKER (status {status_code}, http {http_status}): {barrier_type}. See report: {report_path}")]
    IdsHardBlocker {
        status_code: i32,
        http_status: u16,
        barrier_type: String,
        report_path: String,
    },

    #[error("Recipient lookup failed for handle '{handle}': {message}")]
    LookupFailed { handle: String, message: String },

    #[error("FaceTime call session error: {message}")]
    CallError { message: String },

    #[error("Internal engine error: {message}")]
    InternalError { message: String },
}
