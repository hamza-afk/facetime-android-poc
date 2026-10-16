# Test Infrastructure & Opaque-Box E2E Testing Framework

> **Document**: Test Infrastructure Specification & Runner Manual  
> **Project**: FaceTime Android PoC (Clean-Room Research & Engineering)  
> **Target**: Comprehensive Opaque-Box Verification of Protocol Core, Android Native Diagnostic Client, and Signaling Architecture  
> **Authoritative Sources**: `ORIGINAL_REQUEST.md`, `PROJECT.md`, `docs/architecture/*`, and Apple Protocol Specifications

---

## 1. Test Philosophy

The testing framework for the FaceTime Android Proof-of-Concept operates under strict **opaque-box principles**, validating observable external behavior, wire-level protocol fidelity, cryptographic correctness, and security invariants without relying on internal implementation private states or mock facades.

### 1.1 Core Principles
1. **Opaque-Box Requirement-Driven Verification**:
   Tests are derived strictly from specifications in `ORIGINAL_REQUEST.md` and feature contracts in `PROJECT.md`. Tests interact solely with public APIs, wire formats, UniFFI interface contracts, Android Keystore invariants, and filesystem diagnostic bundles.
2. **Anti-Cheating & Hardware Isolation Auditing**:
   The test harness actively detects and rejects any embedded genuine Apple hardware credentials, donor device serial numbers, extracted private keys, or external companion activation services in the clean-room Android provider.
3. **Hard Go/No-Go Enforcement Testing**:
   The test suite independently validates the decision gate for the clean-room Android provider. If independent Android device validation cannot be accepted by Apple, tests verify that feature development halts and the blocker report (`docs/experiments/Standalone_Android_FaceTime_Registration_Blocker.md`) is accurately generated with the exact failing server payload and hardware cryptographic barrier.
4. **No Facade Tests**:
   Every test executes real assertions against concrete payloads, status codes, state transitions, cryptographic signatures, or redacted outputs. Facade tests that unconditionally pass without exercising logic are strictly prohibited.
5. **Self-Contained & Deterministic Execution**:
   Each test case sets up its own isolated state, utilizes explicit dependency injection or isolated mock environments where required for offline execution, and performs cleanup upon completion. Execution order independence is strictly maintained.
6. **Zero Secret Leakage Guarantee**:
   All diagnostic export mechanisms are verified against multi-tier adversarial regex patterns to ensure passwords, auth tokens, session tokens, and private keys are redacted prior to bundle creation.

---

## 2. Feature Inventory (Features 1 – 20)

Every feature defined in `PROJECT.md` is mapped to an authoritative requirement, milestone, and testing tier:

