#[cfg(test)]
mod tests {
    use std::str::FromStr;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::Arc;
    use plist::Value;

    use super::*;
    use crate::events::{DiagnosticEvent, EventDispatcher};
    use crate::ids::stages::{HardwareBarrierType, IdsStage};

    #[test]
    fn test_mock_provider_deterministic_output_and_mock_flag() {
        let provider = MockValidationProvider::new();
        assert_eq!(provider.provider_type(), ValidationProviderType::Mock);
        assert!(provider.is_mock());
        assert_eq!(provider.display_name(), "Mock Validation Provider (Deterministic / Offline)");

        let headers = provider.get_device_headers();
        assert_eq!(headers.get("X-Validation-Mode").map(|s| s.as_str()), Some("MOCK_MODE"));
        assert_eq!(headers.get("X-Mock-Client").map(|s| s.as_str()), Some("True"));
        assert_eq!(headers.get("X-Apple-I-SRL-NO").map(|s| s.as_str()), Some("MOCK-SERIAL-0000"));

        let session_info = b"test_challenge_nonce";
        let data = provider.generate_validation_data(session_info).expect("mock data generation failed");
        assert_eq!(data, MOCK_VALIDATION_DATA_BYTES);
    }

    #[test]
    fn test_existing_rustpush_provider_baseline() {
        let provider = ExistingRustpushValidationProvider::default();
        assert_eq!(provider.provider_type(), ValidationProviderType::ExistingRustpush);
        assert!(!provider.is_mock());
        assert_eq!(provider.display_name(), "Existing Rustpush Provider (Upstream Reference / Parity)");

        let headers = provider.get_device_headers();
        assert!(headers.contains_key("User-Agent"));
        assert_eq!(headers.get("X-Apple-I-Client-Time").map(|s| s.as_str()), Some("2026-10-16T03:00:00Z"));
        assert_eq!(headers.get("X-Apple-I-TimeZone").map(|s| s.as_str()), Some("UTC"));

        let session_info = b"audit_session_challenge";
        let data = provider.generate_validation_data(session_info).expect("reference generation failed");
        assert_eq!(data, REFERENCE_RUSTPUSH_VALIDATION_BYTES);
    }

    #[test]
    fn test_android_experimental_clean_room_compliance() {
        let profile = AndroidDeviceProfile {
            android_id: "test_android_id_12345".to_string(),
            device_model: "Pixel8".to_string(),
            manufacturer: "Google".to_string(),
            fingerprint: "google/raven/raven:14".to_string(),
            synthetic_serial: "ANDROID-SYNTHETIC-001".to_string(),
        };

        let provider = AndroidExperimentalValidationProvider::new(profile).expect("clean-room init failed");
        assert_eq!(provider.provider_type(), ValidationProviderType::AndroidExperimental);
        assert!(!provider.is_mock());
        assert_eq!(provider.display_name(), "Android Experimental Provider (Clean-Room / Zero Donor)");

        let headers = provider.get_device_headers();
        let srl = headers.get("X-Apple-I-SRL-NO").expect("missing SRL-NO");
        assert!(srl.starts_with("ANDROID"));
        assert_eq!(headers.get("X-Validation-Mode").map(|s| s.as_str()), Some("CLEAN_ROOM_EXPERIMENTAL"));
        assert_eq!(headers.get("X-Device-Model").map(|s| s.as_str()), Some("Pixel8"));
        assert_eq!(headers.get("X-Device-Manufacturer").map(|s| s.as_str()), Some("Google"));

        let session_info = b"challenge_session_bytes";
        let data = provider.generate_validation_data(session_info).expect("clean-room payload failed");
        assert_eq!(data.len(), 64);
        assert_eq!(&data[0..4], b"ANDR");
        assert_eq!(data[4], 0x01); // Version byte
    }

    #[test]
    fn test_android_experimental_rejects_genuine_apple_serial() {
        let bad_profile = AndroidDeviceProfile {
            synthetic_serial: "C02X1234JHC8".to_string(), // Genuine Apple 12-char serial
            ..Default::default()
        };

        let result = AndroidExperimentalValidationProvider::new(bad_profile);
        assert!(result.is_err());
        match result.unwrap_err() {
            ValidationError::CleanRoomViolation(msg) => {
                assert!(msg.contains("Genuine Apple serial number format detected"));
            }
            other => panic!("Expected CleanRoomViolation, got: {:?}", other),
        }
    }

    #[test]
    fn test_android_experimental_rejects_zero_entropy() {
        let profile = AndroidDeviceProfile::default();
        let zero_seed = [0u8; 32];
        let result = AndroidExperimentalValidationProvider::new_with_seed(profile, zero_seed);
        assert_eq!(result.unwrap_err(), ValidationError::InsecureZeroEntropy);
    }

    #[test]
    fn test_empty_session_info_rejection() {
        let ref_provider = ExistingRustpushValidationProvider::default();
        let empty_session: &[u8] = &[];
        assert_eq!(
            ref_provider.generate_validation_data(empty_session).unwrap_err(),
            ValidationError::EmptySessionInfo
        );

        let android_provider = AndroidExperimentalValidationProvider::with_synthetic_defaults();
        assert_eq!(
            android_provider.generate_validation_data(empty_session).unwrap_err(),
            ValidationError::EmptySessionInfo
        );
    }

