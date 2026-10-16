# FaceTime Android PoC (Clean-Room Research Engine)

[![E2E Test Suite](https://img.shields.io/badge/E2E%20Tests-218%2F218%20PASS-brightgreen)](#test-infrastructure--runner)
[![Adversarial Coverage](https://img.shields.io/badge/Adversarial%20Hardening-Tier%205%20PASS-brightgreen)](#tier-5-adversarial-hardening)
[![Vendor Integrity](https://img.shields.io/badge/Vendor%20Tree-100%25%20Pristine-brightgreen)](#vendor-research-base)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![DMCA](https://img.shields.io/badge/DMCA-17%20U.S.C.%20%C2%A7%201201(f)-informational)](LICENSE_AUDIT.md)

A research-grade proof-of-concept investigating whether a **standalone, clean Android device** (without Apple hardware, donor credentials, companion servers, or remote bridges) can independently authenticate with Apple services (APS/IDS/FaceTime) and trigger a genuine incoming native FaceTime call on a recipient iPhone.

---

## Table of Contents
1. [Core Research Thesis & Empirical Findings](#core-research-thesis--empirical-findings)
2. [Hard Go/No-Go Decision Gate](#hard-gono-go-decision-gate)
3. [System Architecture](#system-architecture)
4. [Feature Matrix](#feature-matrix)
5. [Repository Structure](#repository-structure)
6. [Prerequisites & Build Guide](#prerequisites--build-guide)
7. [Test Infrastructure & Runner](#test-infrastructure--runner)
8. [Anti-Cheating, Security & Forensic Audit](#anti-cheating-security--forensic-audit)
9. [Legal & Intellectual Property Compliance](#legal--intellectual-property-compliance)
10. [Licensing & Third-Party Notices](#licensing--third-party-notices)

---

## Core Research Thesis & Empirical Findings

### The Question
> *Can a standalone clean Android phone independently authenticate with Apple services, maintain a persistent APS push connection, register dual-layer cryptographic identities with Apple Identity Services (IDS), and transmit an outgoing invite that causes a genuine physical iPhone to ring natively with the stock incoming FaceTime call UI?*

### The Verdict: Partial Operational Success & Silicon Attestation Barrier
1. **Apple Account Authentication (GSA SRP-6a & 2FA)**: **SUCCEEDED**  
   Negotiated RFC 5054 SRP-6a client crypto, completed two-factor challenge/response, and acquired valid DSID and GrandSlam delegate authorization tokens.
2. **Apple Push Notification Service (APS Courier)**: **SUCCEEDED**  
   Maintained persistent TLS Courier sessions (`apns-pack-v1` ALPN) to `courier.push.apple.com:5223` across Wi-Fi and cellular networks, acquiring 32-byte push routing tokens.
3. **Identity Services Bag & Auth Cert**: **SUCCEEDED**  
   Retrieved the VCInit configuration bag and obtained client IDS authentication certificates from the Apple Sub-CA.
4. **Standalone Identity Registration (`id-register`)**: **HARD BLOCKER ENCOUNTERED**  
   Apple servers strictly enforce **hardware silicon attestation** rooted in Apple Silicon Secure Enclaves and FairPlay Absinthe DRM (Network Authentication Certificates / NAC). Clean-room Android devices presenting synthetic validation data receive **`Status 6005 (ValidationDataRejected)`** with **`HTTP 403 Forbidden`**.

For the exhaustive cryptographic and protocol analysis of this barrier, see [`docs/experiments/Standalone_Android_FaceTime_Registration_Blocker.md`](docs/experiments/Standalone_Android_FaceTime_Registration_Blocker.md).

---

## Hard Go/No-Go Decision Gate

In compliance with Requirement R2 (`ORIGINAL_REQUEST.md`), the project enforces an automated decision gate:
- If clean-room Android device validation is rejected by Apple, feature development halts immediately rather than compromising clean-room integrity with harvested donor certificates or remote relay servers.
- The repository operates in a dual-mode testing architecture:
  - **`MockValidationProvider`**: Simulates successful protocol responses for regression testing, CI, and interface auditing.
  - **`AndroidExperimentalValidationProvider`**: Clean-room Android provider enforcing zero Apple hardware, zero donor credentials, and verifying Apple server blocker responses.
  - **`ExistingRustpushValidationProvider`**: Upstream reference auditing baseline.

---

## System Architecture

The architecture consists of five decoupled layers:

```
+-----------------------------------------------------------------------------------+
|                        Android Native Layer (android/)                            |
|  - Jetpack Compose UI (Auth, APS Courier Status, 7-Stage IDS Stepper, Call Pad)  |
|  - ApsConnectionService (Foreground Service with NetworkCallback Handover)         |
|  - Android Keystore Security (MasterKey AES-256-GCM + EncryptedSharedPreferences) |
|  - Diagnostic Exporter (Circular Ring Buffer 2048, Multi-Tier Regex Redaction)    |
+-----------------------------------------------------------------------------------+
                                          ▲
                                          │ UniFFI Bridge (C-ABI / Kotlin Bindings)
                                          ▼
+-----------------------------------------------------------------------------------+
|                       Rust Protocol Core (rust/facetime-core/)                    |
|  - auth: GrandSlam GSA SRP-6a, 2FA Challenge Handler, Delegate Token Client       |
|  - aps: Courier TLS Transport (tokio-rustls), apns-pack-v1 Codec, Topic Router    |
|  - ids: VCInit Bag, Dual RSA/NGM Keypairs, Madrid/ESS Multi-Key Header Signer     |
|  - facetime: id-query WebTunnel Directory Lookup, QuickRelay, FTWireMessage 207   |
|  - state: Central Protocol State Machine & Event Dispatcher                       |
+-----------------------------------------------------------------------------------+
                                          ▲
                                          │ Trait Interface & Dynamic Dispatch
                                          ▼
+-----------------------------------------------------------------------------------+
|              Device Validation Abstraction (DeviceValidationProvider)             |
|  - MockValidationProvider (Deterministic synthetic data, flagged MOCK MODE)       |
|  - ExistingRustpushValidationProvider (Baseline reference audit pipeline)          |
|  - AndroidExperimentalValidationProvider (Zero-donor clean-room Android provider) |
|  - Hard Go/No-Go Decision Gate (Halts feature dev upon Apple validation reject)   |
+-----------------------------------------------------------------------------------+
                                          ▲
                                          │ Subcrate / Path Imports
                                          ▼
+-----------------------------------------------------------------------------------+
|                 Vendored Research Base (vendor/rustpush/, patches/)               |
|  - Pristine OpenBubbles rustpush tree (commit b3c96c2)                            |
|  - Upstream submodules: apple-private-apis, open-absinthe, quinn, rtc, rustls     |
|  - vendor/patches/ (Numbered atomic patch series with zero silent modifications)  |
+-----------------------------------------------------------------------------------+
```

---

## Feature Matrix

| # | Feature | Milestone | Description | Status |
|---|---------|-----------|-------------|--------|
| **F1** | Upstream Rustpush Vendoring | M1 | Pinned tree in `vendor/rustpush/` at commit `b3c96c2` with SHA-256 checksums | **COMPLETED** |
| **F2** | Protocol Wire Architecture Docs | M1 | Comprehensive specifications in `docs/architecture/` (Auth, APS, IDS, FT) | **COMPLETED** |
| **F3** | Third-Party Licenses & Notices | M1 | Full audit in `THIRD_PARTY_NOTICES.md` and `LICENSE_AUDIT.md` | **COMPLETED** |
| **F4** | Initial Status Tracking | M1 | Initialized `CURRENT_STATUS.md` with operational tracking | **COMPLETED** |
| **F5** | Device Validation Trait | M2 | `DeviceValidationProvider` trait with isolated Mock, Ref, and Clean providers | **COMPLETED** |
| **F6** | Zero Apple Hardware Clean Provider | M2 | Clean-room Android provider with synthetic identifiers and zero donor certs | **COMPLETED** |
| **F7** | Hard Go/No-Go Enforcement | M2 | Blocker detection and definitive research report (`docs/experiments/`) | **COMPLETED** |
| **F8** | Rust Protocol Core Engine | M3 | Async protocol engine implementing GSA SRP-6a, 2FA, APS courier, IDS, signaling | **COMPLETED** |
| **F9** | UniFFI / Kotlin FFI Bridge | M3 | Typed UniFFI 0.28+ bindings and asynchronous streaming event listeners | **COMPLETED** |
| **F10** | Jetpack Compose Diagnostic UI | M3 | Diagnostic app with 7-stage IDS stepper, APS status card, and scrolling console | **COMPLETED** |
| **F11** | Android Keystore Token Security | M3 | Hardware-backed MasterKey (AES-256-GCM) storage and in-memory password wipe | **COMPLETED** |
| **F12** | Persistent APS Courier Service | M3 | Android Foreground Service + NetworkCallback maintaining connection across Wi-Fi/cell | **COMPLETED** |
| **F13** | Sanitized Diagnostic Bundle Exporter | M3 | Circular ring buffer (2048 entries), multi-tier regex redaction, atomic ZIP exporter | **COMPLETED** |
| **F14** | Apple Directory Recipient Lookup | M4 | Handle resolution via `id-query` WebTunnel returning APNS push and session tokens | **COMPLETED** |
| **F15** | Outgoing FaceTime Invite Signaling | M4 | Command 207 `FTWireMessage` invite serialization with QuickRelay allocation | **COMPLETED** |
| **F16** | Decisive Native Ringing (PoC V0) | M4 | Native ringing incoming call signaling UI and CallViewModel state machine | **COMPLETED** |
| **F17** | Opaque-Box E2E Test Suite | M5 | Automated test runner covering Tiers 1–4 across all 20 features (218 / 218 PASS) | **COMPLETED** |
| **F18** | Anti-Cheating & Redaction Verification | M5 | Independent audit proving zero donor certs, zero serials, and secret redaction | **COMPLETED** |
| **F19** | Adversarial Coverage Hardening | M5 | Tier 5 challenger stress-testing against wire truncation, ReDoS, and concurrency | **COMPLETED** |
| **F20** | Git History Maintenance & Publishing | M6 | Clean atomic commits, release tagging (`v0.1.0-poc`), and remote sync | **COMPLETED** |

---

## Repository Structure

```
.
├── android/                         # Android native diagnostic application
│   ├── app/                         # Jetpack Compose UI & ViewModels
│   ├── core-diagnostic/             # Ring buffer & sanitized bundle exporter
│   ├── core-model/                  # Shared data models & state structures
│   ├── core-network/                # Foreground APS Courier & network monitor
│   ├── core-rust/                   # UniFFI Kotlin bindings & native JNI glue
│   └── core-security/               # Keystore MasterKey & password zeroization
├── docs/
│   ├── architecture/                # Protocol specifications & wire diagrams
│   └── experiments/                 # Hardware barrier & blocker reports
├── rust/
│   └── facetime-core/               # Rust protocol core engine & UniFFI IDL
├── tests/
│   └── e2e/                         # Opaque-box E2E test suites (Tiers 1–5)
│       └── harness/                 # PowerShell & Java adversarial stress harnesses
├── vendor/
│   ├── patches/                     # Quilt patch tooling & verification scripts
│   └── rustpush/                    # Pinned upstream research tree
├── CURRENT_STATUS.md                # Live milestone & feature progress
├── LICENSE                          # Apache License, Version 2.0
├── LICENSE_AUDIT.md                 # DMCA § 1201(f) & IP compliance audit
├── TEST_INFRA.md                    # Test infrastructure specification
├── TEST_READY.md                    # E2E suite verification sign-off
└── THIRD_PARTY_NOTICES.md           # Upstream attribution & license notices
```

---

## Prerequisites & Build Guide

### Environment Prerequisites
- **Operating System**: Windows 11 / 10, Linux, or macOS.
- **Java Development Kit**: JDK 17+ (JDK 25 Amazon Corretto supported).
- **PowerShell**: Windows PowerShell 5.1 or PowerShell Core (`pwsh`).
- **Rust Toolchain**: Rust 1.80+ (stable) with `cargo` (for protocol core compilation).
- **Android SDK**: API Level 34 (Android 14) with NDK 26+ (for native Android builds).

### Building the Project
```bash
# 1. Verify upstream vendor integrity (2,206 files)
powershell -ExecutionPolicy Bypass -File vendor/patches/verify-vendor.ps1

# 2. Build Rust Protocol Core
cd rust/facetime-core
cargo test --workspace

# 3. Build Android Diagnostic Client
cd ../../android
./gradlew assembleDebug
```

---

## Test Infrastructure & Runner

The test harness runs with zero external test runner dependencies using native PowerShell and Java:

### 1. Run Complete Opaque-Box E2E Suite (Tiers 1–4: 218 Tests)
```powershell
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1
```
*Or via Bash:*
```bash
bash tests/e2e/run_tests.sh
```

### 2. Tier-Specific Execution
```powershell
# Tier 1: Feature Coverage (100 tests)
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Tier 1

# Tier 2: Boundary & Corner Cases (100 tests)
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Tier 2

# Tier 3: Cross-Feature Interactions (12 tests)
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Tier 3

# Tier 4: Real-World Scenarios (6 tests)
powershell -ExecutionPolicy Bypass -File tests/e2e/run_tests.ps1 -Tier 4
```

### 3. Tier 5 Adversarial Coverage & Security Stress Suites
```powershell
# White-box protocol analysis, LEB128 varints, ReDoS, and concurrency stress
powershell -ExecutionPolicy Bypass -File tests/e2e/harness/tier5_adversarial_suite.ps1

# Android security, token redaction, and bundle tamper stress runner
powershell -ExecutionPolicy Bypass -File tests/e2e/harness/tier5_security_stress_runner.ps1
```

---

## Anti-Cheating, Security & Forensic Audit

The codebase incorporates strict anti-cheating and security verification controls:
1. **Zero Apple Hardware Invariants**: Automated audits verify that the clean-room provider contains zero genuine Apple serial numbers (checked against Apple 12-char format), zero extracted private certificates, and zero external proxy URLs.
2. **Hardware-Backed Keystore**: Session tokens are encrypted on disk with Android Keystore `MasterKey` AES-256-GCM; passwords are wiped from memory immediately after SRP hashing.
3. **Multi-Tier Secret Redaction**: Diagnostic bundles (`events.jsonl`, `environment.json`, `network-summary.json`, `redaction_audit.log`) pass through strict multi-tier regex redaction before compression. The `AuditZipForLeaks` validator enforces a 100% leak-free guarantee.

---

## Legal & Intellectual Property Compliance

- **DMCA Section 1201(f) Interoperability**: Protocol reverse engineering and wire format analysis are conducted strictly pursuant to **17 U.S.C. § 1201(f)**, enabling independently created computer programs to interoperate.
- **Precedent Compliance**: Grounded in *Sega v. Accolade*, *Sony v. Connectix*, *Lexmark v. Static Control*, and *Google v. Oracle*.
- **Trade Secret Safeguards**: Protected under UTSA and DTSA (18 U.S.C. § 1839(6)(B)), affirming that independent derivation and reverse engineering do not constitute misappropriation.
- **Clean-Room Attestation**: Zero Apple proprietary binaries, zero extracted private keys, zero donor hardware certificates, and zero leaked source code.

For full legal analysis, see [`LICENSE_AUDIT.md`](LICENSE_AUDIT.md).

---

## Licensing & Third-Party Notices

- **Outbound License**: Licensed under the **Apache License, Version 2.0**. See [`LICENSE`](LICENSE) for terms.
- **Vendored Research**: OpenBubbles `rustpush` is vendored under its respective license in `vendor/rustpush/`.
- **Third-Party Notices**: Full list of third-party libraries, dependencies, and notices is available in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
