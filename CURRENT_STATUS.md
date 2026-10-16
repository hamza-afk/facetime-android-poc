# Current Status: FaceTime Android PoC

**Project**: FaceTime Android Standalone Proof-of-Concept  
**Repository**: `https://github.com/hamza-afk/facetime-android-poc`  
**Current Milestone**: Milestone 4 (Recipient Lookup & Outgoing Ringing Signaling — PoC V0) — IMPLEMENTED & VERIFIED  
**Last Updated**: October 2026  
**Active Git Branch**: `main`  
**Overall Project Health**: GREEN (Milestones 1, 2, 3, and 4 Deliverables 100% Implemented & Verified)  

---

## 1. Working

The following components, infrastructure, and architectural deliverables are verified, fully functional, and operational:

- **Repository & Remote Configuration**:
  - Greenfield Git repository initialized on branch `main` with verified remote `https://github.com/hamza-afk/facetime-android-poc.git`.
  - Windows 11 host audited with Git and Amazon Corretto JDK 25.
- **Upstream Rustpush Vendoring & Submodules (Feature 1)**:
  - Pristine OpenBubbles `rustpush` vendored into `vendor/rustpush/` pinned at commit `b3c96c23e1aae78d1229ebaccb12027624f1eaff`.
  - All 7 submodules verified with cryptographic checksums across 2,206 files.
- **Patch Management Tooling & Zero-Modification Enforcement (Feature 1)**:
  - Quilt patch scripts in `vendor/patches/` (`apply-patches`, `revert-patches`, `verify-vendor`).
  - Zero active patches, 100% pristine upstream tree verified by `verify-vendor.ps1`.
- **Protocol Architecture Documentation Suite (Feature 2)**:
  - All 6 authoritative architecture specifications authored in `docs/architecture/` (`overview.md`, `apple_account_auth.md`, `aps_push.md`, `ids_registration.md`, `facetime_signaling.md`, `apple_dependencies.md`).
- **Licensing Compliance & Legal Protection Framework (Feature 3)**:
  - Complete catalog in `THIRD_PARTY_NOTICES.md` and IP/patent analysis in `LICENSE_AUDIT.md`.
- **Status & Milestone Governance (Feature 4)**:
  - Operational tracking maintained across all features and milestones.
- **Device Validation Trait & Isolated Providers (Feature 5)**:
  - `DeviceValidationProvider` trait implemented with `MockValidationProvider` (`MOCK_MODE`) and `ExistingRustpushValidationProvider`.
- **Zero Apple Hardware Clean Provider (Feature 6)**:
  - `AndroidExperimentalValidationProvider`: Clean-room Android provider with synthetic identifiers (`ANDROID-SYNTHETIC-*`), zero donor certs, software Anisette, and OS CSPRNG entropy.
- **Hard Go/No-Go Enforcement & Blocker Report (Feature 7)**:
  - `AppleServerSimulator` simulating Status 6005/6009/401/400.
  - `HardGoNoGoGate` transitioning state to `IDS_REGISTRATION_FAILED_HARD_HARDWARE_BLOCKER` upon server rejection.
  - Authoritative research blocker report authored in `docs/experiments/Standalone_Android_FaceTime_Registration_Blocker.md`.
- **Rust Protocol Core Engine (Feature 8)**:
  - Implemented in `rust/facetime-core/` with `[lib] crate-type = ["cdylib", "rlib"]`, `uniffi = "0.28"`, `tokio`, and standard crypto crates.
  - `src/auth/`: GSA RFC 5054 SRP-6a client crypto (`SrpContext`), 2FA challenge handling (`TwoFactorHandler`), iCloud delegate login (`DelegateLogin`), and `AuthManager`.
  - `src/aps/`: Topic hashes for 5 standard FaceTime topics, raw and packed binary framing (`ApsFrame`), TLS Courier client abstraction (`CourierClient`), and `ApsManager`.
  - `src/ids/`: VCInit bag parser (`VcInitBag`), dual RSA 1280 + NGM P-256 identities (`DualIdentities`), dual-header HTTP signer (`IdsHeaderSigner`), and 7-stage registration stepper (`IdsRegistrationStepper`) integrating Milestone 2 `HardGoNoGoGate`.
  - `src/signaling/`: Recipient lookup (`RecipientResolver`), Command 200 QuickRelay allocation, and Command 207 `FTWireMessage` invite serialization (`SignalingWire`).