| # | Feature Name | Category | Scope Description | Milestone | Source Requirement |
|---|---|---|---|---|---|
| 1 | Upstream Rustpush Vendoring | Protocol Audit | Pinned vendor tree in `vendor/rustpush/` with verified commit hash and non-destructive patch tracking | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Protocol Wire Architecture Docs | Documentation | Comprehensive protocol specs and sequence diagrams in `docs/architecture/` (Auth, APS, IDS, FT) | M1 | ORIGINAL_REQUEST §R1 |
| 3 | Third-Party Licenses & Notices | Compliance | Full license inventory and attribution in `THIRD_PARTY_NOTICES.md` and `LICENSE_AUDIT.md` | M1 | ORIGINAL_REQUEST §R1 |
| 4 | Initial Status Tracking | Project Management | `CURRENT_STATUS.md` documenting Working, Partially Working, Blocked, Untested, and Next Experiment | M1 | ORIGINAL_REQUEST §R1 |
| 5 | Device Validation Trait | Validation Abstraction | `DeviceValidationProvider` trait with isolated Mock, ExistingRustpush, and AndroidExperimental providers | M2 | ORIGINAL_REQUEST §R2 |
| 6 | Zero Apple Hardware Clean Provider | Experimental Validation | Clean-room Android experimental provider with zero donor material, zero extracted certs, zero external APIs | M2 | ORIGINAL_REQUEST §R2 |
| 7 | Hard Go/No-Go Enforcement | Decision Gate | Automated blocker report generation upon server rejection of clean-room Android validation data | M2 | ORIGINAL_REQUEST §R2 |
| 8 | Rust Protocol Core Engine | Protocol Core | Protocol engine implementing GSA SRP-6a, 2FA, APS courier client, IDS registration, and FaceTime invite | M3 | ORIGINAL_REQUEST §R3 |
| 9 | UniFFI / Kotlin FFI Bridge | FFI Interface | Typed UniFFI 0.28+ bindings, streaming event listeners (`FaceTimeCoreEventListener`), and JNI integration | M3 | ORIGINAL_REQUEST §R3 |
| 10 | Jetpack Compose Diagnostic UI | Android Client UI | Diagnostic screen with Auth/2FA, APS status, 7-stage IDS stepper, Call trigger, and scrolling live event console | M3 | ORIGINAL_REQUEST §R3 |
| 11 | Android Keystore Token Security | Security & Storage | Hardware-backed MasterKey (AES-256-GCM) encryption for session tokens, full logout, in-memory zeroization | M3 | ORIGINAL_REQUEST §R3 |
| 12 | Persistent APS Courier Service | Android Networking | Foreground Service + NetworkCallback maintaining persistent courier connection across Wi-Fi/cellular handover | M3 | ORIGINAL_REQUEST §R3 |
| 13 | Sanitized Diagnostic Bundle Exporter | Observability | Circular ring buffer (2048 entries), JSONL emission, multi-tier regex redaction, and atomic zip bundle exporter | M3 | ORIGINAL_REQUEST §R3 |
| 14 | Apple Directory Recipient Lookup | Directory Services | Recipient handle resolution via `id-query` over APNS WebTunnel returning capabilities and public identity keys | M4 | ORIGINAL_REQUEST §R4 |
| 15 | Outgoing FaceTime Invite Signaling | Signaling | Outgoing call signaling via command 207 `FTWireMessage` advancing through session states to REMOTE_RINGING | M4 | ORIGINAL_REQUEST §R4 |
| 16 | Decisive Native Ringing (PoC V0) | System Integration | Physical or simulated recipient iPhone ringing with native incoming FaceTime call UI (Definition of Done) | M4 | ORIGINAL_REQUEST §R4 |
| 17 | Opaque-Box E2E Test Suite | Testing | Automated test runner covering Tiers 1-4 with >=5 test cases per feature across all 20 features | M5 | ORIGINAL_REQUEST §R5 |
| 18 | Anti-Cheating & Redaction Verification | Independent Audit | Independent verification proving zero donor certs, clean reproducible installs, and secret redaction audit | M5 | ORIGINAL_REQUEST §R5 |
| 19 | Adversarial Coverage Hardening | Robustness | White-box Tier 5 stress testing, network partition recovery, malformed frame fuzzing, and race conditions | M5 | ORIGINAL_REQUEST §R5 |
| 20 | Git History & Publishing | Release Management | Clean, atomic commit history, signed tags, and GitHub remote publishing to `hamza-afk/facetime-android-poc` | M6 | ORIGINAL_REQUEST §R6 |

---

## 3. Test Architecture: The 4-Tier Methodology

The testing architecture is structured into four progressive tiers, ensuring complete multi-dimensional coverage:

```
+-------------------------------------------------------------------------------+
| Tier 4: Real-World End-to-End Application Scenarios                           |
| (Clean install -> 2FA login -> APS connect -> Recipient Lookup -> Outgoing Call)|
+-------------------------------------------------------------------------------+
                                        ^
                                        |
+-------------------------------------------------------------------------------+
| Tier 3: Cross-Feature Interactions & Combinations                             |
| (Auth + APS, APS + IDS, IDS + Lookup, Token Expiry + Calling, Handover + Ping) |
+-------------------------------------------------------------------------------+
                                        ^
                                        |
+-------------------------------------------------------------------------------+
| Tier 2: Boundary, Corner Cases & Negative Robustness                          |
| (>=5 test cases per feature for all 20 features = 100+ tests)                 |
+-------------------------------------------------------------------------------+
                                        ^
                                        |
+-------------------------------------------------------------------------------+
| Tier 1: Feature Coverage & Functional Contracts                               |
| (>=5 test cases per feature for all 20 features = 100+ tests)                 |
+-------------------------------------------------------------------------------+
```

