//! Device validation module isolating Mock, Reference, and Android experimental providers.

pub mod android_experimental;
pub mod error;
pub mod existing_rustpush;
pub mod gate;
pub mod mock;
pub mod simulation_responder;
pub mod traits;

#[cfg(test)]
mod tests;

pub use android_experimental::{AndroidDeviceProfile, AndroidExperimentalValidationProvider};
pub use error::ValidationError;
pub use existing_rustpush::{ExistingRustpushValidationProvider, ReferenceHardwareConfig, REFERENCE_RUSTPUSH_VALIDATION_BYTES};
pub use gate::{DecisionGateResult, HardGoNoGoGate};
pub use mock::{MockValidationProvider, MOCK_VALIDATION_DATA_BYTES};
pub use simulation_responder::{AppleServerSimulator, SimulatedHttpResponse, SimulatedResponseMode};
pub use traits::{DeviceValidationProvider, ValidationProviderType};

/// Unified configuration container for instantiating validation providers.
#[derive(Debug, Clone, Default)]
pub struct ValidationConfig {
    pub reference_config: Option<ReferenceHardwareConfig>,
    pub android_profile: Option<AndroidDeviceProfile>,
}

/// Factory function to create validation provider trait objects.
pub fn create_validation_provider(
    provider_type: ValidationProviderType,
    config: Option<&ValidationConfig>,
) -> Result<Box<dyn DeviceValidationProvider>, ValidationError> {
    match provider_type {
        ValidationProviderType::Mock => Ok(Box::new(MockValidationProvider::new())),
        ValidationProviderType::ExistingRustpush => {
            let ref_provider = ExistingRustpushValidationProvider::new(
                config.and_then(|c| c.reference_config.clone()),
            );
            Ok(Box::new(ref_provider))
        }
        ValidationProviderType::AndroidExperimental => {
            let profile = config
                .and_then(|c| c.android_profile.clone())
                .unwrap_or_default();
            let android_provider = AndroidExperimentalValidationProvider::new(profile)?;
            Ok(Box::new(android_provider))
        }
    }
}
