//! High-Fidelity Apple Server Simulation Responder
//!
//! Provides deterministic offline simulation of Apple GSA, Albert, and IDS server
//! responses for unit tests, E2E tests, and Hard Go/No-Go verification.

use std::collections::HashMap;
use plist::Value;

/// Configurable simulation response modes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SimulatedResponseMode {
    /// Simulates genuine Apple server rejecting synthetic validation data with Status 6005.
    RejectStatus6005,
    /// Simulates account temporarily restricted with Status 6009.
    RejectStatus6009,
    /// Simulates GSA Anisette rejection with HTTP 401 Unauthorized (ec = -7066).
    RejectGsaAnisette401,
    /// Simulates Albert Activation rejection with HTTP 400 Bad Request.
    RejectAlbertCert400,
    /// Simulates successful registration for Mock provider.
    AcceptMockSuccess,
}

/// Simulated HTTP response envelope.
#[derive(Debug, Clone)]
pub struct SimulatedHttpResponse {
    pub status_code: u16,
    pub headers: HashMap<String, String>,
    pub body_bytes: Vec<u8>,
}

pub struct AppleServerSimulator;

impl AppleServerSimulator {
    /// Simulates Apple IDS `id-register` response.
    pub fn simulate_id_register(mode: SimulatedResponseMode) -> SimulatedHttpResponse {
        let mut headers = HashMap::new();
        headers.insert("content-type".to_string(), "application/x-apple-plist".to_string());
        headers.insert("server".to_string(), "AppleIdentityServices/1.0".to_string());

        match mode {
            SimulatedResponseMode::RejectStatus6005 => {
                let mut dict = plist::Dictionary::new();
                dict.insert("status".to_string(), Value::Integer(6005.into()));
                dict.insert("error".to_string(), Value::String("Bad authentication, try again and re-enter device details if persistent. (6005)".into()));
                dict.insert("reason".to_string(), Value::String("DeviceNotSupported".into()));
                dict.insert("localizedError".to_string(), Value::String("Your device could not be registered with Apple Identity Services (Missing FairPlay hardware endorsement)".into()));

                let mut body = Vec::new();
                plist::to_writer_xml(&mut body, &Value::Dictionary(dict)).expect("plist write");

                SimulatedHttpResponse {
                    status_code: 403,
                    headers,
                    body_bytes: body,
                }
            }
            SimulatedResponseMode::RejectStatus6009 => {
                let mut dict = plist::Dictionary::new();
                dict.insert("status".to_string(), Value::Integer(6009.into()));
                dict.insert("error".to_string(), Value::String("Your iMessage access is temporarily disabled. Try again later, or ask Apple to allow you to use iMessage: https://apple.co/IMFT-mac.".into()));
                dict.insert("reason".to_string(), Value::String("FairPlayVerificationFailed".into()));
                dict.insert("block-url".to_string(), Value::String("https://apple.co/IMFT-mac".into()));

                let mut body = Vec::new();
                plist::to_writer_xml(&mut body, &Value::Dictionary(dict)).expect("plist write");

                SimulatedHttpResponse {
                    status_code: 403,
                    headers,
                    body_bytes: body,
                }
            }
            SimulatedResponseMode::AcceptMockSuccess => {
                let mut dict = plist::Dictionary::new();
                dict.insert("status".to_string(), Value::Integer(0.into()));
                dict.insert("next-hbi".to_string(), Value::Integer(86400.into()));

                let mut services = plist::Dictionary::new();
                let mut ft_service = plist::Dictionary::new();
                ft_service.insert("cert".to_string(), Value::String("MOCK-FACETIME-SERVICE-CERT".into()));
                ft_service.insert("status".to_string(), Value::String("active".into()));
                services.insert("com.apple.private.alloy.facetime.multi".to_string(), Value::Dictionary(ft_service));
                dict.insert("services".to_string(), Value::Dictionary(services));

                let mut body = Vec::new();
                plist::to_writer_xml(&mut body, &Value::Dictionary(dict)).expect("plist write");

                SimulatedHttpResponse {
                    status_code: 200,
                    headers,
                    body_bytes: body,
                }
            }
            SimulatedResponseMode::RejectGsaAnisette401 => Self::simulate_gsa_auth_rejection(),
            SimulatedResponseMode::RejectAlbertCert400 => Self::simulate_albert_rejection(),
        }
    }

    /// Simulates Apple GSA authentication response with synthetic Anisette failure.
    pub fn simulate_gsa_auth_rejection() -> SimulatedHttpResponse {
        let mut headers = HashMap::new();
        headers.insert("content-type".to_string(), "text/xml".to_string());
        headers.insert("X-Apple-Baa-UE".to_string(), "AKAuthenticationError:-7066|com.apple.devicecheck.error.baa:-10000".to_string());
        headers.insert("X-Apple-Host-Baa-E".to_string(), "-7066".to_string());

        let mut dict = plist::Dictionary::new();
        let mut resp_dict = plist::Dictionary::new();
        resp_dict.insert("status".to_string(), Value::Integer(401.into()));
        dict.insert("Response".to_string(), Value::Dictionary(resp_dict));

        let mut status_dict = plist::Dictionary::new();
        status_dict.insert("ec".to_string(), Value::Integer((-7066).into()));
        status_dict.insert("em".to_string(), Value::String("AKAuthenticationErrorAnisetteFailed: invalid device signature".into()));
        dict.insert("status".to_string(), Value::Dictionary(status_dict));

        let mut body = Vec::new();
        plist::to_writer_xml(&mut body, &Value::Dictionary(dict)).expect("plist write");

        SimulatedHttpResponse {
            status_code: 401,
            headers,
            body_bytes: body,
        }
    }

    /// Simulates Apple Albert activation rejection.
    pub fn simulate_albert_rejection() -> SimulatedHttpResponse {
        let mut headers = HashMap::new();
        headers.insert("content-type".to_string(), "text/xml".to_string());

        let mut dict = plist::Dictionary::new();
        dict.insert("status".to_string(), Value::String("failure".into()));
        dict.insert("error".to_string(), Value::String("AlbertCertParseError".into()));
        dict.insert("errorCode".to_string(), Value::Integer((-1002).into()));
        dict.insert("errorMessage".to_string(), Value::String("FairPlay certificate signature validation failed: unknown root authority".into()));

        let mut body = Vec::new();
        plist::to_writer_xml(&mut body, &Value::Dictionary(dict)).expect("plist write");

        SimulatedHttpResponse {
            status_code: 400,
            headers,
            body_bytes: body,
        }
    }
}