    #[test]
    fn test_oversized_session_info_rejection() {
        let mock_provider = MockValidationProvider::new();
        let huge_session = vec![0u8; 10 * 1024 * 1024 + 1];
        assert!(matches!(
            mock_provider.generate_validation_data(&huge_session).unwrap_err(),
            ValidationError::OversizedSessionInfo { .. }
        ));

        let ref_provider = ExistingRustpushValidationProvider::default();
        assert!(matches!(
            ref_provider.generate_validation_data(&huge_session).unwrap_err(),
            ValidationError::OversizedSessionInfo { .. }
        ));

        let android_provider = AndroidExperimentalValidationProvider::with_synthetic_defaults();
        assert!(matches!(
            android_provider.generate_validation_data(&huge_session).unwrap_err(),
            ValidationError::OversizedSessionInfo { .. }
        ));
    }

    #[test]
    fn test_provider_type_from_str_and_display() {
        assert_eq!(ValidationProviderType::from_str("Mock").unwrap(), ValidationProviderType::Mock);
        assert_eq!(ValidationProviderType::from_str("existingrustpush").unwrap(), ValidationProviderType::ExistingRustpush);
        assert_eq!(ValidationProviderType::from_str("android_experimental").unwrap(), ValidationProviderType::AndroidExperimental);

        let err = ValidationProviderType::from_str("AlienHardwareProvider").unwrap_err();
        assert!(matches!(err, ValidationError::UnsupportedProviderType(_)));
        assert_eq!(ValidationProviderType::Mock.to_string(), "Mock");
        assert_eq!(ValidationProviderType::ExistingRustpush.to_string(), "ExistingRustpush");
        assert_eq!(ValidationProviderType::AndroidExperimental.to_string(), "AndroidExperimental");
    }

    #[test]
    fn test_factory_polymorphism() {
        for pt in [
            ValidationProviderType::Mock,
            ValidationProviderType::ExistingRustpush,
            ValidationProviderType::AndroidExperimental,
        ] {
            let provider = create_validation_provider(pt, None).expect("factory failed");
            assert_eq!(provider.provider_type(), pt);
        }
    }

    #[test]
    fn test_apple_server_simulator_responses() {
        // Status 6005
        let resp6005 = AppleServerSimulator::simulate_id_register(SimulatedResponseMode::RejectStatus6005);
        assert_eq!(resp6005.status_code, 403);
        let parsed: Value = plist::from_reader(std::io::Cursor::new(&resp6005.body_bytes)).expect("parse plist");
        let dict = parsed.as_dictionary().unwrap();
        assert_eq!(dict.get("status").unwrap().as_signed_integer().unwrap(), 6005);
        assert_eq!(dict.get("reason").unwrap().as_string().unwrap(), "DeviceNotSupported");

        // Status 6009
        let resp6009 = AppleServerSimulator::simulate_id_register(SimulatedResponseMode::RejectStatus6009);
        assert_eq!(resp6009.status_code, 403);
        let parsed: Value = plist::from_reader(std::io::Cursor::new(&resp6009.body_bytes)).expect("parse plist");
        let dict = parsed.as_dictionary().unwrap();
        assert_eq!(dict.get("status").unwrap().as_signed_integer().unwrap(), 6009);
        assert_eq!(dict.get("reason").unwrap().as_string().unwrap(), "FairPlayVerificationFailed");

        // Mock Success (status 0)
        let resp0 = AppleServerSimulator::simulate_id_register(SimulatedResponseMode::AcceptMockSuccess);
        assert_eq!(resp0.status_code, 200);
        let parsed: Value = plist::from_reader(std::io::Cursor::new(&resp0.body_bytes)).expect("parse plist");
        let dict = parsed.as_dictionary().unwrap();
        assert_eq!(dict.get("status").unwrap().as_signed_integer().unwrap(), 0);

        // GSA 401
        let resp_gsa = AppleServerSimulator::simulate_gsa_auth_rejection();
        assert_eq!(resp_gsa.status_code, 401);
        assert_eq!(resp_gsa.headers.get("X-Apple-Host-Baa-E").unwrap(), "-7066");

        // Albert 400
        let resp_albert = AppleServerSimulator::simulate_albert_rejection();
        assert_eq!(resp_albert.status_code, 400);
    }

    #[test]
    fn test_hard_go_no_go_gate_triggers_on_status_6005() {
        let provider = AndroidExperimentalValidationProvider::with_synthetic_defaults();
        let dispatcher = EventDispatcher::new();
        let event_emitted = Arc::new(AtomicBool::new(false));
        let event_emitted_clone = Arc::clone(&event_emitted);

        dispatcher.subscribe(move |event| {
            if let DiagnosticEvent::HardGoNoGoTriggered { apple_status, .. } = event {
                if *apple_status == 6005 {
                    event_emitted_clone.store(true, Ordering::SeqCst);
                }
            }
        });

        let result = HardGoNoGoGate::evaluate_id_register_response(
            &provider,
            403,
            6005,
            "ValidationDataRejected",
            Some(&dispatcher),
        );

        assert!(result.is_halted);
        assert!(event_emitted.load(Ordering::SeqCst));
        match result.stage {
            IdsStage::RegistrationFailedHardHardwareBlocker {
                status_code,
                http_status,
                barrier_type,
                report_path,
                ..
            } => {
                assert_eq!(status_code, 6005);
                assert_eq!(http_status, 403);
                assert_eq!(barrier_type, HardwareBarrierType::FairPlayAbsintheMissing);
                assert_eq!(report_path, "docs/experiments/Standalone_Android_FaceTime_Registration_Blocker.md");
            }
            other => panic!("Expected RegistrationFailedHardHardwareBlocker, got {:?}", other),
        }
    }

    #[test]
    fn test_hard_go_no_go_gate_does_not_halt_on_mock_or_success() {
        let mock_provider = MockValidationProvider::new();
        let result = HardGoNoGoGate::evaluate_id_register_response(
            &mock_provider,
            200,
            0,
            "OK",
            None,
        );

        assert!(!result.is_halted);
        assert_eq!(result.stage, IdsStage::Registered);
    }
}
