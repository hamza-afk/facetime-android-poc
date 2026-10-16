# Patch Management System (`vendor/patches/`)

This directory maintains the atomic patch series and management tooling for the vendored research tree in `vendor/rustpush/`.

---

## 1. Zero Silent Modifications Policy

The code in `vendor/rustpush/` is a pinned, byte-for-byte replica of upstream `OpenBubbles/rustpush` at commit `b3c96c23e1aae78d1229ebaccb12027624f1eaff`.

- **Direct In-Tree Edits Prohibited**: Modifying any file directly within `vendor/rustpush/` without an accompanying patch file is strictly forbidden.
- **Continuous Integrity**: Automated verification (`verify-vendor.ps1` and `verify-vendor.sh`) validates all file hashes against `vendor/rustpush/CHECKSUMS.sha256`.
- **Atomic Patches**: Any modifications required for platform compatibility (e.g. Android NDK compilation, OpenSSL vendoring, UniFFI bridge hooks) must be captured as discrete unified diff patches in this directory.

---

## 2. Patch Naming & Format Conventions

### 2.1 File Naming
Patches must follow the zero-padded sequential numbering format:
```
NNNN-<descriptive-slug>.patch
```
Examples:
- `0001-fix-android-openssl-flavor.patch`
- `0002-export-uniffi-engine-hooks.patch`

### 2.2 Standard Patch Header Format
Every `.patch` file must begin with standard metadata explaining why the change is necessary:

```patch
From: <Author Name> <author@email.com>
Date: <UTC Timestamp>
Subject: [PATCH NNNN] <One-line summary>

Why this patch is needed:
<Detailed technical rationale: problem solved, compilation error fixed, Apple protocol adjustment>

Affected files:
- <relative file path within vendor/rustpush/>

Upstream reference:
<PR/Issue link or "None (standalone Android compatibility patch)">
---
```

### 2.3 The `series` File
The `series` file maintains the strict sequential application order of active patches (Quilt-style). When applying or reverting, scripts read `series` line-by-line, ignoring blank lines and comments (`#`).

---

## 3. Tooling & Script Reference

| Script | Platform | Purpose |
|---|---|---|
| `apply-patches.ps1` | Windows PowerShell | Applies active patches from `series` to `vendor/rustpush/`. Supports `-CheckOnly` for dry runs. |
| `apply-patches.sh` | Bash / Linux / macOS | Applies active patches from `series` to `vendor/rustpush/`. Supports `--check` for dry runs. |
| `revert-patches.ps1` | Windows PowerShell | Reverts active patches in reverse order, restoring the pristine upstream tree. |
| `revert-patches.sh` | Bash / Linux / macOS | Reverts active patches in reverse order, restoring the pristine upstream tree. |
| `verify-vendor.ps1` | Windows PowerShell | Verifies tree presence, `REVISION.md` commit pinning, `CHECKSUMS.sha256` integrity, and patch dry-run application. |
| `verify-vendor.sh` | Bash / Linux / macOS | Verifies vendor integrity and runs `apply-patches.sh --check`. |

---

## 4. Workflow for Adding a Patch

1. Ensure the current tree is pristine:
   ```powershell
   powershell -File vendor/patches/verify-vendor.ps1
   ```
2. Make necessary edits in a temporary copy or branch, and generate the unified diff:
   ```powershell
   git diff > vendor/patches/0001-my-change.patch
   ```
3. Add the patch filename to `vendor/patches/series`.
4. Test dry-run application:
   ```powershell
   powershell -File vendor/patches/apply-patches.ps1 -CheckOnly
   ```
5. Apply the patch:
   ```powershell
   powershell -File vendor/patches/apply-patches.ps1
   ```
6. Commit both the patch file, `series`, and the affected files.
