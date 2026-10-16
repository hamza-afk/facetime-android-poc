//! Apple Identity Services (IDS) protocol implementation and state transitions.

pub mod bag;
pub mod keys;
pub mod pipeline;
pub mod signing;
pub mod stages;

pub use bag::VcInitBag;
pub use keys::DualIdentities;
pub use pipeline::IdsRegistrationStepper;
pub use signing::IdsHeaderSigner;
pub use stages::{HardwareBarrierType, IdsStage};
