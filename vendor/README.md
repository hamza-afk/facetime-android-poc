# Vendor Research Layer

This directory contains the upstream research codebases, vendored protocol components, and patch tooling for the FaceTime Android Proof-of-Concept.

---

## 1. Architectural Role

The vendor layer serves as the empirical research base for Apple's closed communications stack:
- **`vendor/rustpush/`**: The complete, clean upstream source tree of OpenBubbles `rustpush` pinned at commit `b3c96c23e1aae78d1229ebaccb12027624f1eaff`.
- **`vendor/patches/`**: Patch management tooling (`apply-patches.ps1`, `revert-patches.ps1`, `verify-vendor.ps1`, `series`) enforcing the **Zero Silent Modifications Policy**.

All higher-level components in this repository (`rust/facetime-core/`, `android/`) consume this vendored base via explicit Cargo path dependencies and clean-room abstractions.

---

## 2. Upstream Provenance & Submodules

Full provenance metadata, commit hashes, and submodule revisions are maintained in:
👉 [`vendor/rustpush/REVISION.md`](rustpush/REVISION.md)

### Vendored Component Summary:
- **Repository**: `https://github.com/OpenBubbles/rustpush.git`
- **Pinned Commit**: `b3c96c23e1aae78d1229ebaccb12027624f1eaff` (master)
- **Reference Branch**: `ft-testing` @ `b7a3b45a233a17289c09a58125a8566892f78cf6` (AVConference models)
- **Submodules Included**:
  - `open-absinthe` (`1f8dc73a`)
  - `third_party/apple-private-apis` (`b8598d2c`)
  - `third_party/apple-private-apis/clearadi` (`663f33f9`)
  - `third_party/quinn` (`bb2c42e0`)
  - `third_party/rtc` (`87589665`)
  - `third_party/rustls` (`cdb821cf`)
  - `third_party/rustls-platform-verifier` (`2c5b3b01`)

---

## 3. Zero Silent Modifications Policy

To guarantee reproducibility and clean separation:
1. Direct in-place edits to `vendor/rustpush/` are strictly prohibited.
2. Any modifications for Android NDK compilation, OpenSSL vendoring, or UniFFI bridge hooks must be captured as numbered `.patch` files in `vendor/patches/` and recorded in `vendor/patches/series`.
3. In Milestone 1, zero patches are applied; `vendor/rustpush/` remains 100% pristine upstream.
4. Cryptographic integrity is continuously validated against [`vendor/rustpush/CHECKSUMS.sha256`](rustpush/CHECKSUMS.sha256).

To verify the integrity of the vendor tree:
```powershell
powershell -ExecutionPolicy Bypass -File vendor/patches/verify-vendor.ps1
```

---

## 4. Root Cargo Workspace Patch Propagation Rule

Upstream `rustpush` relies on a patched fork of Quinn (`third_party/quinn/quinn`) declared in `vendor/rustpush/Cargo.toml` under `[patch.crates-io]`. 

Because Cargo ignores `[patch]` sections defined inside non-root workspace crates or path dependencies, any workspace root manifest (`Cargo.toml`) that consumes `rustpush` (such as `rust/facetime-core/` in Milestone 3) must re-export this patch rule at its root:

```toml
[patch.crates-io]
quinn = { path = "vendor/rustpush/third_party/quinn/quinn" }
```

Failing to re-export this patch in the root manifest causes Cargo to resolve standard Quinn from crates.io, missing Apple-specific QPod QUIC protocol adjustments.
