# Apple Identity Services (IDS) Registration & Key Management Architecture

> **Project**: FaceTime Android Standalone Proof-of-Concept  
> **Document**: `docs/architecture/ids_registration.md`  
> **Source References**: `vendor/rustpush/src/ids/user.rs:245-1040`, `vendor/rustpush/src/auth.rs:526-610`, `vendor/rustpush/src/util.rs:58`  
> **Protocol Components**: VCInit Service Bag, Multi-Key HTTP Header Signing, Auth Certificate Issuance, Dual-Layer Identity Keys (Legacy RSA 1280 vs NGM P-256), Madrid/ESS Registration, Payload Encryption (`pair` vs `pair-ec`)  
> **Version**: 1.0 (Milestone 1 Architecture Baseline)  

---

## 1. Identity Services Overview & Service Bag

Apple Identity Services (IDS) is the cryptographic directory and routing authority underlying iMessage and FaceTime. IDS binds an Apple Account (identified by verified email handles and telephone numbers) to physical devices, routing push tokens, and public encryption keys.

```
[Android Client]
       │
       │ 1. GET /WebObjects/VCInit.woa/wa/getBag?ix=3
       ▼
[init.ess.apple.com] ──> Returns IDS Service Endpoints Bag
       │
       │ 2. POST /WebObjects/VCInit.woa/wa/id-authenticate-ds-id
       ▼      (Auth CSR signed with Profile ID + Delegate Auth Token)
[Apple IDS Sub-CA] ──> Returns Auth Certificate (X.509 DER)
       │
       │ 3. POST /WebObjects/VCInit.woa/wa/id-get-handles
       ▼      (Dual RSA-signed headers: APS Key + Auth Key)
[init.ess.apple.com] ──> Returns verified handles (mailto:user@example.com)
       │
       │ 4. Generate Dual Identity Keypairs (RSA 1280 + NGM P-256)
       │
       │ 5. POST /WebObjects/VCInit.woa/wa/id-register
       ▼      (Validation-data + Public Keys + Services: madrid, ess, facetime)
[init.ess.apple.com] ──> Returns registered service certs + next-hbi
```

### 1.1 The VCInit Service Bag
All IDS operations query endpoints defined in the VCInit service bag:
- **Endpoint**: `GET https://init.ess.apple.com/WebObjects/VCInit.woa/wa/getBag?ix=3` (HTTP/1.1)
- **Response**: Apple binary property list containing nested base64-encoded plists with key service endpoints:
  - `id-authenticate-ds-id`: Endpoint for auth certificate acquisition (`https://init.ess.apple.com/...`).
  - `id-get-handles`: Endpoint for discovering account handles.
  - `id-register`: Endpoint for committing service identities.
  - `id-query`: Directory lookup endpoint for recipient public keys and push tokens.

---

## 2. Multi-Key Request Header Signing Protocol

Every HTTP request to an IDS endpoint requires cryptographic signature headers computed using **two distinct private keys**:
1. **Push Signatures (`x-push-*`)**: Proves possession of the private key corresponding to the device's APS Courier Push Certificate (`aps_keypair`).
2. **Auth Signatures (`x-auth-*`)**: Proves possession of the private key corresponding to the user's IDS Auth Certificate (`auth_keypair`).

### 2.1 HTTP Request Envelope Structure
```http
POST /WebObjects/VCInit.woa/wa/id-register HTTP/1.1
Host: init.ess.apple.com
User-Agent: com.apple.invitation-registration [macOS,14.5,23F79,MacBookPro18,1]
x-protocol-version: 1760
x-push-token: <base64_encoded_32_byte_aps_token>
content-type: application/x-apple-plist
content-encoding: gzip
accept-encoding: gzip

x-push-nonce: <base64_17_byte_nonce>
x-push-sig: <base64_signature_bytes>
x-push-cert: <base64_aps_cert_der>

x-auth-user-id-0: <user_dsid>
x-auth-nonce-0: <base64_17_byte_nonce>
x-auth-sig-0: <base64_signature_bytes>
x-auth-cert-0: <base64_auth_cert_der>
```