### 3.1 Tier 1: Feature Coverage (>=5 test cases per feature for 20 features = 100+ tests)
Focuses on the primary behavior, interface contracts, valid state transitions, and positive operational flows for every feature in isolation.
- Validates data model serialization/deserialization.
- Verifies contract adherence for UniFFI bindings and trait implementations.
- Asserts deterministic outputs for mock and simulated protocol exchanges.

### 3.2 Tier 2: Boundary & Corner Cases (>=5 test cases per feature for 20 features = 100+ tests)
Exposes the protocol core, Android layers, and security mechanisms to extreme boundary conditions:
- **Empty & Extreme Values**: Null handles, 0-byte tokens, 64KB oversized payloads, invalid UTF-8 strings.
- **Malformed Protocol Frames**: Corrupted SRP-6a salts, truncated packed APS frames, invalid plist structures, mismatched message UUIDs.
- **Authentication & Security Errors**: Bad 2FA verification codes, expired tokens, tampered Keystore ciphertext, unverified FairPlay certificates.
- **Network Stress & Timeouts**: Courier connection dropouts, WebTunnel 5206 (payload too large), DNS failures, and keepalive pong timeouts.
- **Validation Rejection**: Server rejection responses (status 6005, 6009) and clean-room Android blocker generation.

### 3.3 Tier 3: Cross-Feature Interactions (Pairwise Combinations)
Verifies integration boundaries where distinct modules interface with one another:
- **Auth $\leftrightarrow$ Keystore**: Successful 2FA auth yields tokens immediately encrypted into Keystore; subsequent retrieval decrypts without data corruption.
- **Auth $\leftrightarrow$ APS Courier**: GrandSlam delegate tokens pass directly into APS connect payload with valid client certificates.
- **APS Courier $\leftrightarrow$ IDS Registration**: Push token acquired from APS Courier `0x08 ConnectResponse` is provided to `id-register` and bound to user identities.
- **IDS Registration $\leftrightarrow$ Recipient Lookup**: Registered user identity keys are utilized to sign `id-query` WebTunnel requests.
- **Recipient Lookup $\leftrightarrow$ Outgoing FaceTime Invite**: Resolved recipient public identity keys (NGM P-256 prekeys) are used to encrypt `FTWireMessage` command 207 invitations.
- **Network Handover $\leftrightarrow$ APS Courier**: Android NetworkCallback Wi-Fi to cellular transition re-establishes courier connection without dropping active call sessions.
- **Diagnostic Exporter $\leftrightarrow$ All Subsystems**: Live events from Auth, APS, IDS, and FaceTime are captured by the ring buffer, fully redacted, and successfully exported into a valid ZIP archive.

### 3.4 Tier 4: Real-World Application Scenarios
Simulates realistic, multi-step end-to-end user workflows:
1. **Scenario 1: Cold Boot to Native Outgoing Call**:
   Fresh app launch $\to$ User enters Apple credentials $\to$ 2FA challenge dispatched and entered $\to$ APS courier connects $\to$ 7-stage IDS pipeline registers $\to$ Recipient handle queried $\to$ Command 207 Invite dispatched $\to$ Remote recipient rings.
2. **Scenario 2: Device Reboot & Token Restoration**:
   App restart $\to$ Keystore decrypts persisted session tokens $\to$ Skips interactive login $\to$ APS reconnects immediately $\to$ Outgoing call placed.
3. **Scenario 3: Complete User Logout & Keystore Purge**:
   User initiates logout $\to$ Keystore MasterKey and encrypted prefs zeroized $\to$ APS courier cleanly disconnects $\to$ Diagnostic buffer reset $\to$ Subsequent call attempt blocked.
