# Apple Account Authentication Architecture

> **Project**: FaceTime Android Standalone Proof-of-Concept  
> **Document**: `docs/architecture/apple_account_auth.md`  
> **Source References**: `vendor/rustpush/third_party/apple-private-apis/icloud-auth/src/client.rs:682-1050`, `vendor/rustpush/src/auth.rs:377-526`  
> **Protocol Components**: GrandSlam GSA, SRP-6a (RFC 5054 2048-bit), PBKDF2-HMAC-SHA256, SPD AES-CBC Decryption, 2FA Challenge, iCloud Delegate Login  
> **Version**: 1.0 (Milestone 1 Architecture Baseline)  

---

## 1. Overview & Service Architecture

Authentication with Apple services is not a single OAuth2 or simple password exchange. Instead, it is anchored on Apple's **GrandSlam Authentication Service (GSA)**, which executes a Secure Remote Password (SRP-6a) mutual zero-knowledge proof. 

GrandSlam protects user credentials from eavesdropping and rogue server impersonation while issuing federated, cryptographically signed service tokens:

```
[Android Client]
       │
       │ 1. SRP-6a Init (Client Ephemeral A)
       ▼
[gsa.apple.com/grandslam/GsService2]
       │
       │ 2. Server Parameters (Salt, Iterations, Server Ephemeral B)
       ▼
[Android Client]
       │
       │ 3. SRP-6a Complete (Client Proof M1)
       ▼
[gsa.apple.com/grandslam/GsService2]
       │
       │ 4. Server Proof M2 + AES-CBC Encrypted SPD Payload
       ▼
[Android Client] (Decrypts SPD -> Extracts PET, DSID, adsid)
       │
       │ 5. 2FA Trigger & Verification (if required)
       ▼
[gsa.apple.com/auth/verify/trusteddevice] & [/validate]
       │
       │ 6. Delegate Login with PET (setup.icloud.com)
       ▼
[setup.icloud.com/setup/signin/v2/login]
       │
       ▼
[Android Client] (Acquires IDS Delegate auth-token & profile-id)
```

### Key Token Taxonomy:
- **PET (`com.apple.gs.idms.pet`)**: Password Equivalent Token. A long-lived, high-entropy cryptographic ticket that replaces the user's raw password for subsequent delegate authorizations.
- **DSID (`DsPrsId`)**: Directory Services Identifier. A unique 64-bit integer assigned to every Apple Account.
- **adsid**: Alphanumeric Directory Services Identifier (e.g. `W1092834712`). Used in HTTP identity headers (`X-Apple-Identity-Token`).
- **IDS Delegate Auth Token**: Scoped authorization bearer token specifically issued by `setup.icloud.com` for Apple Identity Services (`com.apple.private.ids`).

---

## 2. GSA Init Request & Cryptographic Parameters

### 2.1 Cryptographic Group: RFC 5054 2048-bit SRP
GSA employs the RFC 5054 2048-bit safe prime group ($G_{2048}$):
- **Generator**: $g = 2$
- **Prime modulus $N$**: 2048-bit safe prime ($N = 2q + 1$):
  ```
  AC6BDB41 324A9A9B F166DE5E 1389582F AF72B665 1987EE07 FC319294 3DB56050
  A37329CB B4A099ED 8193E075 7767A13D D52312AB 4B03310D CD7F48A9 DA04FD50
  E8083969 EDA7491A 0A041864 22472351 F33F99F7 CC972DF0 E5B39A33 1A4E9ACC
  16CDBE8B EA9529E8 A2ADC57F 104079AB CD8002C1 0F849FFC 70533BE0 B5664970
  8E6F07CB FF467E70 37E21EC5 7E60E3F3 92DAF560 FA24A8DE F09CE69F C09D18F7
  571CDF75 983CA107 4A7E15E1 4500C05C 029DC5F8 CE44479C 72F729C4 6998DA99
  D8614942 43474CB5 E663FA9E 412F51CE 516CE6EA 7614C906 70A6034B 717B81BC
  F0874E4A 6B2B5015 2E532551 2470A94A 08C4A9E3 2242D538 01F2EB80 68FC93FB
  ```
- **Multiplier parameter $k$**:
  $$k = H(N \,||\, g) = \text{SHA256}(N \,||\, g)$$

### 2.2 Client Ephemeral Generation
The client generates 32 cryptographically secure random bytes:
$$a \in [1, N-1]$$
The client calculates its public ephemeral $A$:
$$A = g^a \pmod N$$
$A$ is a 256-byte unsigned big-endian integer, serialized as base64 in the `<data>` tag `A2k`.

