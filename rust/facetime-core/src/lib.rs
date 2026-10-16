//! FaceTime Android Protocol Core Engine & Clean-Room Validation Architecture
//!
//! Provides the core protocol implementation, device validation abstraction layer,
//! and state machine for FaceTime on Android.

pub mod events;
pub mod ids;
pub mod validation;

pub use events::{DiagnosticEvent, EventDispatcher};
pub use ids::stages::{HardwareBarrierType, IdsStage};
pub use validation::{
    create_validation_provider, AndroidDeviceProfile, AndroidExperimentalValidationProvider,
    AppleServerSimulator, DecisionGateResult, DeviceValidationProvider,
    ExistingRustpushValidationProvider, HardGoNoGoGate, MockValidationProvider,
    ReferenceHardwareConfig, SimulatedHttpResponse, SimulatedResponseMode, ValidationError,
    ValidationProviderType,
};
