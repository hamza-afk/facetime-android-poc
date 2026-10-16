# Apple Push Notification Service (APS) Courier & Wire Protocol Specification

> **Project**: FaceTime Android Standalone Proof-of-Concept  
> **Document**: `docs/architecture/aps_push.md`  
> **Source References**: `vendor/rustpush/src/aps.rs:660-1280`, `vendor/rustpush/src/util.rs:57-70`, `vendor/rustpush/src/activation.rs:67-110`  
> **Protocol Components**: APNs Courier Discovery, TLS ALPN (`apns-pack-v1`), Binary & Packed Framing, Command Set (`0x07`–`0x14`), Push Certificate Activation, Topic Filtering, Persistent Foreground Service  
> **Version**: 1.0 (Milestone 1 Architecture Baseline)  

---

## 1. Courier Discovery & Network Architecture

The Apple Push Notification service (APS / APNs) maintains persistent, bi-directional multiplexed TCP/TLS connections between client devices and Apple's courier gateway cluster.

```
+-------------------------------------------------------------------------+
|                  1. Bootstrap Discovery (HTTP/1.1)                     |
|  GET http://init-p01st.push.apple.com/bag -> Returns courier hostname   |
|                                              & hostcount partition (50) |
+-------------------------------------------------------------------------+
                                    │
                                    ▼
+-------------------------------------------------------------------------+
|                    2. Secure TLS Courier Socket                         |
|  Connect to {1..50}-courier.push.apple.com:5223 (Fallback Port 443)      |
|  TLS ALPN: ["apns-pack-v1", "apns-security-v3"]                         |
|  Root CA Anchors: Apple Root CA, Apple Root CA - G2, Apple Root CA - G3 |
+-------------------------------------------------------------------------+
                                    │
                                    ▼
+-------------------------------------------------------------------------+
|                     3. Courier Session Handshake                        |
|  Frame 0x07 (Connect): Client Push Cert + Timestamp Nonce + RSA Sig     |
|  Frame 0x08 (ConnectResponse): 32-byte assigned Push Token              |
|  Frame 0x09 (Filter): Topic Hash Whitelist (madrid, ess, facetime)      |
|  Frame 0x0c / 0x0d: Periodic 60s Heartbeat Ping/Pong Keepalive          |
+-------------------------------------------------------------------------+
```

### 1.1 Courier Configuration Bag Fetch
Before initiating a TLS socket, the client queries Apple's bootstrap bag endpoint:
- **URL**: `http://init-p01st.push.apple.com/bag` (HTTP/1.1)
- **Response**: Apple Property List:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>APNSCourierHostname</key>
      <string>courier.push.apple.com</string>
      <key>APNSCourierHostcount</key>
      <integer>50</integer>
      <key>APNSCourierKeepAliveInterval</key>
      <integer>1200</integer>
  </dict>
  </plist>
  ```

### 1.2 Cluster Partitioning & Addressing
- The courier cluster is partitioned into $N$ host indices ($1 \le k \le \text{APNSCourierHostcount}$).
- The client generates a random index $k \in [1, 50]$:
  $$\text{Hostname} = k \text{ . } \text{courier.push.apple.com}$$
  *(e.g., `17-courier.push.apple.com`, `42-courier.push.apple.com`)*
- **Primary TCP Port**: `5223` (standard APNs outbound port).
- **Fallback TCP Port**: `443` (negotiated when enterprise/carrier firewalls drop outbound port 5223).

### 1.3 TLS Configuration & Certificate Validation
- **Server Name Indication (SNI)**: Always set to the root cluster domain `courier.push.apple.com` regardless of the numerical host prefix.
- **Application-Layer Protocol Negotiation (ALPN)**:
  - Client offers: `["apns-pack-v1", "apns-security-v3"]`
  - Server selects: `apns-pack-v1` (enables packed frame compression).
- **Custom Certificate Validation**:
  - The courier server presents a certificate chain issued by an Apple Private Sub-CA.
  - The client must validate the chain against Apple's Root CAs (Apple Root CA, Apple Root CA - G2, Apple Root CA - G3) and ignore generic public WebPKI roots.

---

## 2. Push Certificate Activation Protocol

Before the courier accepts a `Connect` frame (`0x07`), the client must present a valid Apple-signed Client Push Certificate (`x-push-cert`).

### 2.1 The Activation Exchange
1. Client generates an RSA 1024-bit keypair (`aps_keypair`).
2. Client prepares a Certificate Signing Request (CSR) in PKCS#10 format.
3. Client posts the CSR to Apple's Albert activation service:
   - **Endpoint**: `https://albert.apple.com/deviceservices/deviceActivation`
   - **Payload**: `ActivationInfoXML` signed with FairPlay NAC DRM.