### 2.2 Nonce Generation Algorithm
Both `x-push-nonce` and `x-auth-nonce-0` are 17-byte buffers constructed as follows:
- **Byte 0**: Protocol version marker (`0x01`).
- **Bytes 1..8**: Current Unix timestamp in milliseconds as a 64-bit unsigned big-endian integer.
- **Bytes 9..16**: 8 cryptographically secure pseudorandom bytes.

### 2.3 Signature Payload Assembly
The signature covers the URI path, query parameters, body payload, and device push token:

$$\text{Payload} = \text{Nonce} \,||\, \text{len}(\text{bag}) \,||\, \text{bag} \,||\, \text{len}(\text{query}) \,||\, \text{query} \,||\, \text{len}(\text{body}) \,||\, \text{body} \,||\, \text{len}(\text{token}) \,||\, \text{token}$$

Where:
- $\text{len}(X)$ is serialized as a 4-byte big-endian unsigned integer.
- $\text{bag}$ is the URI path (e.g. `/WebObjects/VCInit.woa/wa/id-register`).
- $\text{query}$ is the raw query string (or empty byte slice).
- $\text{body}$ is the gzipped binary plist payload bytes.
- $\text{token}$ is the raw 32-byte APS push token.

### 2.4 RSA-SHA1 Signing
1. The payload buffer is signed using the respective RSA private key with **RSA-SHA1 and PKCS#1 v1.5 padding**.
2. The signature is prefixed with two version bytes: `[0x01, 0x01]`.
3. The resulting byte array is base64-encoded for the header:
   $$\text{HeaderValue} = \text{base64}([0x01, 0x01] \,||\, \text{RSA-SHA1-Sign}(\text{key}, \text{Payload}))$$

---

## 3. Step-by-Step Registration Pipeline

### Step 1: `id-authenticate-ds-id` (Auth Certificate Issuance)
- **Key Generation**: Client generates a 2048-bit RSA keypair (`auth_keypair`).
- **CSR Generation**: Client generates a PKCS#10 Certificate Signing Request (CSR) with:
  - Common Name: $\text{hex\_lowercase}(\text{SHA1}(\text{ids\_profile\_id}))$
- **Submission**: Client posts the CSR along with the delegate `auth_token` acquired during Apple Account login.
- **Response**: Apple IDS Sub-CA signs and returns the `auth-cert` (X.509 DER format).

### Step 2: `id-get-handles` (Account Handle Discovery)
- Client signs an empty request using both `x-push-*` and `x-auth-*` headers.
- Apple returns an array of verified handle strings authorized for this Apple Account:
  - `mailto:user@example.com`
  - `tel:+1234567890` (if registered)

### Step 3: Dual-Layer Identity Key Generation
Apple's modern identity architecture requires **two distinct sets of cryptographic identities** per registered device:

1. **Legacy Identity (`IDSUserIdentity`)**:
   - **Encryption Keypair**: RSA 1280-bit keypair (`public_message_identity_key`).
   - **Signing Keypair**: NIST P-256 (secp256r1) ECDSA keypair.
   - Used for legacy clients and fallback signaling.
2. **Next-Generation Messaging Identity (`IDSNGMIdentity`)**:
   - **Device Identity Key**: NIST P-256 EC keypair (`ngm-public-identity`).
   - **Ephemeral Pre-Key**: NIST P-256 EC keypair.
   - **Pre-Key Signature**: Device Identity Key signs the prekey public point with ECDSA P-256 SHA-256.
   - **Protobuf Serialization**: Serialized as Protobuf message into dictionary entry `public-message-ngm-device-prekey-data-key`.

### Step 4: `id-register` (Service Identity Commitment)
The client posts the full identity bundle to Apple IDS:

```xml
<plist version="1.0">
<dict>
    <key>validation-data</key>
    <data>BASE64_ABSINTHE_NAC_VALIDATION_DATA</data>
    <key>services</key>
    <array>
        <string>com.apple.madrid</string>
        <string>com.apple.ess</string>
        <string>com.apple.private.alloy.facetime.multi</string>
    </array>
    <key>handles</key>
    <array>
        <string>mailto:user@example.com</string>
    </array>
    <key>public-message-identity-key</key>
    <data>DER_ENCODED_RSA_1280_PUBLIC_KEY</data>
    <key>public-message-ngm-device-prekey-data-key</key>
    <data>PROTOBUF_PREKEY_DATA_BYTES</data>
    <key>push-token</key>
    <data>32_BYTES_APS_PUSH_TOKEN</data>
</dict>
</plist>
```

