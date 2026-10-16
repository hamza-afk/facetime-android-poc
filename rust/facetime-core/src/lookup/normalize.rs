//! Strict URI and Handle Normalization for Apple Directory Lookups.

use regex::Regex;
use std::sync::OnceLock;
use crate::bridge::error::FaceTimeCoreError;

static EMAIL_REGEX: OnceLock<Regex> = OnceLock::new();
static E164_REGEX: OnceLock<Regex> = OnceLock::new();

fn get_email_regex() -> &'static Regex {
    EMAIL_REGEX.get_or_init(|| {
        Regex::new(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").unwrap()
    })
}

fn get_e164_regex() -> &'static Regex {
    E164_REGEX.get_or_init(|| {
        Regex::new(r"^\+[1-9]\d{6,14}$").unwrap()
    })
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NormalizedHandleType {
    Email(String),
    PhoneNumber(String),
    Temporary(String),
}

impl NormalizedHandleType {
    pub fn to_uri(&self) -> String {
        match self {
            Self::Email(addr) => format!("mailto:{}", addr),
            Self::PhoneNumber(num) => format!("tel:{}", num),
            Self::Temporary(token) => format!("temp:{}", token),
        }
    }
}

pub struct HandleNormalizer;

impl HandleNormalizer {
    /// Normalizes raw user input into an authoritative Apple Directory URI.
    pub fn normalize(raw: &str) -> Result<NormalizedHandleType, FaceTimeCoreError> {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return Err(FaceTimeCoreError::LookupFailed {
                handle: raw.to_string(),
                message: "Recipient handle cannot be empty".to_string(),
            });
        }

        // Scheme-prefixed handles
        if let Some(email) = trimmed.strip_prefix("mailto:") {
            return Self::normalize_email(email, raw);
        }
        if let Some(phone) = trimmed.strip_prefix("tel:") {
            return Self::normalize_phone(phone, raw);
        }
        if let Some(temp) = trimmed.strip_prefix("temp:") {
            if temp.is_empty() {
                return Err(FaceTimeCoreError::LookupFailed {
                    handle: raw.to_string(),
                    message: "Temporary token cannot be empty".to_string(),
                });
            }
            return Ok(NormalizedHandleType::Temporary(temp.to_string()));
        }

        // Reject other URI schemes early (e.g. ftp://, http://)
        if trimmed.contains("://") {
            return Err(FaceTimeCoreError::LookupFailed {
                handle: raw.to_string(),
                message: "Unsupported handle URI scheme".to_string(),
            });
        }

        // Bare email heuristic
        if trimmed.contains('@') {
            return Self::normalize_email(trimmed, raw);
        }

        // Bare phone heuristic
        Self::normalize_phone(trimmed, raw)
    }

    fn normalize_email(email: &str, raw_orig: &str) -> Result<NormalizedHandleType, FaceTimeCoreError> {
        let cleaned = email.trim().to_lowercase();
        if !get_email_regex().is_match(&cleaned) {
            return Err(FaceTimeCoreError::LookupFailed {
                handle: raw_orig.to_string(),
                message: format!("Invalid email address format: '{}'", email),
            });
        }
        Ok(NormalizedHandleType::Email(cleaned))
    }

    fn normalize_phone(phone: &str, raw_orig: &str) -> Result<NormalizedHandleType, FaceTimeCoreError> {
        let mut digits = String::with_capacity(phone.len() + 2);
        let trimmed = phone.trim();

        // Handle international dialing prefix '00'
        let s = if trimmed.starts_with("00") {
            &trimmed[2..]
        } else {
            trimmed
        };

        for (i, ch) in s.chars().enumerate() {
            if ch == '+' && i == 0 {
                digits.push('+');
            } else if ch.is_ascii_digit() {
                digits.push(ch);
            } else if ch == ' ' || ch == '-' || ch == '(' || ch == ')' || ch == '.' {
                continue;
            } else {
                return Err(FaceTimeCoreError::LookupFailed {
                    handle: raw_orig.to_string(),
                    message: format!("Invalid character '{}' in phone number", ch),
                });
            }
        }

        // If no '+' prefix, apply NANP / international default heuristic
        let e164 = if !digits.starts_with('+') {
            if digits.len() == 10 {
                format!("+1{}", digits)
            } else if digits.len() == 11 && digits.starts_with('1') {
                format!("+{}", digits)
            } else {
                format!("+{}", digits)
            }
        } else {
            digits
        };

        if !get_e164_regex().is_match(&e164) {
            return Err(FaceTimeCoreError::LookupFailed {
                handle: raw_orig.to_string(),
                message: format!("Phone number '{}' does not conform to ITU-T E.164 (+1XXXXXXXXXX)", e164),
            });
        }

        Ok(NormalizedHandleType::PhoneNumber(e164))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_email_normalization() {
        let r1 = HandleNormalizer::normalize("Alice@Example.COM ").unwrap();
        assert_eq!(r1.to_uri(), "mailto:alice@example.com");

        let r2 = HandleNormalizer::normalize("mailto:Bob.Smith+tag@icloud.com").unwrap();
        assert_eq!(r2.to_uri(), "mailto:bob.smith+tag@icloud.com");
    }

    #[test]
    fn test_phone_normalization() {
        let r1 = HandleNormalizer::normalize("(415) 555-0199").unwrap();
        assert_eq!(r1.to_uri(), "tel:+14155550199");

        let r2 = HandleNormalizer::normalize("+44 20 7946 0958").unwrap();
        assert_eq!(r2.to_uri(), "tel:+442079460958");

        let r3 = HandleNormalizer::normalize("0044 20 7946 0958").unwrap();
        assert_eq!(r3.to_uri(), "tel:+442079460958");

        let r4 = HandleNormalizer::normalize("tel:+1 (555) 555-0100").unwrap();
        assert_eq!(r4.to_uri(), "tel:+15555550100");
    }

    #[test]
    fn test_invalid_handles() {
        assert!(HandleNormalizer::normalize("").is_err());
        assert!(HandleNormalizer::normalize("   ").is_err());
        assert!(HandleNormalizer::normalize("ftp://user@example.com").is_err());
        assert!(HandleNormalizer::normalize("not-an-email-or-phone").is_err());
    }
}
