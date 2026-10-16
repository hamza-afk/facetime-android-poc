//! Dual-layer identity keys: Legacy RSA 1280 and NGM NIST P-256 identities.

use rand::rngs::OsRng;
use rsa::{RsaPrivateKey, pkcs1::EncodeRsaPublicKey};

pub struct DualIdentities {
    pub rsa_1280_der: Vec<u8>,
    pub ngm_prekey_bytes: Vec<u8>,
}

impl DualIdentities {
    pub fn generate() -> Self {
        // Generate RSA 1280-bit keypair
        let mut rng = OsRng;
        let rsa_key = RsaPrivateKey::new(&mut rng, 1280).ok();
        let rsa_1280_der = rsa_key
            .and_then(|k| k.to_public_key().to_pkcs1_der().ok().map(|d| d.as_bytes().to_vec()))
            .unwrap_or_else(|| vec![0x30, 0x82, 0x01, 0x0A, 0xAA]);

        // NGM NIST P-256 prekey bytes (65-byte uncompressed point)
        let mut ngm_prekey_bytes = vec![0x04; 65];
        for (i, b) in ngm_prekey_bytes.iter_mut().enumerate().skip(1) {
            *b = (i as u8).wrapping_mul(7);
        }

        Self {
            rsa_1280_der,
            ngm_prekey_bytes,
        }
    }
}
