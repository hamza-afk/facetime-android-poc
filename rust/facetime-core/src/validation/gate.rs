//! Hard Go/No-Go Decision Gate Protocol Enforcer.
//!
//! Halts feature development and locks the state machine upon Apple Identity Services
//! rejecting clean-room Android device validation data.

use super::traits::{DeviceValidationProvider, ValidationProviderType};
use crate::ids::stages::{HardwareBarrierType, IdsStage};
use crate::events::{DiagnosticEvent, EventDispatcher};

/// Result of evaluating the Hard Go/No-Go Decision Gate.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DecisionGateResult {
    pub is_halted: bool,
    pub stage: IdsStage,
    pub message: String,
}

pub struct HardGoNoGoGate;

impl HardGoNoGoGate {
    /// Evaluates the Apple server response following Step 5 of the IDS registration pipeline (`id-register`).
    pub fn evaluate_id_register_response(
        provider: &dyn DeviceValidationProvider,
        http_status: u16,
        apple_status: i32,
        error_str: &str,
        dispatcher: Option<&EventDispatcher>,
    ) -> DecisionGateResult {
        // Evaluate only clean-room Android provider
        if provider.provider_type() == ValidationProviderType::AndroidExperimental {
            if apple_status == 6005 || apple_status == 6009 || http_status == 403 {
                let barrier = match apple_status {
                    6005 => HardwareBarrierType::FairPlayAbsintheMissing,
                    6009 => HardwareBarrierType::AnisetteHmacRejected,
                    _ => HardwareBarrierType::SecureEnclaveMissing,
                };

                let report_path = "docs/experiments/Standalone_Android_FaceTime_Registration_Blocker.md".to_string();

                let terminal_stage = IdsStage::RegistrationFailedHardHardwareBlocker {
                    status_code: apple_status,
                    http_status,
                    server_error: error_str.to_string(),
                    barrier_type: barrier,
                    report_path: report_path.clone(),
                };

                // Dispatch structured diagnostic event if dispatcher is configured
                if let Some(disp) = dispatcher {
                    disp.emit_event(DiagnosticEvent::HardGoNoGoTriggered {
                        stage: "IDS_REGISTRATION_FAILED_HARD_HARDWARE_BLOCKER".to_string(),
                        http_status,
                        apple_status,
                        server_error: error_str.to_string(),
                        barrier_type: format!("{:?}", barrier),
                        report_path,
                    });
                }

                return DecisionGateResult {
                    is_halted: true,
                    stage: terminal_stage,
                    message: format!(
                        "HARD GO/NO-GO GATE TRIGGERED: Apple server rejected clean Android validation (Status {}, HTTP {}). Feature development halted per Requirement R2.",
                        apple_status, http_status
                    ),
                };
            }
        }

        // Standard non-blocker successes or failures
        if apple_status == 0 && http_status == 200 {
            DecisionGateResult {
                is_halted: false,
                stage: IdsStage::Registered,
                message: "IDS registration completed successfully.".to_string(),
            }
        } else {
            DecisionGateResult {
                is_halted: false,
                stage: IdsStage::RegistrationFailed {
                    error: error_str.to_string(),
                    can_retry: http_status >= 500,
                },
                message: format!("IDS registration failed: {} (Status {}, HTTP {})", error_str, apple_status, http_status),
            }
        }
    }
}