### 2.3 GSA Init Request Plist
- **Endpoint**: `POST https://gsa.apple.com/grandslam/GsService2`
- **Content-Type**: `text/xml` or `application/x-apple-plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Header</key>
    <dict>
        <key>Version</key>
        <string>1.0.1</string>
    </dict>
    <key>Request</key>
    <dict>
        <key>A2k</key>
        <data>BASE64_ENCODED_CLIENT_EPHEMERAL_A_256_BYTES</data>
        <key>cpd</key>
        <dict>
            <key>X-Apple-I-Client-Time</key>
            <string>2026-10-16T03:15:00Z</string>
            <key>X-Apple-I-MD</key>
            <string>BASE64_ANISETTE_DATA</string>
            <key>X-Apple-I-MD-LU</key>
            <string>BASE64_LOCAL_USER_UUID</string>
            <key>X-Apple-I-MD-M</key>
            <string>BASE64_MACHINE_ID</string>
            <key>X-Apple-I-MD-RINFO</key>
            <string>17106176</string>
            <key>X-Apple-I-SRL-NO</key>
            <string>SERIAL_NUMBER</string>
            <key>X-Apple-I-TimeZone</key>
            <string>UTC</string>
            <key>bootstrap</key>
            <true/>
            <key>icsdet</key>
            <true/>
        </dict>
        <key>o</key>
        <string>init</string>
        <key>ps</key>
        <array>
            <string>s2k</string>
            <string>s2k_fo</string>
        </array>
        <key>u</key>
        <string>user@example.com</string>
    </dict>
</dict>
</plist>
```

### 2.4 GSA Init Response Plist
```xml
<plist version="1.0">
<dict>
    <key>Response</key>
    <dict>
        <key>B</key>
        <data>BASE64_SERVER_EPHEMERAL_B_256_BYTES</data>
        <key>c</key>
        <string>CHALLENGE_STRING_TOKEN</string>
        <key>i</key>
        <integer>20000</integer>
        <key>s</key>
        <data>BASE64_SALT_BYTES</data>
        <key>sp</key>
        <string>s2k_fo</string>
        <key>status</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

---

## 3. Password Derivation & SRP-6a Proof Calculation

### 3.1 Password Pre-Hashing
Apple supports two password pre-hashing schemes indicated by the server's `sp` response:
1. $P_{raw} = \text{UTF-8}(Password)$
2. $H_{pass} = \text{SHA256}(P_{raw})$ (32 raw bytes)
3. If `sp == "s2k_fo"`:
   $$P_{srp} = \text{hex\_lowercase}(H_{pass}) \quad \text{(64-character ASCII string)}$$
4. If `sp == "s2k"`:
   $$P_{srp} = H_{pass} \quad \text{(32 raw bytes)}$$

### 3.2 Key Derivation (PBKDF2)
Using the server-provided salt $s$ (typically 16 bytes) and iteration count $i$ (typically 20,000 or 40,000):
$$\text{KeyBuf} = \text{PBKDF2-HMAC-SHA256}(P_{srp}, s, i, 32)$$

### 3.3 Private Key $x$
$$x = \text{SHA256}(s \,||\, \text{KeyBuf})$$

### 3.4 Scrambler Parameter $u$
The random scrambling parameter $u$ ties both ephemerals:
$$u = \text{SHA256}(A \,||\, B)$$
If $u \equiv 0 \pmod N$, abort execution.

### 3.5 Verifier Premaster Secret $S$ and Session Key $K$
The client computes the shared secret $S$:
$$S = (B - k \cdot (g^x \pmod N))^{(a + u \cdot x)} \pmod N$$
The cryptographic session key $K$ is derived:
$$K = \text{SHA256}(S)$$

### 3.6 Client Proof $M_1$
The client generates proof $M_1$ demonstrating possession of $K$ without exposing $x$:
$$H_N = \text{SHA256}(N), \quad H_g = \text{SHA256}(g)$$
$$H_{xor} = H_N \oplus H_g$$
$$H_u = \text{SHA256}(u_{name}) \quad \text{where } u_{name} = \text{UTF-8}(user@example.com)$$
$$M_1 = \text{SHA256}(H_{xor} \,||\, H_u \,||\, s \,||\, A \,||\, B \,||\, K)$$

---

## 4. GSA Complete Request & SPD Decryption

### 4.1 GSA Complete Request Plist
The client submits $M_1$ and the challenge token $c$:

```xml
<dict>
    <key>Header</key>
    <dict>
        <key>Version</key>
        <string>1.0.1</string>
    </dict>
    <key>Request</key>
    <dict>
        <key>M1</key>
        <data>BASE64_CLIENT_PROOF_M1_32_BYTES</data>
        <key>c</key>
        <string>CHALLENGE_STRING_TOKEN</string>
        <key>cpd</key>
        <dict>...</dict>
        <key>o</key>
        <string>complete</string>
        <key>u</key>
        <string>user@example.com</string>
    </dict>
</dict>
```

### 4.2 GSA Complete Response Plist
```xml
<dict>
    <key>Response</key>
    <dict>
        <key>M2</key>
        <data>BASE64_SERVER_PROOF_M2_32_BYTES</data>
        <key>spd</key>
        <data>BASE64_AES_256_CBC_ENCRYPTED_SPD_BYTES</data>
        <key>status</key>
        <integer>0</integer>
    </dict>
    <key>status</key>
    <dict>
        <key>au</key>
        <string>trustedDeviceSecondaryAuth</string>
        <key>ec</key>
        <integer>0</integer>
    </dict>
