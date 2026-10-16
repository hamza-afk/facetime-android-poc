#!/usr/bin/env bash
# run_tests.sh — Bash wrapper for FaceTime Android PoC E2E test runner
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Running FaceTime Android PoC E2E Test Suite..."

if command -v pwsh >/dev/null 2>&1; then
    pwsh -ExecutionPolicy Bypass -File "$SCRIPT_DIR/run_tests.ps1" "$@"
elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/run_tests.ps1" "$@"
elif command -v powershell >/dev/null 2>&1; then
    powershell -ExecutionPolicy Bypass -File "$SCRIPT_DIR/run_tests.ps1" "$@"
else
    echo "Error: PowerShell runtime (pwsh or powershell) required to execute tests." >&2
    exit 1
fi
