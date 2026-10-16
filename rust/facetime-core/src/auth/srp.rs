//! GrandSlam SRP-6a cryptographic client calculations (RFC 5054 2048-bit group).

use hmac::{Hmac, Mac};
use num_bigint::{BigUint, RandBigInt};
use sha2::{Digest, Sha256};
use crate::bridge::error::FaceTimeCoreError;

/// RFC 5054 2048-bit safe prime modulus N in hex.
pub const RFC5054_N_HEX: &str = "\
AC6BDB41324A9A9BF166DE5E1389582FAF72B6651987EE07FC3192943DB56050\
A37329CBB4A099ED8193E0757767A13DD52312AB4B03310DCD7F48A9DA04FD50\
E8083969EDA7491A0A04186422472351F33F99F7CC972DF0E5B39A331A4E9ACC\
16CDBE8BEA9529E8A2ADC57F104079ABCD8002C10F849FFC70533BE0B5664970\
8E6F07CBFF467E7037E21EC57E60E3F392DAF560FA24A8DEF09CE69FC09D18F7\
571CDF75983CA1074A7E15E14500C05C029DC5F8CE44479C72F729C46998DA99\
D861494243474CB5E663FA9E412F51CE516CE6EA7614C90670A6034B717B81BC\
F0874E4A6B2B50152E5325512470A94A08C4A9E32242D53801F2EB8068FC93FB";

pub struct SrpContext {
    pub n: BigUint,
    pub g: BigUint,
    pub k: BigUint,
    pub a_secret: BigUint,
    pub a_public: BigUint,
}

impl Default for SrpContext {
    fn default() -> Self {
        Self::new()
    }
}

impl SrpContext {
    pub fn new() -> Self {
        let n = BigUint::parse_bytes(RFC5054_N_HEX.as_bytes(), 16).expect("Valid N hex");
        let g = BigUint::from(2u32);

        // k = SHA256(N || g)
        let mut hasher = Sha256::new();
        hasher.update(n.to_bytes_be());
        hasher.update(g.to_bytes_be());
        let k_bytes = hasher.finalize();
        let k = BigUint::from_bytes_be(&k_bytes);

        // a: 32 random bytes (256-bit ephemeral secret)
        let mut rng = rand::thread_rng();
        let a_secret = rng.gen_biguint(256);
        let a_public = g.modpow(&a_secret, &n);

        Self {
            n,
            g,
            k,
            a_secret,
            a_public,
        }
    }

    pub fn a_public_bytes(&self) -> Vec<u8> {
        let mut bytes = self.a_public.to_bytes_be();
        // Pad to 256 bytes if leading zeroes were stripped
        while bytes.len() < 256 {
            bytes.insert(0, 0);
        }
        bytes
    }

    pub fn calculate_proof_m1(
        &self,
        username: &str,
        password: &str,
        salt: &[u8],
        iterations: u32,
        b_bytes: &[u8],
        protocol: &str,
    ) -> Result<(Vec<u8>, Vec<u8>), FaceTimeCoreError> {
        let b = BigUint::from_bytes_be(b_bytes);
        if &b % &self.n == BigUint::from(0u32) {
            return Err(FaceTimeCoreError::AuthFailed {
                code: -20102,
                message: "Server ephemeral B mod N is zero".to_string(),
            });
        }

        // 1. Password pre-hashing
        let mut sha = Sha256::new();
        sha.update(password.as_bytes());
        let pass_hash = sha.finalize();

        let pass_srp = if protocol == "s2k_fo" {
            hex::encode(pass_hash).into_bytes()
        } else {
            pass_hash.to_vec()
        };

        // 2. PBKDF2
        let mut key_buf = [0u8; 32];
        pbkdf2::pbkdf2::<Hmac<Sha256>>(&pass_srp, salt, iterations, &mut key_buf)
            .map_err(|e| FaceTimeCoreError::AuthFailed {
                code: -20101,
                message: format!("PBKDF2 derivation failed: {}", e),
            })?;

        // 3. x = SHA256(s || KeyBuf)
        let mut sha_x = Sha256::new();
        sha_x.update(salt);
        sha_x.update(&key_buf);
        let x_bytes = sha_x.finalize();
        let x = BigUint::from_bytes_be(&x_bytes);

        // 4. u = SHA256(A || B)
        let mut sha_u = Sha256::new();
        sha_u.update(self.a_public_bytes());
        sha_u.update(b_bytes);
        let u_bytes = sha_u.finalize();
        let u = BigUint::from_bytes_be(&u_bytes);
        if u == BigUint::from(0u32) {
            return Err(FaceTimeCoreError::AuthFailed {
                code: -20103,
                message: "Scrambler parameter u is zero".to_string(),
            });
        }

        // 5. Shared secret S = (B - k * (g^x mod N))^(a + u * x) mod N
        let gx = self.g.modpow(&x, &self.n);
        let kgx = (&self.k * &gx) % &self.n;

        let base = if b >= kgx {
            (&b - &kgx) % &self.n
        } else {
            (&self.n - ((&kgx - &b) % &self.n)) % &self.n
        };

        let exp = &self.a_secret + (&u * &x);
        let s = base.modpow(&exp, &self.n);

        // 6. Session Key K = SHA256(S)
        let mut sha_k = Sha256::new();
        sha_k.update(s.to_bytes_be());
        let k_session = sha_k.finalize().to_vec();

        // 7. Client Proof M1 = SHA256(H(N) ^ H(g) || H(u) || s || A || B || K)
        let hn = Sha256::digest(self.n.to_bytes_be());
        let hg = Sha256::digest(self.g.to_bytes_be());
        let mut h_xor = [0u8; 32];
        for i in 0..32 {
            h_xor[i] = hn[i] ^ hg[i];
        }

        let hu = Sha256::digest(username.as_bytes());

        let mut sha_m1 = Sha256::new();
        sha_m1.update(&h_xor);
        sha_m1.update(&hu);
        sha_m1.update(salt);
        sha_m1.update(self.a_public_bytes());
        sha_m1.update(b_bytes);
        sha_m1.update(&k_session);
        let m1 = sha_m1.finalize().to_vec();

        Ok((m1, k_session))
    }

    pub fn verify_m2(a_bytes: &[u8], m1: &[u8], k: &[u8], m2_server: &[u8]) -> bool {
        let mut sha_m2 = Sha256::new();
        sha_m2.update(a_bytes);
        sha_m2.update(m1);
        sha_m2.update(k);
        let expected_m2 = sha_m2.finalize();
        expected_m2.as_slice() == m2_server
    }
}