- **UniFFI / Kotlin FFI Interface Bridge (Feature 9)**:
  - Proc-macro scaffolding in `src/lib.rs` and IDL definition in `src/facetime_core.udl`.
  - `FaceTimeCoreEventListener` exporting 5 asynchronous callbacks: `onAuthStateChanged`, `onApsStateChanged`, `onIdsStateChanged`, `onCallStateChanged`, and `onDiagnosticEvent`.
  - `FaceTimeCoreEngine` exposing all 8 core API methods with clean exception translation via `FaceTimeCoreError`.
  - Comprehensive unit and integration test suite in `rust/facetime-core/tests/integration_tests.rs`.
- **Jetpack Compose Diagnostic UI (Feature 10)**:
  - Multi-module Android application in `android/app/` with Material 3 dark/light themes.
  - `AuthScreen`: Apple ID & password inputs with in-memory zeroization and interactive 2FA dialog.
  - `ApsScreen`: Live courier status card, TLS status, 32-byte push token display with clipboard copy, ping latency, and registered topics.
  - `IdsPipelineScreen`: 7-stage visual stepper, stage badges, error highlights, and Hard Go/No-Go Blocker banner with direct link to research report.
  - `CallTriggerScreen`: Recipient handle input, directory capability check badge, and call controls advancing to `RemoteRinging`.
  - `DiagnosticConsoleSheet`: Live virtualized event console with color-coded severity badges, search filter, and bundle export triggers.
- **Android Keystore Hardware-Backed Token Security (Feature 11)**:
  - Implemented in `android/core-security/` with `MasterKey` AES-256-GCM hardware encryption and `EncryptedSharedPreferences`.
  - `PasswordZeroizer`: In-memory `CharArray` password zeroization with `wipe` and `useAndWipe` blocks.
  - Complete logout Keystore purge invalidating stored credentials.
- **Persistent APS Courier Foreground Service (Feature 12)**:
  - Implemented in `android/core-network/` with `ApsConnectionService` (Channel `aps_channel`, ID 101, `connectedDevice` foreground service type).
  - `NetworkMonitor` handling Wi-Fi/cellular handover via `ConnectivityManager.NetworkCallback`.
  - Exponential reconnect backoff schedule `[1s, 2s, 4s, 8s, 16s, 32s]` and 60-second keepalive heartbeat.
- **Sanitized Diagnostic Bundle Exporter (Feature 13)**:
  - Implemented in `android/core-diagnostic/` with `CircularEventBuffer` bounded FIFO ring buffer (1,000-2,048 entries, $O(1)$ head eviction, zero OOM).
  - `SecretSanitizer`: Automated multi-tier regex redaction engine covering passwords, PET tokens, GS tokens, 2FA codes, private keys, and hardware blobs.
  - `DiagnosticBundleExporter`: Atomic zip bundle generator producing `events.jsonl`, `environment.json`, `network-summary.json`, `redaction_audit.log`, and `checksum.sha256`, with in-process leak audit verification.
- **Apple Directory Recipient Lookup (Feature 14)**:
  - Implemented in `rust/facetime-core/src/lookup/` (`mod.rs`, `normalize.rs`, `model.rs`, `wire.rs`, `mock.rs`).
  - Strict handle normalizer supporting ITU-T E.164 phone numbers (`tel:+...`) and Apple ID email addresses (`mailto:...`) with RFC 5322 validation.
  - WebTunnel Command 96 framing over persistent APS Courier connection to `https://init.ess.apple.com/WebObjects/VCInit.woa/wa/id-query`.
  - Multi-key cryptographic request signing (`x-id-*`) using 17-byte HTTP nonces and RSA-SHA1 PKCS#1 v1.5 signatures.
  - Binary property list parser for `IDSLookupResp` extracting 32-byte APNS push tokens, session routing tokens, RSA 1280 public keys, and NGM P-256 pre-keys.
  - High-fidelity offline simulation mock responder and oversized response bisection error handling (Status 5206).
- **Outgoing FaceTime Invite Signaling & Relay Protocol (Feature 15)**:
  - Implemented in `rust/facetime-core/src/signaling/` (`invite.rs`, `relay.rs`, `session.rs`, `wire.rs`, `lookup.rs`, `mod.rs`).
  - Command 200 QuickRelay media relay allocation request serialization and response parsing (`qrip`, `qrp`, `qrst`, `qrsk`, `qids`, `qal`).
  - Command 207 outer IDS relay binary plist envelope with 32-byte push token targeting and dynamic session tokens.
  - Plaintext inner `FTWireMessage` binary plist containing session UUIDs, caller participant IDs, and media negotiation descriptor (`AVCData`).
  - Encoded Protocol Buffer `ConversationParticipantDidJoinContext` with `notificationStyles = 1` (`STANDARD_RINGING`) triggering native iOS SpringBoard CallKit incoming call UI.
  - 5-stage call progression state machine: `Idle` -> `Resolving` -> `QuickRelayAllocating` -> `InviteSending` -> `RemoteRinging` -> `Connected` / `Declined` / `Ended`.