#### Server Validation & Response:
- **Status 0**: Success. Server returns service certificates (`cert`) for each registered service, along with heartbeat refresh interval `next-hbi` (typically 86,400 seconds).
- **Status 6005**: Device validation rejected. Trigger of the Hard Go/No-Go Decision Gate.
- **Status 6009**: Account disabled / restricted.

---

## 4. Payload Encryption Specification (`pair` vs `pair-ec`)

When communicating with recipient endpoints (for directory lookups or invite signaling), IDS payloads are end-to-end encrypted under one of two schemes:

### 4.1 Legacy Encryption Scheme (`pair`)
1. **Symmetric Key**: Sender generates a random 16-byte AES key.
2. **RSA Wrapping**: The AES key and the first 100 bytes of the message are encrypted under the recipient's RSA 1280 public key using RSA-OAEP with SHA-1 MGF1.
3. **Stream Cipher**: The remainder of the message is encrypted using AES-128-CTR with static IV:
   `00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01`
4. **Sender Signature**: Sender signs the encrypted ciphertext using its P-256 ECDSA signing key.

### 4.2 Modern Next-Generation Scheme (`pair-ec`)
FaceTime and modern iOS devices enforce `pair-ec` encryption:
1. **Ephemeral Key Exchange**:
   - Sender generates an ephemeral P-256 keypair $(e_{\text{priv}}, E_{\text{pub}})$.
   - Sender performs ECDH with recipient's published NGM pre-key $R_{\text{pre}}$:
     $$S_{\text{shared}} = \text{ECDH}(e_{\text{priv}}, R_{\text{pre}})$$
2. **Key Derivation (HKDF)**:
   $$\text{Key}_{\text{aes256}}, \text{IV}_{\text{ctr64}} = \text{HKDF-SHA256}(S_{\text{shared}}, \text{salt}=\text{None}, \text{info}=\text{"NGMKeyDerivation"})$$
3. **Inner Message Protobuf**:
   - Plaintext payload (e.g. `FTWireMessage`) is packed into Protobuf `idsp::InnerMessage`.
4. **Ciphertext**:
   - Encrypted using AES-256-CTR with the derived 64-bit counter IV.
5. **Outer Message Protobuf**:
   - Wrapped into Protobuf `idsp::OuterMessage` containing:
     - Ephemeral public key $E_{\text{pub}}$
     - Recipient prekey identifier
     - Sender ECDSA signature over the ciphertext

---

## 5. Android Diagnostic Stepper Stages

The Android Jetpack Compose diagnostic application tracks registration progress through seven explicit, verifiable pipeline stages:

```
[1. IDS_AUTH_CONTEXT_READY]
            │
            ▼
[2. IDS_BAG_LOADED]
            │
            ▼
[3. IDS_PUSH_TOKEN_ACQUIRED]
            │
            ▼
[4. IDS_IDENTITIES_GENERATED]
            │
            ▼
[5. IDS_SERVICE_REGISTERED]
            │
            ▼
[6. IDS_REGISTERED]  <── (SUCCESS: Ready for Outgoing FaceTime Calls)
            │
            └──> [7. IDS_REGISTRATION_FAILED] (TERMINAL: Validation Reject)
```

1. **`IDS_AUTH_CONTEXT_READY`**: Valid GrandSlam session, PET, DSID, and IDS delegate auth token obtained from Auth phase.
2. **`IDS_BAG_LOADED`**: VCInit service bag successfully parsed from `init.ess.apple.com`.
3. **`IDS_PUSH_TOKEN_ACQUIRED`**: Active APS courier connection established; 32-byte push token ready for header signing.
4. **`IDS_IDENTITIES_GENERATED`**: Dual RSA 1280 and NGM P-256 identity keypairs generated and signed locally.
5. **`IDS_SERVICE_REGISTERED`**: Dual-signed `id-register` HTTP request transmitted with validation data.
6. **`IDS_REGISTERED`**: Apple IDS returns Status 0 with signed service certificates for `com.apple.ess` and `com.apple.private.alloy.facetime.multi`.
7. **`IDS_REGISTRATION_FAILED`**: Server rejected registration; triggers Hard Go/No-Go blocker workflow.
