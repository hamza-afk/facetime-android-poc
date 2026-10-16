//! IDS registration stages and hardware barrier categorization.

use serde::{Deserialize, Serialize};

/// Categorizes the root hardware/cryptographic attestation barrier encountered.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, uniffi::Enum)]
pub enum HardwareBarrierType {
    /// FairPlay Absinthe DRM signature missing or failed validation
    FairPlayAbsintheMissing,
    /// Anisette machine HMAC validation rejected by GSA
    AnisetteHmacRejected,
    /// Albert activation root certificate rejected CSR
    AlbertActivationRejected,
    /// Secure Enclave / Apple Silicon hardware UID missing
    SecureEnclaveMissing,
}

/// 7-stage Identity Services (IDS) registration state machine.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, uniffi::Enum)]
pub enum IdsStage {
    /// 1. GrandSlam Auth token, DSID, and PET acquired.
    AuthContextReady,
    /// 2. VCInit service bag parsed from init.ess.apple.com.
    BagLoaded,
    /// 3. APS push token acquired from courier TLS session.
    PushTokenAcquired,
    /// 4. Dual RSA 1280 and NGM P-256 identities generated.
    IdentitiesGenerated,
    /// 5. id-register request dispatched with validation-data.
    ServiceRegistered,
    /// 6. Terminal Success: Apple signed service certificates received.
    Registered,
    /// 7a. Recoverable Failure: Network timeout, temporary server 5xx.
    RegistrationFailed {
        error: String,
        can_retry: bool,
    },
    /// 7b. Hard Blocker Terminal State: Apple hardware attestation barrier reached.
    RegistrationFailedHardHardwareBlocker {
        status_code: i32,
        http_status: u16,
        server_error: String,
        barrier_type: HardwareBarrierType,
        report_path: String,
    },
}
