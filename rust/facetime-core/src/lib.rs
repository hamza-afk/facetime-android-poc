//! FaceTime Android Protocol Core Engine & Clean-Room Validation Architecture
//!
//! Provides the core protocol implementation, device validation abstraction layer,
//! 7-stage IDS registration stepper, and UniFFI 0.28+ bindings for Android Kotlin.

uniffi::setup_scaffolding!("facetime_core");

pub mod aps;
pub mod auth;
pub mod bridge;
pub mod engine;
pub mod events;
pub mod ids;
pub mod signaling;
pub mod validation;

// Re-export public types
pub use bridge::{
    AppleCredentials, ApsStatus, AuthSession, AuthState, CallSession, CallState, CoreConfig,
    DiagnosticEventJsonl, FaceTimeCoreError, FaceTimeCoreEventListener, IdsRegistrationResult,
    RecipientCapabilities,
};
pub use engine::FaceTimeCoreEngine;
pub use events::{DiagnosticEvent, EventDispatcher};
pub use ids::stages::{HardwareBarrierType, IdsStage};
pub use validation::{
    create_validation_provider, AndroidDeviceProfile, AndroidExperimentalValidationProvider,
    AppleServerSimulator, DecisionGateResult, DeviceValidationProvider,
    ExistingRustpushValidationProvider, HardGoNoGoGate, MockValidationProvider,
    ReferenceHardwareConfig, SimulatedHttpResponse, SimulatedResponseMode, ValidationError,
    ValidationProviderType,
};
