#!/usr/bin/env bash
# vendor/patches/revert-patches.sh
# Reverts all patches in reverse order
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VENDOR_DIR="${REPO_ROOT}/vendor/rustpush"
SERIES_FILE="${SCRIPT_DIR}/series"

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
    echo "[INFO] No patches to revert."
    exit 0
fi

echo "Reverting ${#PATCHES[@]} patch(es) in reverse order..."
for (( i=${#PATCHES[@]}-1; i>=0; i-- )); do
    patch="${PATCHES[i]}"
    patch_name="$(basename "${patch}")"
    echo "Reverting ${patch_name}..."
    git -C "${VENDOR_DIR}" apply -R "${patch}"
    echo "[REVERTED] ${patch_name}"
done
echo "All patches reverted successfully."
