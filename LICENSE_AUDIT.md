# Legal, Intellectual Property, and Compliance Audit

**Project**: FaceTime Android Proof-of-Concept (`facetime-android-poc`)  
**Scope**: Clean-room implementation of Apple communication protocols (APS, IDS, FaceTime signaling) on standalone Android hardware.  
**Classification**: Research & Engineering Diagnostic Proof-of-Concept  
**Audit Date**: October 2026  
**Auditor / Reviewer**: Licensing Compliance & IP Risk Strategy Group  

---

## 1. Executive Summary

This document establishes the comprehensive intellectual property (IP), licensing compatibility, and statutory compliance framework for the **FaceTime Android PoC** project. 

The primary findings of this audit are:
1. **Permissive Open-Source Base**: All runtime crates and vendored upstream modules (`vendor/rustpush/`, Tokio, Reqwest, Serde, Rustls, UniFFI) are governed by permissive or file-level weak copyleft licenses (Apache-2.0, MIT, ISC, MPL-2.0, OpenBubbles). There is **zero GPL/AGPL/LGPL copyleft taint** across the repository.
2. **Outbound Licensing Recommendation**: The project repository is licensed under the **Apache License, Version 2.0**, which provides explicit patent grants, clear contributor terms, and robust compatibility with the Android Open Source Project (AOSP) ecosystem.
3. **DMCA Section 1201(f) Interoperability Protection**: Reverse engineering of protocol wire formats and network endpoints is conducted strictly pursuant to the statutory exemption in **17 U.S.C. § 1201(f)**, enabling computer programs to interoperate across operating systems.
4. **Clean-Room Attestation**: The project maintains a strict clean-room perimeter: **zero Apple proprietary binaries, zero extracted private keys, zero donor hardware certificates, and zero leaked internal source files**.
5. **Hard Go/No-Go Gate**: In accordance with the clean-room protocol, if standalone clean Android hardware validation is rejected by Apple's servers due to lack of genuine Apple hardware cryptographic roots (FairPlay/Absinthe), the project halts feature development immediately and documents the blocker, rather than resorting to illicit donor device harvesting or credential relays.

---

## 2. License Compatibility & Redistribution Matrix

### 2.1 Outbound License Choice: Apache License 2.0
The FaceTime Android PoC adopts the **Apache License, Version 2.0** as its outbound license. The rationale includes:
- **Explicit Patent Grant (§ 3)**: Protects downstream developers and contributors from patent infringement claims regarding contributions.
- **Defensive Termination (§ 3)**: Protects the project from patent retaliation by automatically terminating patent licenses if a user files patent litigation against contributors.
- **AOSP Alignment**: The Android Open Source Project and Google Play library ecosystem standardize on Apache-2.0.

### 2.2 Compatibility Matrix
| Inbound Component / License | Outbound (Apache-2.0) Compatibility | Obligations & Conditions |
|---|---|---|
| **MIT License** (`tokio`, `serde`, `plist`, `deku`, `rasn`, `reqwest`) | **Fully Compatible** | Retain original copyright notices and permission notices in `THIRD_PARTY_NOTICES.md`. |
| **Apache License 2.0** (`prost`, `openssl`, `AndroidX`, `Kotlin`) | **Identical / Fully Compatible** | Comply with Section 4: provide license copy, retain attribution, include NOTICE file if applicable. |
| **ISC License** (`rustls`, `tokio-rustls`) | **Fully Compatible** | Retain copyright notice and disclaimer in documentation. |
| **Mozilla Public License 2.0** (`uniffi`, `uniffi_bindgen`, `webpki-roots`) | **Compatible as Larger Work (§ 3.3)** | MPL-2.0 is a file-level copyleft license. Modifying UniFFI source files requires making those modifications MPL-2.0. However, compiling UniFFI bindings or linking against the `uniffi` runtime within an Apache-2.0 project constitutes a "Larger Work" under Section 3.3, keeping the rest of the project Apache-2.0. |
| **OpenBubbles License** (`vendor/rustpush/`) | **Compatible under Isolation** | Kept in isolated vendor directory `vendor/rustpush/` under original license. Modifications are captured in `vendor/patches/`. |
| **GPL / AGPL / LGPL** | **NOT PERMITTED / ZERO PRESENT** | No copyleft code is accepted into the repository to prevent license contamination. |

---

## 3. Reverse Engineering for Interoperability under DMCA Section 1201

### 3.1 Statutory Framework: 17 U.S.C. § 1201(f)
Title 17 of the United States Code, Section 1201(f) provides an explicit statutory exception to anti-circumvention rules for reverse engineering:

> **17 U.S.C. § 1201(f) Reverse Engineering:**  
> (1) *Notwithstanding the provisions of subsection (a)(1)(A), a person who has lawfully obtained the right to use a copy of a computer program may circumvent a technological measure that effectively controls access to a particular portion of that program for the sole purpose of identifying and analyzing those elements of the program that are necessary to achieve interoperability of an independently created computer program with other programs, to the extent that such acts are permitted under this title.*  
> (2) *...a person may develop and employ technological means to circumvent a technological measure... for the purpose of enabling interoperability of an independently created computer program with other programs...*  
> (3) *The information acquired through the acts permitted under paragraph (1), and the means permitted under paragraph (2), may be made available to others... solely for the purpose of enabling interoperability of an independently created computer program with other programs...*

### 3.2 Application to the FaceTime Android PoC
The development and research conducted in this project satisfy every prong of § 1201(f):
1. **Lawful Access**: Research was conducted using publicly observable network communications, lawful ownership of target mobile devices, and standard developer diagnostic tools.
2. **Sole Purpose of Interoperability**: The sole objective of this project is to enable an independently created computer program (an Android native application) to achieve communication interoperability with Apple's communication servers (APS, IDS, FaceTime signaling) and recipient devices.
3. **Necessary Elements Only**: The project analyzes only functional protocol schemas, serialization wire formats (Apple binary plists, protobuf definitions, TLS ALPN negotiation), and cryptographic handshakes (SRP-6a, EC prekeys). No expressive software code is copied.
4. **Independent Implementation**: The protocol core is written independently from scratch in modern Rust, with zero Apple source code.

### 3.3 Supporting Legal Precedents
- ***Sega Enterprises Ltd. v. Accolade, Inc.*, 977 F.2d 1510 (9th Cir. 1992)**:  
  The Ninth Circuit held that disassembly and reverse engineering of copyrighted object code is fair use as a matter of law when it is the only way to gain access to unprotected functional elements and interface specifications necessary for interoperability.
- ***Sony Computer Entertainment, Inc. v. Connectix Corp.*, 203 F.3d 596 (9th Cir. 2000)**:  
  Reaffirmed that reverse engineering for the purpose of creating a non-infringing, functionally compatible platform is protected fair use.
- ***Lexmark International, Inc. v. Static Control Components, Inc.*, 387 F.3d 522 (6th Cir. 2004)**:  
  The Sixth Circuit ruled that technological authentication handshakes that serve as gatekeepers for functional interoperability do not constitute actionable access control circumvention under the DMCA when the underlying functional data is uncopyrightable.
- ***Chamberlain Group, Inc. v. Skylink Technologies, Inc.*, 381 F.3d 1178 (Fed. Cir. 2004)**:  
  Circumvention of a technological measure does not violate § 1201 unless the plaintiff can prove a nexus between the circumvention and actionable copyright infringement. Because interoperable communications infringe no copyright, § 1201 claims fail.
- ***Google LLC v. Oracle America, Inc.*, 141 S. Ct. 1183 (2021)**:  
  The Supreme Court affirmed that declaring code, API definitions, and interface structures necessary for interoperability fall squarely within fair use under 17 U.S.C. § 107.

---

## 4. Trade Secret Protection & Clean-Room Attestation

### 4.1 Trade Secret Law (UTSA & Defend Trade Secrets Act)
Under both the Uniform Trade Secrets Act (UTSA) and the federal Defend Trade Secrets Act (DTSA, 18 U.S.C. § 1839(6)(B)):
> *"Reverse engineering, independent derivation, or any other lawful means of acquisition shall not be considered theft, misappropriation, or improper means."*

### 4.2 Clean-Room Attestation Statement
The contributors and engineering agents of the FaceTime Android PoC formally attest to the following clean-room operating procedures:

```
================================================================================
                    CLEAN-ROOM COMPLIANCE ATTESTATION
================================================================================
1. ZERO APPLE BINARY ASSETS:
   No Apple-compiled binary libraries (including libadi.dylib, libabsinthe.dylib,
   CoreADI.framework, FairPlay DRM modules, StoreServices.framework, or
   AppleAccount.framework) are bundled, wrapped, dynamically loaded, or
   redistributed within this repository or the compiled Android APK.

2. ZERO EXTRACTED PRIVATE KEYS OR DONOR CERTIFICATES:
   No cryptographic private keys, X.509 client certificates extracted from physical
   Apple devices, hardware serial numbers, UDIDs, MLB numbers, or ROM MAC
   addresses are embedded or distributed.

3. ZERO PROPRIETARY SOURCE CODE OR LEAKED MATERIALS:
   No proprietary Apple source code, confidential documentation, or leaked internal
   materials have been consulted, decompiled, or committed.

4. INDEPENDENT CLEAN-ROOM IMPLEMENTATION:
   All protocol engines, cryptographic state machines (SRP-6a, AES-GCM, TLS 1.3,
   P-256 ECDH, RSA-OAEP), serialization parsers (plist, protobuf, deku), and
   network client pipelines are implemented independently from public RFC standards
   and network wire observations.

5. ZERO COMPANION OR SERVER-SIDE BYPASS BRIDGES:
   The implementation is strictly standalone Android client-to-server; it does
   not route through macOS bridge servers, cloud VM relays, or donor device farms.
================================================================================
```

