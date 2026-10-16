//! End-to-end integration tests verifying Rust Core Engine and UniFFI Bridge.

use facetime_core::bridge::{
    AppleCredentials, ApsStatus, AuthState, CallState, CoreConfig, DiagnosticEventJsonl,
    FaceTimeCoreEventListener,
};
use facetime_core::engine::FaceTimeCoreEngine;
use facetime_core::ids::stages::IdsStage;
use facetime_core::validation::traits::ValidationProviderType;
use std::sync::atomic::{AtomicUsize, Ordering};

struct TestListener {
    auth_events: AtomicUsize,
    aps_events: AtomicUsize,
    ids_events: AtomicUsize,
    call_events: AtomicUsize,
    diagnostic_events: AtomicUsize,
}

impl TestListener {
    fn new() -> Self {
        Self {
            auth_events: AtomicUsize::new(0),
            aps_events: AtomicUsize::new(0),
            ids_events: AtomicUsize::new(0),
            call_events: AtomicUsize::new(0),
            diagnostic_events: AtomicUsize::new(0),
        }
    }
}

impl FaceTimeCoreEventListener for TestListener {
    fn on_auth_state_changed(&self, _state: AuthState) {
        self.auth_events.fetch_add(1, Ordering::SeqCst);
    }
    fn on_aps_state_changed(&self, _status: ApsStatus) {
        self.aps_events.fetch_add(1, Ordering::SeqCst);
    }
    fn on_ids_state_changed(&self, _stage: IdsStage) {
        self.ids_events.fetch_add(1, Ordering::SeqCst);
    }
    fn on_call_state_changed(&self, _call_id: String, _state: CallState) {
        self.call_events.fetch_add(1, Ordering::SeqCst);
    }
    fn on_diagnostic_event(&self, _event: DiagnosticEventJsonl) {
        self.diagnostic_events.fetch_add(1, Ordering::SeqCst);
    }
}

#[test]
fn test_full_engine_lifecycle_mock_provider() {
    let engine = FaceTimeCoreEngine::new();
    let listener = Box::new(TestListener::new());

    let config = CoreConfig {
        environment: "Production".to_string(),
        user_agent: "com.apple.invitation-registration [macOS,14.5,23F79,MacBookPro18,1]".to_string(),
        courier_host: None,
        default_provider: ValidationProviderType::Mock,
    };

    assert!(engine.init_engine(config, listener).is_ok());

    // 1. Auth Flow
    let creds = AppleCredentials {
        username: "valid.user@icloud.com".to_string(),
        password: "SecretPassword123!".to_string(),
    };
    let auth_res = engine.authenticate_apple_account(creds).expect("Auth should prompt 2FA");
    assert!(auth_res.requires_2fa);

    let session = engine.submit_two_factor_code("123456".to_string()).expect("2FA should succeed");
    assert!(!session.requires_2fa);
    assert!(session.pet.starts_with("PET-"));

    // 2. APS Courier
    assert!(engine.connect_aps_courier().is_ok());

    // 3. IDS Registration with Mock Provider -> Success
    let reg_res = engine.register_ids_pipeline(ValidationProviderType::Mock).expect("Mock IDS should register");
    assert!(reg_res.is_success);
    assert!(!reg_res.is_halted_by_gate);
    assert_eq!(reg_res.stage, IdsStage::Registered);

    // 4. Recipient Lookup
    let lookup = engine.lookup_recipient("mailto:recipient@example.com".to_string()).expect("Lookup should succeed");
    assert!(lookup.is_facetime_capable);

    // 5. FaceTime Call Initiation -> Remote Ringing
    let call = engine.start_facetime_call("mailto:recipient@example.com".to_string()).expect("Call should start");
    match call.state {
        CallState::RemoteRinging { ref call_id } => assert_eq!(call_id, &call.call_id),
        other => panic!("Expected RemoteRinging, got {:?}", other),
    }

    // 6. End Call
    assert!(engine.end_facetime_call(call.call_id).is_ok());
}

#[test]
fn test_ids_registration_android_experimental_triggers_blocker() {
    let engine = FaceTimeCoreEngine::new();
    let listener = Box::new(TestListener::new());

    let config = CoreConfig {
        environment: "Production".to_string(),
        user_agent: "com.apple.invitation-registration [macOS,14.5,23F79,MacBookPro18,1]".to_string(),
        courier_host: None,
        default_provider: ValidationProviderType::AndroidExperimental,
    };
    assert!(engine.init_engine(config, listener).is_ok());

    // Connect APS
    assert!(engine.connect_aps_courier().is_ok());

    // Execute with AndroidExperimental -> Must trigger Hard Go/No-Go Decision Gate!
    let reg_res = engine.register_ids_pipeline(ValidationProviderType::AndroidExperimental).expect("Should evaluate gate");
    assert!(!reg_res.is_success);
    assert!(reg_res.is_halted_by_gate);

    match reg_res.stage {
        IdsStage::RegistrationFailedHardHardwareBlocker { status_code, http_status, ref report_path, .. } => {
            assert_eq!(status_code, 6005);
            assert_eq!(http_status, 403);
            assert_eq!(report_path, "docs/experiments/Standalone_Android_FaceTime_Registration_Blocker.md");
        }
        other => panic!("Expected RegistrationFailedHardHardwareBlocker, got {:?}", other),
    }
}