- **Decisive Native Ringing & Android Call Screen (Feature 16)**:
  - Complete Jetpack Compose UI implemented in `android/app/src/main/java/org/facetime/android/ui/` and `org/facetime/poc/ui/`.
  - `CallViewModel.kt` managing handle validation, directory lookup state caching, active call stopwatch timer, and UniFFI bridge dispatch.
  - `CallTriggerScreen.kt` featuring recipient handle input with recent chips, directory capability badge, visual 5-stage progression stepper, pulsing ringing animation, and prominent red "End / Cancel Call" button.
- **Opaque-Box E2E Testing Suite**:
  - Full automated test runner in `tests/e2e/run_tests.ps1` executing 218 test cases across Tiers 1-4 with 100% pass rate.

---

## 2. Partially Working

None. All Milestone 1, 2, 3, and 4 deliverables are fully implemented, tested, and passing.

---

## 3. Blocked

- **Hard Go/No-Go Decision Gate (OPERATIONAL & ENFORCED)**:
  - *Identified Barrier*: Apple's Identity Services (`init.ess.apple.com`) strictly requires FairPlay/Absinthe hardware validation signatures and Anisette HMACs rooted in Apple Silicon (Secure Enclave Processor).
  - *Empirical Finding*: In clean-room Android mode (without donor Apple hardware or extracted certificates), Apple servers return **`Status 6005 (ValidationDataRejected)`** with **`HTTP 403 Forbidden`**.
  - *Operational Rule*: Per Requirement R2, feature development for standalone clean-room calling is **halted**, and the hardware barrier is formally cataloged in `docs/experiments/Standalone_Android_FaceTime_Registration_Blocker.md`.
  - *Dual-Mode Architecture*: Offline testing and CI remain fully operational via `MockValidationProvider` (`MOCK_MODE`), while reference auditing is supported via `ExistingRustpushValidationProvider`.

---

## 4. Untested

The following features and functional layers are planned and will be subjected to physical testing in subsequent milestones:

- **Milestone 5 (E2E Testing & Anti-Cheating)**:
  - Anti-cheating forensic verification audit.
  - Tier 5 adversarial stress-testing.

---

## 5. Next Experiment

### Immediate Next Operational Action:
- **Initiate Milestone 5 (E2E Hardening, Anti-Cheating & Forensic Audit)**:
  1. Execute full opaque-box E2E regression and adversarial test suites.
  2. Perform forensic audit verifying zero web links, zero SMS companion paths, and zero donor cert leakage.
  3. Validate redaction audit logs and token zeroization across all memory boundaries.

---

## 6. Feature Progress Matrix

| Feature # | Feature Name | Target Milestone | Status | Blockers / Dependencies |
|---|---|---|---|---|
| **F1** | Upstream Rustpush Vendoring | M1 | COMPLETED | None |
| **F2** | Protocol Wire Architecture Docs | M1 | COMPLETED | None |
| **F3** | Third-Party Licenses & Notices | M1 | COMPLETED | None |
| **F4** | Initial Status Tracking | M1 | COMPLETED | None |
| **F5** | Device Validation Trait | M2 | COMPLETED | None |
| **F6** | Zero Apple Hardware Clean Provider | M2 | COMPLETED | None |
| **F7** | Hard Go/No-Go Enforcement | M2 | COMPLETED | None |
| **F8** | Rust Protocol Core Engine | M3 | COMPLETED | None |
| **F9** | UniFFI / Kotlin FFI Bridge | M3 | COMPLETED | None |
| **F10** | Jetpack Compose Diagnostic UI | M3 | COMPLETED | None |
| **F11** | Android Keystore Token Security | M3 | COMPLETED | None |
| **F12** | Persistent APS Courier Service | M3 | COMPLETED | None |
| **F13** | Sanitized Diagnostic Bundle Exporter | M3 | COMPLETED | None |
| **F14** | Apple Directory Recipient Lookup | M4 | COMPLETED | None |
| **F15** | Outgoing FaceTime Invite Signaling | M4 | COMPLETED | None |
| **F16** | Decisive Native Ringing (PoC V0) | M4 | COMPLETED | None |
| **F17** | Opaque-Box E2E Test Suite | M5 | PLANNED | F16 |
| **F18** | Anti-Cheating & Redaction Verification | M5 | PLANNED | F17 |
| **F19** | Adversarial Coverage Hardening | M5 | PLANNED | F17, F18 |
| **F20** | Git History & Publishing | M6 | PLANNED | M5 Pass |