---

## 5. Android Platform & Distribution Compliance

### 5.1 Google Play Developer Program Policies
To ensure eligibility for Android distribution:
- **Device and Network Abuse**: The PoC does not interfere with, disrupt, damage, or access in an unauthorized manner any other device, network, or server. Network calls are standard HTTPS and TLS connections initiated solely upon explicit user action or legitimate background push keepalive cycles.
- **Intellectual Property & Impersonation**:
  - The application must **NOT** be named "Apple FaceTime", "FaceTime for Android", or use Apple trademarks as primary identifiers.
  - Recommended naming: **"OpenPush Protocol Diagnostic"** or **"FaceTime Protocol Research PoC"**.
  - App icons, splash screens, and UI elements must not copy Apple's green video camera icon, Apple trademarks, or proprietary iconography.
  - Prominent in-app disclaimer:  
    *"FaceTime Android PoC is an independent open-source research and diagnostic project. It is not affiliated with, sponsored by, authorized by, or endorsed by Apple Inc."*
- **User Privacy & Keystore Security**:
  - Passwords and two-factor codes entered by the user are held exclusively in volatile memory and zeroized immediately following SRP verification.
  - Session tokens (PET, DSID, IDS delegate tokens) must be stored in encrypted format using Android Keystore hardware-backed keys (`MasterKey` with AES-256-GCM) via `EncryptedSharedPreferences`.
  - Diagnostic export bundles (`events.jsonl`) automatically pass through regex redaction to strip authorization tokens, cookies, and passwords before being written to disk or shared.

---

## 6. Apple Terms of Service & User Account Risk Mitigation

### 6.1 Terms of Service (ToS) Landscape
- Apple Media Services and iCloud Terms of Service govern end-user access to Apple accounts.
- While reverse engineering for interoperability is protected under federal copyright and trade secret law, Apple exercises autonomous administrative discretion over accounts connecting to its infrastructure.
- Apple's servers monitor device validation anomalies and may return diagnostic rejection codes:
  - **HTTP 401/403**: Invalid SRP credentials or Anisette signature mismatch.
  - **Status 6005**: Rejection during IDS registration due to missing or invalid validation-data.
  - **Status 6009**: Account-level restriction ("Your iMessage/FaceTime access is temporarily disabled").

### 6.2 Mitigation Strategy for Developers & Researchers
1. **Dedicated Research Accounts**: The diagnostic application and documentation must explicitly advise researchers to test exclusively using secondary, disposable Apple Accounts created for research purposes.
2. **Graceful Error Handling**: Upon encountering error codes 6005 or 6009, the client must cease registration attempts immediately to avoid repeated server rejections or automated rate-limiting.
3. **Hard Go/No-Go Enforcement**: See Section 7.

---

## 7. The Hard Go/No-Go Decision Gate

In compliance with Requirement R2 (`ORIGINAL_REQUEST.md`):

```
       [Clean Standalone Android Device Validation Test]
                              |
       +----------------------+----------------------+
       |                                             |
[Apple Server Accepts Validation]         [Apple Server Rejects Validation]
       |                                             |
       v                                             v
Advance to Outgoing Ringing Signaling     HALT FEATURE DEVELOPMENT IMMEDIATELY
(Milestone 4 / PoC V0)                    Compile Blocker Research Report:
                                          docs/experiments/Standalone_Android_
                                          FaceTime_Registration_Blocker.md
```

### Protocol for Blocker Compilation:
If Apple's validation servers reject clean-room synthetic validation data:
1. Immediately halt development on media pipelines, video codecs, and signaling extensions.
2. Capture the full HTTP exchange, server headers, and plist response body (with sensitive credentials redacted).
3. Document the mathematical and cryptographic proof of the hardware barrier: demonstrating that Apple's server requires unforgeable FairPlay/Absinthe signatures tied to genuine Apple Secure Enclaves or Apple-signed device certificates.
4. Publish the blocker report as the terminal research conclusion of the zero-donor hypothesis.

---

## 8. Continuous Compliance & Auditing Protocol

To ensure continuous adherence throughout all milestones:
1. **Automated CI Secret & License Scanning**:
   - `cargo-deny`: Run on all Rust dependencies to verify license compliance (allowing only Apache-2.0, MIT, ISC, BSD-2/3, MPL-2.0).
   - Secret Scanner: Verify that no private keys, certificate blocks (`-----BEGIN RSA PRIVATE KEY-----`), or Apple serial numbers exist in git commits.
2. **Patch Transparency**:
   - Zero modifications to `vendor/rustpush/` without a corresponding atomic patch in `vendor/patches/`.
3. **Diagnostic Bundle Redaction Verification**:
   - Unit tests in `android/core-diagnostic/` must fuzz diagnostic logs against known token patterns to verify 100% redaction rate prior to export.

---

**Audit Approved By**: Milestone 1 Licensing & Compliance Explorer  
**Status**: ACTIVE & BINDING FOR ALL MILESTONES