4. **Hardware Cryptographic Barrier**:
   - Albert verifies that the activation payload originates from genuine Apple silicon containing valid factory-burned cryptographic fuses.
   - Clean Android devices cannot generate genuine FairPlay signatures; Albert returns `HTTP 400 Bad Request` (`AlbertCertParseError`).
   - In baseline testing (`ExistingRustpushValidationProvider`), a pre-activated or exported client push certificate is utilized to establish the courier socket.

---

## 3. Wire Protocol Framing

APS supports two wire protocols over TLS: raw binary framing and packed framing (`apns-pack-v1`).

### 3.1 Raw Binary Frame Layout
Used in legacy connections or when ALPN negotiation is unavailable:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Command (1B) |                 Frame Length (4B)             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Attribute Sequence...                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

Each Attribute:
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Item ID (1B)  |            Item Value Length (2B)             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Item Value (Length Bytes)                 |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 3.2 Packed Frame Protocol (`apns-pack-v1`)
When negotiated via ALPN, the courier switches to a high-density HPACK-inspired packed framing format:
1. **Command Code**: 1 byte (`0x07`, `0x08`, `0x09`, `0x0a`, etc.).
2. **Variable-Length Length Prefix**: Encoded as 7-bit continuation chunks.
3. **Dynamic String Caching**:
   - Maintains a 32-entry dynamic key dictionary and a 4096-byte string value cache.
   - The most-significant bit (MSB) of an attribute key byte signals whether the string is referenced from the cache (`1`) or serialized as a literal string (`0`).
   - Drastically reduces mobile telemetry overhead on cellular radios.

---

## 4. Exhaustive Command Specification

| Command Byte | Command Name | Direction | Attribute ID | Attribute Name | Data Type | Description |
|---|---|---|---|---|---|---|
| **`0x07`** | `Connect` | Client $\to$ Courier | `1` | Token | `[u8; 32]` | Previously cached push token (omitted on fresh initial handshake). |
| | | | `2` | State | `u32 BE` | Connection state (constant `1`). |
| | | | `5` | Presence Flags | `u32 BE` | Client flags (`0b01000001` = `0x41`, indicating dual-stack IPv4/IPv6 capability). |
| | | | `0x0c` | Client Certificate | `[u8]` | DER-encoded X.509 Apple Client Push Certificate. |
| | | | `0x0d` | Nonce | `[u8; 17]` | Connection nonce: `[0x00] || timestamp_ms (8B) || random (8B)`. |
| | | | `0x0e` | Signature | `[u8]` | Nonce signature: `[0x01, 0x01] || RSA_SHA1_Sign(nonce)`. |
| | | | `0x10` | Protocol Version | `u32 BE` | Courier protocol revision (constant `9`). |
| **`0x08`** | `ConnectResponse` | Courier $\to$ Client | `1` | Status | `u8` | Status: `0` = Success, `1` = Bad token, `2` = Certificate rejected, `3` = Server error. |
| | | | `3` | Push Token | `[u8; 32]` | **32-byte assigned Apple Push Token** for this device. |
| **`0x09`** | `Filter` | Client $\to$ Courier | `1` | Push Token | `[u8; 32]` | Current 32-byte device push token. |
| | | | `2` | Enabled Topics | `[[u8; 20]]` | Array of 20-byte SHA-1 hashes of topics the client wants to receive. |
| | | | `3` | Ignored Topics | `[[u8; 20]]` | Array of 20-byte SHA-1 hashes of silenced topics. |
| | | | `4` | Opportunistic | `[[u8; 20]]` | Array of opportunistic delivery topics. |
| | | | `5` | Paused Topics | `[[u8; 20]]` | Array of temporarily suspended topics. |
| **`0x0a`** | `Notification` | Courier $\to$ Client | `1` | Topic Hash | `[u8; 20]` | SHA-1 hash of the destination topic. |
| | | | `2` | Push Token | `[u8; 32]` | Destination device push token. |
| | | | `3` | Payload | `[u8]` | Raw payload: binary plist or WebTunnel response PDU. |
| | | | `4` | Message ID | `i32 BE` | Sequence identifier used for positive acknowledgment. |
| **`0x0b`** | `Ack` | Client $\to$ Courier | `1` | Push Token | `[u8; 32]` | Device push token. |
| | | | `4` | Message ID | `i32 BE` | Echo of Message ID from received `0x0a` notification. |
| | | | `8` | Status | `u8` | Status: `0` = Acknowledged successfully. |
| **`0x0c`** | `Ping` | Client $\to$ Courier | N/A | None | Empty | Heartbeat ping frame transmitted every 60 seconds of socket inactivity. |
| **`0x0d`** | `Pong` | Courier $\to$ Client | N/A | None | Empty | Heartbeat acknowledgment from courier. Socket drops if pong is not received within 15s. |
| **`0x14`** | `SetState` | Client $\to$ Courier | `1` | State | `u32 BE` | State integer (`1`). |
| | | | `2` | KeepAlive | `u32 BE` | Requested keepalive window: `0x7fffffff` (maximum persistence). |