</dict>
```

### 4.3 Server Proof Verification ($M_2$)
Before decrypting sensitive payload bytes, the client must verify the server's proof $M_2$:
$$M_2' = \text{SHA256}(A \,||\, M_1 \,||\, K)$$
If $M_2 \neq M_2'$, the server does not know $K$ and is an imposter. Abort immediately.

### 4.4 SPD Decryption Algorithm
The `spd` (Secondary Payload Data) dictionary contains the actual credentials encrypted with AES-256-CBC.
1. **Derive Extra Keys**:
   $$\text{Key}_{extra} = \text{HMAC-SHA256}(K, \text{"extra data key:"})$$
   $$\text{IV}_{extra} = \text{HMAC-SHA256}(K, \text{"extra data iv:"})[0..16]$$
2. **Decrypt**:
   - Decrypt `spd` payload using AES-256-CBC with $\text{Key}_{extra}$ and $\text{IV}_{extra}$.
   - Strip standard PKCS#7 padding.
   - Deserialize the resulting buffer as an Apple Property List.
3. **Extracted Fields**:
   - `com.apple.gs.idms.pet`: Password Equivalent Token string.
   - `adsid`: Alphanumeric Directory Services ID string.
   - `DsPrsId`: 64-bit integer DSID.
   - `com.apple.gs.idms.hb`: Heartbeat token string.

---

## 5. Two-Factor Authentication (2FA) Workflows

If the response `status.au` is `trustedDeviceSecondaryAuth`, 2FA verification is required before full session privileges are granted.

### 5.1 Triggering Trusted Device Prompt
- **Endpoint**: `GET https://gsa.apple.com/auth/verify/trusteddevice`
- **Headers**:
  - `X-Apple-Identity-Token`: `base64(adsid:GsIdmsToken)`
  - Anisette Headers (`X-Apple-I-MD`, `X-Apple-I-MD-M`, etc.)
- **Effect**: Apple's push servers send a high-priority push notification to all genuine Apple devices enrolled under this account, displaying the modal 6-digit challenge code and approximate location map.

### 5.2 Validating Security Code
When the user enters the 6-digit code on Android:
- **Endpoint**: `GET https://gsa.apple.com/grandslam/GsService2/validate`
- **Headers**:
  - `security-code`: `123456`
  - `X-Apple-Identity-Token`: `base64(adsid:GsIdmsToken)`
  - Anisette Headers
- **Response Headers**:
  - `X-Apple-GS-Token`: Federated GrandSlam token.
  - `X-Apple-PE-Token`: Upgraded Password Equivalent Token.
  - `X-Apple-HB-Token`: Heartbeat token.

---

## 6. Delegate Login for Identity Services (`com.apple.private.ids`)

To communicate with Apple Identity Services (IDS) and FaceTime, the client must exchange its PET for an IDS-scoped delegate auth token via iCloud Setup:

- **Endpoint**: `POST https://setup.icloud.com/setup/signin/v2/login`
- **Authorization**: `Basic base64(apple_id:pet)`
- **Headers**:
  - `User-Agent`: `com.apple.invitation-registration [macOS,14.5,23F79,MacBookPro18,1]`
  - `X-Mme-Nas-Qualify`: `<base64_absinthe_nac_signature>`
  - `Content-Type`: `text/plist`

### Request Plist:
```xml
<plist version="1.0">
<dict>
    <key>apple-id</key>
    <string>user@example.com</string>
    <key>delegates</key>
    <dict>
        <key>com.apple.private.ids</key>
        <dict>
            <key>client-id</key>
            <string>550E8400-E29B-41D4-A716-446655440000</string>
        </dict>
        <key>com.apple.mobileme</key>
        <dict/>
    </dict>
</dict>
</plist>
```

### Response Processing:
1. Extract `response["delegates"]["com.apple.private.ids"]["auth-token"]` $\to$ `ids_auth_token`.
2. Extract `response["delegates"]["com.apple.private.ids"]["profile-id"]` $\to$ `ids_profile_id`.
3. Store both tokens in Android Keystore for use in IDS header signing (`id-authenticate-ds-id`).

---

## 7. Error Code Taxonomy & Session Recovery

| Code | Name | Root Cause | Handling Strategy |
|---|---|---|---|
| `-20101` | `AuthBadPassword` | Password pre-hash verification failed. | Prompt user for password re-entry; clear cached credentials. |
| `-22406` | `Auth2FARequired` | Account requires two-factor verification. | Transition FSM to `AUTH_2FA_REQUIRED` and trigger prompt. |
| `-22411` | `AuthInvalid2FACode` | 6-digit code incorrect or expired. | Prompt user to retry; re-trigger push if code timed out. |
| `401` | `Unauthorized` | Anisette headers rejected by GSA backend. | Check Anisette timestamp drift; regenerate local machine UUID. |
| `403` | `Forbidden` | Apple Account flagged or rate-limited. | Halt retry loops; display account security notice to user. |
| `6005` | `IDSRegistrationRejected` | Server rejected synthetic validation data. | Enforce Hard Go/No-Go rule; compile blocker report. |
