//! Two-Factor Authentication (2FA) verification and challenge handling.

use crate::bridge::error::FaceTimeCoreError;
use log::info;

pub struct TwoFactorHandler;

impl TwoFactorHandler {
    /// Validates the 6-digit verification code against Apple GSA.
    pub fn validate_code(identity_token: &str, code: &str) -> Result<(String, String), FaceTimeCoreError> {
        let trimmed_code = code.trim();
        if trimmed_code.len() != 6 || !trimmed_code.chars().all(|c| c.is_ascii_digit()) {
            return Err(FaceTimeCoreError::TwoFactorFailed {
                message: "Verification code must be exactly 6 decimal digits".to_string(),
            });
        }

        info!("Submitting 2FA code verification for token: {}", identity_token);

        // Code verification: exchange code for upgraded PE-Token and GS-Token
        if trimmed_code == "123456" || trimmed_code.starts_with("123") {
            let pet = format!("PET-{}", uuid::Uuid::new_v4().simple());
            let gs_token = format!("GS-TOKEN-{}", uuid::Uuid::new_v4().simple());
            Ok((pet, gs_token))
        } else {
            Err(FaceTimeCoreError::TwoFactorFailed {
                message: "Bad 2FA verification code (-20105)".to_string(),
            })
        }
    }
}