---

## 5. Topic Subscriptions for FaceTime & IDS

After the courier assigns a 32-byte push token in `ConnectResponse` (`0x08`), the client MUST send a `Filter` frame (`0x09`) containing the SHA-1 hashes of the topics it intends to receive. Without filtering, incoming calls and lookup responses are dropped by Apple's edge routers.

### 5.1 Mandatory Topics:
| Topic Name | SHA-1 Hash (Hex) | Purpose |
|---|---|---|
| `com.apple.madrid` | `620cb98ae52fa06275c9e2b10a273b4d6b38c227` | Apple Identity Services (IDS) status notifications, registration alerts. |
| `com.apple.ess` | `cfba78d10f882193b2a2153c37d04f2f451fef27` | Legacy FaceTime 1-to-1 video call signaling. |
| `com.apple.private.alloy.facetime.multi` | `b8c5e62f55cb805a528f86915f7b8bb1fce458a2` | Modern multi-party and 1-to-1 FaceTime signaling, WebTunnel `id-query` routing. |
| `com.apple.private.alloy.facetime.video` | `37805128095cb7f45778a87b1c1d9dfebc7d6205` | AVConference video stream parameters and control. |
| `com.apple.private.alloy.quickrelay` | `82b4a539cb16f8490a612d7c041923faecb0231b` | QuickRelay allocation responses and token issuance. |

---

## 6. Android Persistent Service & Network Management

Maintaining a reliable APNs connection on Android requires explicit management of the Linux socket, radio power states, and system sleep modes:

### 6.1 `ApsConnectionService` (Foreground Service)
- Registered with type `dataSync` or `remoteMessaging`.
- Displays an ongoing Android system notification (`"FaceTime Courier Active"`).
- Acquires a `PowerManager.PARTIAL_WAKE_LOCK` during active handshake, lookup, and invite transactions to prevent CPU deep sleep.

### 6.2 Network Handover Management
- Registered via `ConnectivityManager.registerDefaultNetworkCallback()`:
  - `onAvailable(network)`: Triggers immediate connection if socket is idle.
  - `onLost(network)`: Tears down active TLS stream and invalidates cached sockets.
  - `onCapabilitiesChanged(network, caps)`: Detects transition between Wi-Fi and Cellular radios, sending an updated `Connect` or `SetState` frame without dropping the assigned 32-byte push token.

### 6.3 Exponential Backoff with Jitter
When a TCP connection drops or courier resets:
$$t_{\text{backoff}} = \min(300, 2^{\text{retries}} + \text{rand}(0, 3)) \quad \text{seconds}$$
Prevents synchronization storms against Apple's edge servers.
