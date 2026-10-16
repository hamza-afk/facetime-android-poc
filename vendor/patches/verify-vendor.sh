#!/usr/bin/env bash
# vendor/patches/verify-vendor.sh
# Integrity verification for Linux/CI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VENDOR_DIR="${REPO_ROOT}/vendor/rustpush"
CHECKSUM_FILE="${VENDOR_DIR}/CHECKSUMS.sha256"
REVISION_FILE="${VENDOR_DIR}/REVISION.md"

echo "=== Verifying Vendor Tree Integrity ==="
if [[ ! -d "${VENDOR_DIR}" ]]; then
    echo "ERROR: ${VENDOR_DIR} does not exist" >&2
    exit 1
fi

if [[ ! -f "${REVISION_FILE}" ]]; then
    echo "ERROR: REVISION.md missing" >&2
    exit 1
fi

if ! grep -q "b3c96c23e1aae78d1229ebaccb12027624f1eaff" "${REVISION_FILE}"; then
    echo "ERROR: REVISION.md missing pinned commit b3c96c23e1aae78d1229ebaccb12027624f1eaff" >&2
    exit 1
fi
echo "[PASS] REVISION.md verified."

if [[ -f "${CHECKSUM_FILE}" ]]; then
    echo "Verifying SHA-256 checksums..."
    (cd "${VENDOR_DIR}" && sha256sum -c CHECKSUMS.sha256 --quiet)
    echo "[PASS] CHECKSUMS.sha256 verified with zero mismatches."
fi

"${SCRIPT_DIR}/apply-patches.sh" --check
echo "=== ALL VENDOR VERIFICATION CHECKS PASSED ==="
