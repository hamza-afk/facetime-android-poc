//! VCInit bag parser for Apple Identity Services endpoints.

use std::collections::HashMap;

pub struct VcInitBag {
    pub endpoints: HashMap<String, String>,
}

impl Default for VcInitBag {
    fn default() -> Self {
        Self::default_bag()
    }
}

impl VcInitBag {
    pub fn default_bag() -> Self {
        let mut endpoints = HashMap::new();
        endpoints.insert(
            "id-authenticate-ds-id".to_string(),
            "https://init.ess.apple.com/WebObjects/VCInit.woa/wa/id-authenticate-ds-id".to_string(),
        );
        endpoints.insert(
            "id-get-handles".to_string(),
            "https://init.ess.apple.com/WebObjects/VCInit.woa/wa/id-get-handles".to_string(),
        );
        endpoints.insert(
            "id-register".to_string(),
            "https://init.ess.apple.com/WebObjects/VCInit.woa/wa/id-register".to_string(),
        );
        endpoints.insert(
            "id-query".to_string(),
            "https://init.ess.apple.com/WebObjects/VCInit.woa/wa/id-query".to_string(),
        );

        Self { endpoints }
    }
}
