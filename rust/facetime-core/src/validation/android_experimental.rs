//! Clean-room Android Experimental Validation Provider.
//! Enforces zero Apple hardware, zero donor certificates, zero external activation APIs.

use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};
use base64::{engine::general_purpose::STANDARD as BASE64, Engine};
use chrono::{DateTime, Utc};
use hmac::{Hmac, Mac};
use rand::{rngs::OsRng, RngCore};
use regex::Regex;
use sha2::{Digest, Sha256};
use uuid::Uuid;

use super::error::ValidationError;
use super::traits::{DeviceValidationProvider, ValidationProviderType};

type HmacSha256 = Hmac<Sha256>;

pub const MAX_SESSION_INFO_BYTES: usize = 10 * 1024 * 1024;

/// Native Android device profile attributes.
#[derive(Debug, Clone)]
pub struct AndroidDeviceProfile {
    pub android_id: String,
    pub device_model: String,
    pub manufacturer: String,
    pub fingerprint: String,
    pub synthetic_serial: String,
}

impl Default for AndroidDeviceProfile {
    fn default() -> Self {
        Self {
            android_id: "4a8b1c9d3e5f7a2b".to_string(),
            device_model: "Pixel8".to_string(),
            manufacturer: "Google".to_string(),
            fingerprint: "google/raven/raven:14/UP1A.231005.007/10754064:user/release-keys".to_string(),
            synthetic_serial: "ANDROID-SYNTHETIC-001".to_string(),
        }
    }
}

/// Clean-room Android Experimental Validation Provider.
#[derive(Debug, Clone)]
pub struct AndroidExperimentalValidationProvider {
    profile: AndroidDeviceProfile,
    synthetic_key_seed: [u8; 32],
}

impl AndroidExperimentalValidationProvider {
    /// Creates a new AndroidExperimentalValidationProvider while auditing clean-room anti-cheating invariants.
    pub fn new(profile: AndroidDeviceProfile) -> Result<Self, ValidationError> {
        // Anti-Cheating Invariant 1: Audit serial number format
        Self::audit_serial_number(&profile.synthetic_serial)?;

        // Anti-Cheating Invariant 2: Generate local synthetic key entropy using OS CSPRNG
        let mut seed = [0u8; 32];
        OsRng.fill_bytes(&mut seed);

        // Anti-Cheating Invariant 3: Audit entropy (reject zero entropy)
        if seed.iter().all(|&b| b == 0) {
            return Err(ValidationError::InsecureZeroEntropy);
        }

        Ok(Self {
            profile,
            synthetic_key_seed: seed,
        })
    }

    /// Creates an instance with an explicit seed for reproducible testing or auditing.
    pub fn new_with_seed(profile: AndroidDeviceProfile, seed: [u8; 32]) -> Result<Self, ValidationError> {
        Self::audit_serial_number(&profile.synthetic_serial)?;

        if seed.iter().all(|&b| b == 0) {
            return Err(ValidationError::InsecureZeroEntropy);
        }

        Ok(Self {
            profile,
            synthetic_key_seed: seed,
        })
    }

    /// Creates a default provider with synthetic Android parameters.
    pub fn with_synthetic_defaults() -> Self {
        let profile = AndroidDeviceProfile::default();
        Self::new(profile).expect("default clean-room profile initialization must succeed")
    }

    /// Verifies that the serial number is clean-room synthetic and not a genuine Apple hardware serial.
    pub fn audit_serial_number(serial: &str) -> Result<(), ValidationError> {
        // Genuine Apple serials are 10-12 alphanumeric characters (e.g. 12-char uppercase alphanumeric)
        let apple_pattern = Regex::new(r"^[A-Z0-9]{10,12}$").unwrap();
        if apple_pattern.is_match(serial)
            && !serial.starts_with("ANDROID")
            && !serial.starts_with("CLEANROOM")
            && !serial.starts_with("SYNTHETIC")
        {
            return Err(ValidationError::CleanRoomViolation(format!(
                "Genuine Apple serial number format detected in Android provider: {}",
                serial
            )));
        }

        if !serial.starts_with("ANDROID")
            && !serial.starts_with("CLEANROOM")
            && !serial.starts_with("SYNTHETIC")
        {
            return Err(ValidationError::CleanRoomViolation(format!(
                "Android synthetic serial must begin with 'ANDROID', 'CLEANROOM', or 'SYNTHETIC': {}",
                serial
            )));
        }

        Ok(())
    }

    /// Generates local synthetic Anisette OTP (X-Apple-I-MD).
    fn generate_synthetic_otp(&self) -> String {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        let window = timestamp / 30;

        let mut buf = Vec::with_capacity(64);
        buf.extend_from_slice(&window.to_be_bytes()); // 8 bytes timestamp window

        // Software HMAC over timestamp and android_id
        let mut hmac = HmacSha256::new_from_slice(&self.synthetic_key_seed)
            .unwrap_or_else(|_| HmacSha256::new_from_slice(&[0x11; 32]).unwrap());
        hmac.update(&window.to_be_bytes());
        hmac.update(self.profile.android_id.as_bytes());
        let digest = hmac.finalize().into_bytes();

        buf.extend_from_slice(&digest); // 32 bytes digest
        buf.extend_from_slice(&[0xAA; 24]); // 24 bytes synthetic padding -> 64 bytes total
        BASE64.encode(&buf)
    }

