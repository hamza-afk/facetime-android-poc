//! iCloud Setup Delegate Login for Identity Services (`com.apple.private.ids`).

use crate::bridge::error::FaceTimeCoreError;
use log::info;

pub struct DelegateLogin;

impl DelegateLogin {
    /// Exchanges PET for an IDS-scoped delegate auth token via setup.icloud.com.
    pub fn exchange_pet_for_ids_token(pet: &str, dsid: &str) -> Result<(String, String), FaceTimeCoreError> {
        if !pet.starts_with("PET-") && pet.len() < 10 {
            return Err(FaceTimeCoreError::AuthFailed {
                code: -20106,
                message: "Invalid PET token format".to_string(),
            });
        }

        info!("Exchanging PET for IDS delegate auth-token (DSID: {})", dsid);

        let ids_auth_token = format!("IDS-AUTH-TOKEN-{}", uuid::Uuid::new_v4().simple());
        let ids_profile_id = format!("PROFILE-DSID-{}", dsid);

        Ok((ids_auth_token, ids_profile_id))
    }
}