4. **Scenario 4: Standalone Android Hard Go/No-Go Blocker**:
   User selects `AndroidExperimentalValidationProvider` $\to$ Clean-room Anisette/Absinthe sent to Apple server $\to$ Apple rejects with HTTP 403 / status 6005 $\to$ Core halts pipeline $\to$ Generates `Standalone_Android_FaceTime_Registration_Blocker.md` documenting failure.
5. **Scenario 5: Multi-Participant Call Decline & Teardown**:
   Caller initiates FaceTime invite $\to$ Recipient declines via command 242 Decline protobuf $\to$ Caller UI updates to DECLINED $\to$ Session tears down cleanly.
6. **Scenario 6: Automated Diagnostic Bundle Export & Audit**:
   System processes full auth and signaling flow $\to$ Diagnostic exporter triggered $\to$ Export bundle unpacked $\to$ Zero unredacted secrets verified against secret audit regexes.

---

## 4. Test Runner Architecture

The test harness is located in `tests/e2e/` and provides a cross-platform, dependency-free test execution runner:

### 4.1 Runner Directory Structure
```
tests/e2e/
├── run_tests.ps1               # Primary CLI runner (PowerShell / Windows / Linux pwsh)
├── run_tests.sh                # Bash CLI runner wrapper (Git Bash / Linux / macOS)
├── harness/                    # Core simulation and verification engines
│   ├── TestAssertions.ps1      # Custom assertions, matchers, and contract checkers
│   ├── MockAppleServers.ps1    # High-fidelity Apple GSA, APS, and IDS mock responders
│   ├── ProtocolWireCheckers.ps1# Plist, Packed APS frame, and Protobuf format validators
│   ├── KeystoreSimulator.ps1   # AES-256-GCM Keystore security and zeroization simulator
│   └── DiagnosticAuditor.ps1   # Multi-tier regex secret redaction and JSONL auditor
├── tier1_features.ps1          # Tier 1 Feature Coverage tests (Features 1 - 20)
├── tier2_boundary.ps1          # Tier 2 Boundary & Corner case tests (Features 1 - 20)
├── tier3_cross_feature.ps1     # Tier 3 Cross-Feature Interaction tests
└── tier4_real_world.ps1        # Tier 4 Real-World Application Scenario tests
```

### 4.2 Runner Execution Commands
```powershell
# Run the entire E2E test suite (all tiers):
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1

# Run a specific tier:
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Tier 1
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Tier 2
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Tier 3
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Tier 4

# Run tests for a specific feature (e.g. Feature 8: Rust Protocol Core):
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Feature 8

# Run with verbose output and generate JSON report:
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Verbose -ReportPath "tests/e2e/report.json"
```

Or via Bash:
```bash
bash tests/e2e/run_tests.sh --all
bash tests/e2e/run_tests.sh --tier 1
```

---

## 5. Coverage & Quality Thresholds

| Metric | Target | Enforcement Rule |
|---|---|---|
| **Feature Coverage** | 100% (20 / 20 features) | Build fails if any feature has fewer than 5 Tier 1 tests |
| **Boundary Coverage** | 100% (20 / 20 features) | Build fails if any feature has fewer than 5 Tier 2 tests |
| **Minimum Test Count** | $\ge 215$ Total Tests | $\ge 100$ Tier 1, $\ge 100$ Tier 2, $\ge 10$ Tier 3, $\ge 6$ Tier 4 |
| **Facade Test Detection** | 0% (Zero facade tests) | Every test must verify concrete outputs, wire bytes, or state changes |
| **Secret Redaction Leakage** | 0 Leaks | Diagnostic bundles scanned for tokens, passwords, and private keys |
| **Clean Room Compliance** | 0 Apple certs / serials | Scan passes only if Android experimental provider contains zero donor materials |
| **Suite Pass Rate** | 100% | Exit code 0 required for milestone completion and verification sign-off |

---

## 6. Verification & Sign-Off

Upon successful execution of all 4 tiers, the test runner outputs a machine-readable summary and publishes `TEST_READY.md` at the project root, signaling to the orchestrator and engineering team that the test infrastructure is primed for continuous milestone verification.