    /// Generates local machine identifier hash (X-Apple-I-MD-M).
    fn generate_machine_id(&self) -> String {
        let mut hasher = Sha256::new();
        hasher.update(b"AndroidMachineIdentifier:");
        hasher.update(self.profile.android_id.as_bytes());
        hasher.update(self.profile.fingerprint.as_bytes());
        BASE64.encode(hasher.finalize())
    }

    /// Generates synthetic ROM hex string.
    fn generate_rom_hex(&self) -> String {
        let mut hasher = Sha256::new();
        hasher.update(b"ROM:");
        hasher.update(self.profile.android_id.as_bytes());
        hex::encode(&hasher.finalize()[0..6])
    }

    /// Generates synthetic MLB string.
    fn generate_mlb(&self) -> String {
        let mut hasher = Sha256::new();
        hasher.update(b"MLB:");
        hasher.update(self.profile.android_id.as_bytes());
        format!("ANDROIDMLB{}", &hex::encode(&hasher.finalize()[0..4]).to_uppercase())
    }
}

impl DeviceValidationProvider for AndroidExperimentalValidationProvider {
    fn provider_type(&self) -> ValidationProviderType {
        ValidationProviderType::AndroidExperimental
    }

    fn generate_validation_data(&self, session_info: &[u8]) -> Result<Vec<u8>, ValidationError> {
        if session_info.is_empty() {
            return Err(ValidationError::EmptySessionInfo);
        }

        if session_info.len() > MAX_SESSION_INFO_BYTES {
            return Err(ValidationError::OversizedSessionInfo {
                size: session_info.len(),
                max_allowed: MAX_SESSION_INFO_BYTES,
            });
        }

        // Verify key seed is not all zeros
        if self.synthetic_key_seed.iter().all(|&b| b == 0) {
            return Err(ValidationError::InsecureZeroEntropy);
        }

        // Synthesize clean-room validation payload:
        // [ Magic (4B) | Version (1B) | Timestamp (8B) | HMAC-SHA256(seed, session_info) (32B) | Device Digest (19B) ] = 64 bytes
        let mut payload = Vec::with_capacity(64);
        payload.extend_from_slice(b"ANDR"); // Magic: "ANDR"
        payload.push(0x01); // Version: 1

        let now_ms = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64;
        payload.extend_from_slice(&now_ms.to_be_bytes()); // 8 bytes

        // HMAC-SHA256 over session_info using synthetic local seed
        let mut mac = HmacSha256::new_from_slice(&self.synthetic_key_seed)
            .map_err(|e| ValidationError::EntropyGenerationFailed(e.to_string()))?;
        mac.update(session_info);
        let hmac_result = mac.finalize().into_bytes();
        payload.extend_from_slice(&hmac_result); // 32 bytes

        // Device identifier digest (19 bytes to make total 64 bytes)
        let mut hasher = Sha256::new();
        hasher.update(self.profile.android_id.as_bytes());
        let device_hash = hasher.finalize();
        payload.extend_from_slice(&device_hash[..19]);

        Ok(payload)
    }

    fn get_device_headers(&self) -> HashMap<String, String> {
        let now: DateTime<Utc> = Utc::now();
        let formatted_time = now.format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let local_user_id = Uuid::new_v5(&Uuid::NAMESPACE_OID, self.profile.android_id.as_bytes()).to_string();
        let device_uuid = Uuid::new_v5(&Uuid::NAMESPACE_DNS, self.profile.fingerprint.as_bytes()).to_string();

        let mut headers = HashMap::new();

        // Android device identifiers
        headers.insert("X-Apple-I-SRL-NO".to_string(), self.profile.synthetic_serial.clone());
        headers.insert("X-Device-Model".to_string(), self.profile.device_model.clone());
        headers.insert("X-Device-Manufacturer".to_string(), self.profile.manufacturer.clone());
        headers.insert("X-Validation-Mode".to_string(), "CLEAN_ROOM_EXPERIMENTAL".to_string());

        // Synthetic Anisette headers
        headers.insert("X-Apple-I-MD".to_string(), self.generate_synthetic_otp());
        headers.insert("X-Apple-I-MD-M".to_string(), self.generate_machine_id());
        headers.insert("X-Apple-I-MD-RINFO".to_string(), "17106176".to_string());
        headers.insert("X-Apple-I-MD-LU".to_string(), local_user_id);
        headers.insert("X-Apple-I-ROM".to_string(), self.generate_rom_hex());
        headers.insert("X-Apple-I-MLB".to_string(), self.generate_mlb());
        headers.insert("X-Apple-I-Client-Time".to_string(), formatted_time);
        headers.insert("X-Apple-I-TimeZone".to_string(), "UTC".to_string());
        headers.insert("X-Apple-Locale".to_string(), "en_US".to_string());
        headers.insert("X-Mme-Device-Id".to_string(), device_uuid);

        headers
    }

    fn is_mock(&self) -> bool {
        false
    }

    fn display_name(&self) -> &'static str {
        "Android Experimental Provider (Clean-Room / Zero Donor)"
    }
}
