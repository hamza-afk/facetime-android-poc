#!/usr/bin/env bash
# vendor/patches/apply-patches.sh
# Applies all patches in vendor/patches/ to vendor/rustpush/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VENDOR_DIR="${REPO_ROOT}/vendor/rustpush"
SERIES_FILE="${SCRIPT_DIR}/series"

CHECK_ONLY=false
if [[ "${1:-}" == "--check" ]]; then
    CHECK_ONLY=true
fi

if [[ ! -d "${VENDOR_DIR}" ]]; then
    echo "ERROR: Vendor directory not found at ${VENDOR_DIR}" >&2
    exit 1
fi

PATCHES=()
if [[ -f "${SERIES_FILE}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        if [[ -n "${line}" && ! "${line}" =~ ^# ]]; then
            PATCHES+=("${SCRIPT_DIR}/${line}")
        fi
    done < "${SERIES_FILE}"
else
    while IFS= read -r file; do
        if [[ -f "${file}" ]]; then
            PATCHES+=("${file}")
        fi
    done < <(find "${SCRIPT_DIR}" -maxdepth 1 -name "*.patch" | sort)
fi

if [[ ${#PATCHES[@]} -eq 0 ]]; then
    echo "[INFO] No patches found in ${SCRIPT_DIR}. Vendor tree remains pristine."
    exit 0
fi

echo "Found ${#PATCHES[@]} patch(es) to process."
for patch in "${PATCHES[@]}"; do
    patch_name="$(basename "${patch}")"
    if [[ "${CHECK_ONLY}" == true ]]; then
        echo "Checking patch ${patch_name}..."
        git -C "${VENDOR_DIR}" apply --check "${patch}"
        echo "[PASS] Dry run passed: ${patch_name}"
    else
        echo "Applying patch ${patch_name}..."
        git -C "${VENDOR_DIR}" apply "${patch}"
        echo "[APPLIED] ${patch_name}"
    fi
done
echo "All patches processed successfully."
