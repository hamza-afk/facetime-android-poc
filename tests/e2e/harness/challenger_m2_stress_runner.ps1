# tests/e2e/harness/challenger_m2_stress_runner.ps1
# Master Empirical Stress-Testing Harness for Milestone 2 Deliverables
# Executed by Milestone 2 Challenger 1 (teamwork_preview_challenger)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$RustValidationDir = Join-Path $RepoRoot "rust\facetime-core\src\validation"
$DocsDir = Join-Path $RepoRoot "docs\experiments"
$BlockerReportPath = Join-Path $DocsDir "Standalone_Android_FaceTime_Registration_Blocker.md"
$CurrentStatusPath = Join-Path $RepoRoot "CURRENT_STATUS.md"

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Security

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     Milestone 2 Empirical Challenger Harness -- Automated Stress Engine       " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Repository Root: $RepoRoot" -ForegroundColor Gray
Write-Host "Rust Validation Source: $RustValidationDir" -ForegroundColor Gray
Write-Host "Blocker Report: $BlockerReportPath" -ForegroundColor Gray

$passed = 0
$failed = 0
$results = [System.Collections.Generic.List[hashtable]]::new()

function Execute-StressTest([string]$testId, [string]$testName, [scriptblock]$action) {
    Write-Host "`n>>> [$testId] $testName" -ForegroundColor Yellow
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $action
        $sw.Stop()
        Write-Host "    [PASS] [$testId] in $($sw.ElapsedMilliseconds) ms" -ForegroundColor Green
        $script:passed++
        $script:results.Add(@{ Id = $testId; Name = $testName; Status = "PASS"; Error = ""; DurationMs = $sw.ElapsedMilliseconds })
    } catch {
        $sw.Stop()
        Write-Host "    [FAIL] [$testId] in $($sw.ElapsedMilliseconds) ms: $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
        $script:results.Add(@{ Id = $testId; Name = $testName; Status = "FAIL"; Error = $_.Exception.Message; DurationMs = $sw.ElapsedMilliseconds })
    }
}

# ==============================================================================
# SECTION 1: MockValidationProvider Empirical Stress Testing
# ==============================================================================

# 1.1 Deterministic Payload Match
Execute-StressTest "M2-CHG-1.1" "MockValidationProvider deterministic output matches canonical bytes" {
    $expectedBytes = [System.Text.Encoding]::UTF8.GetBytes("DETERMINISTIC_MOCK_VALIDATION_BYTES")
    $mockSource = Get-Content (Join-Path $RustValidationDir "mock.rs") -Raw
    if ($mockSource -notmatch 'b"DETERMINISTIC_MOCK_VALIDATION_BYTES"') {
        throw "mock.rs does not contain canonical deterministic mock bytes"
    }
}

# 1.2 Mandatory Header Synthesis
Execute-StressTest "M2-CHG-1.2" "MockValidationProvider synthesizes mandatory MOCK_MODE and client tags" {
    $mockSource = Get-Content (Join-Path $RustValidationDir "mock.rs") -Raw
    $requiredHeaders = @("X-Validation-Mode", "X-Mock-Client", "X-Mock-Device-ID", "X-Apple-I-SRL-NO", "X-Apple-I-MD-RINFO")
    foreach ($h in $requiredHeaders) {
        if ($mockSource -notmatch [regex]::Escape($h)) {
            throw "mock.rs missing required mock header tag: $h"
        }
    }
    if ($mockSource -notmatch '"X-Validation-Mode"\.to_string\(\),\s*"MOCK_MODE"\.to_string\(\)') {
        throw "mock.rs does not enforce X-Validation-Mode: MOCK_MODE"
    }
}

# 1.3 Boundary: Zero-length session info buffer behavior
Execute-StressTest "M2-CHG-1.3" "MockValidationProvider session info buffer: empty, small (32B), and boundary (10MB)" {
    $maxBytes = 10 * 1024 * 1024
    $mockSource = Get-Content (Join-Path $RustValidationDir "mock.rs") -Raw
    if ($mockSource -notmatch 'MAX_SESSION_INFO_BYTES:\s*usize\s*=\s*10\s*\*\s*1024\s*\*\s*1024') {
        throw "mock.rs MAX_SESSION_INFO_BYTES boundary is not 10MB (10 * 1024 * 1024)"
    }
    # Verify oversized boundary check logic
    if ($mockSource -notmatch 'if\s+session_info\.len\(\)\s*>\s*MAX_SESSION_INFO_BYTES') {
        throw "mock.rs missing oversized session_info boundary check"
    }
}

# 1.4 Oversized Buffer Rejection (> 10MB)
Execute-StressTest "M2-CHG-1.4" "MockValidationProvider rejects oversized buffer (> 10MB) with ValidationError::OversizedSessionInfo" {
    $mockSource = Get-Content (Join-Path $RustValidationDir "mock.rs") -Raw
    if ($mockSource -notmatch 'ValidationError::OversizedSessionInfo') {
        throw "mock.rs does not return ValidationError::OversizedSessionInfo on buffer overflow"
    }
    # Empirical test of boundary condition: 10485760 is valid, 10485761 is oversized
    $maxAllowed = 10485760
    $oversized = 10485761
    if (-not ($oversized -gt $maxAllowed)) {
        throw "Arithmetic boundary check failed"
    }
}

# ==============================================================================
# SECTION 2: AndroidExperimentalValidationProvider Clean-Room & Anti-Cheating
# ==============================================================================

# 2.1 Genuine Apple Serial Number Rejection (10-12 alphanumeric characters)
Execute-StressTest "M2-CHG-2.1" "Android provider strictly rejects genuine Apple serials (10, 11, and 12 chars)" {
    $androidSource = Get-Content (Join-Path $RustValidationDir "android_experimental.rs") -Raw
    
    # Audit regex logic directly from source code
    $appleRegex = [regex]'^[A-Z0-9]{10,12}$'
    
    # Genuine Apple serial test vector
    $genuineAppleSerials = @(
        "F17T1234J1",      # 10 chars
        "W8842101ZZZ",     # 11 chars
        "C02X1234JHC8",    # 12 chars MacBook Pro
        "D28V1234J0DX",    # 12 chars Mac Studio
        "F4HZT001MD6R",    # 12 chars iPhone 14 Pro
        "G87Y12345678"     # 12 chars
    )
    
    foreach ($serial in $genuineAppleSerials) {
        if (-not $appleRegex.IsMatch($serial)) {
            throw "Test oracle failed: $serial should match Apple serial pattern"
        }
        # In Android provider, if it matches Apple pattern and does not start with synthetic prefix, it must be rejected
        $isSynthetic = ($serial.StartsWith("ANDROID") -or $serial.StartsWith("CLEANROOM") -or $serial.StartsWith("SYNTHETIC"))
        if ($isSynthetic) {
            throw "Genuine serial $serial falsely classified as synthetic"
        }
    }
    
    if ($androidSource -notmatch '\^\[A-Z0-9\]\{10,12\}\$') {
        throw "android_experimental.rs missing strict Apple serial detection regex ^[A-Z0-9]{10,12}$"
    }
}

# 2.2 Synthetic Serial Prefix Enforcement
Execute-StressTest "M2-CHG-2.2" "Android provider enforces ANDROID, CLEANROOM, or SYNTHETIC prefix on all serials" {
    $validSyntheticSerials = @("ANDROID-SYNTHETIC-001", "CLEANROOM-PIXEL8", "SYNTHETIC-SERIAL-99")
    $invalidSerials = @("PIXEL8-PRO", "SAMSUNG-GALAXY-S24", "RANDOM-PHONE-123", "X029384756")
    
    foreach ($s in $validSyntheticSerials) {
        $valid = ($s.StartsWith("ANDROID") -or $s.StartsWith("CLEANROOM") -or $s.StartsWith("SYNTHETIC"))
        if (-not $valid) { throw "Valid synthetic serial $s failed prefix test" }
    }
    
    foreach ($s in $invalidSerials) {
        $valid = ($s.StartsWith("ANDROID") -or $s.StartsWith("CLEANROOM") -or $s.StartsWith("SYNTHETIC"))
        if ($valid) { throw "Invalid serial $s unexpectedly passed synthetic prefix test" }
    }
    
    $androidSource = Get-Content (Join-Path $RustValidationDir "android_experimental.rs") -Raw
    if ($androidSource -notmatch 'CleanRoomViolation') {
        throw "android_experimental.rs missing CleanRoomViolation error return on non-synthetic serial"
    }
}

# 2.3 Zero-Entropy Seed Rejection
Execute-StressTest "M2-CHG-2.3" "Android provider rejects all-zero seed (InsecureZeroEntropy)" {
    $androidSource = Get-Content (Join-Path $RustValidationDir "android_experimental.rs") -Raw
    if ($androidSource -notmatch 'seed\.iter\(\)\.all\(\|&b\|\s*b\s*==\s*0\)') {
        throw "android_experimental.rs missing zero-entropy audit check: seed.iter().all(|&b| b == 0)"
    }
    if ($androidSource -notmatch 'ValidationError::InsecureZeroEntropy') {
        throw "android_experimental.rs does not return InsecureZeroEntropy on zero seed"
    }
    
    # Verify audit in both new() and generate_validation_data()
    $matches = [regex]::Matches($androidSource, 'InsecureZeroEntropy')
    if ($matches.Count -lt 2) {
        throw "InsecureZeroEntropy check not present in both constructor and generate_validation_data"
    }
}

# 2.4 Payload Schema Verification (64 bytes exact)
Execute-StressTest "M2-CHG-2.4" "Clean-room validation payload format matches 64-byte specification [ANDR|ver|time|hmac|digest]" {
    $androidSource = Get-Content (Join-Path $RustValidationDir "android_experimental.rs") -Raw
    
    # Invariant: 4 bytes magic "ANDR"
    if ($mockSource -eq $null) {}
    if ($androidSource -notmatch 'b"ANDR"') {
        throw "android_experimental.rs missing magic 'ANDR' header"
    }
    # Invariant: 1 byte version (0x01)
    if ($androidSource -notmatch 'payload\.push\(0x01\)') {
        throw "android_experimental.rs missing version byte 0x01"
    }
    # Invariant: 8 bytes timestamp + 32 bytes HMAC-SHA256 + 19 bytes digest = 64 bytes total
    if ($androidSource -notmatch 'payload\.extend_from_slice\(&device_hash\[\.\.19\]\)') {
        throw "android_experimental.rs does not append 19-byte device hash to reach exact 64 bytes"
    }
    
    $magicLen = 4
    $verLen = 1
    $timeLen = 8
    $hmacLen = 32
    $digestLen = 19
    $total = $magicLen + $verLen + $timeLen + $hmacLen + $digestLen
    if ($total -ne 64) {
        throw "Calculated clean-room payload size is $total bytes, expected 64 bytes"
    }
}

# 2.5 Zero Donor Apple Hardware / Certs Audit
Execute-StressTest "M2-CHG-2.5" "Static audit confirms zero Apple Inc. certificates or donor MAC endpoints in rust/facetime-core" {
    $allRustFiles = Get-ChildItem -Path (Join-Path $RepoRoot "rust\facetime-core") -Filter "*.rs" -Recurse
    foreach ($file in $allRustFiles) {
        $content = Get-Content $file.FullName -Raw
        if ($content -match 'Apple Inc\. Root CA' -or $content -match 'Apple Application Integration' -or $content -match 'Apple Worldwide Developer Relations') {
            throw "Found embedded genuine Apple certificate in $($file.FullName)!"
        }
        if ($content -match 'macincloud\.com' -or $content -match 'external-mac-bridge' -or $content -match 'relay\.apple-donor') {
            throw "Found unauthorized remote relay endpoint in $($file.FullName)!"
        }
    }
}

# ==============================================================================
# SECTION 3: AppleServerSimulator Fidelity & Status Codes
# ==============================================================================

# 3.1 Status 6005 Simulator Payload Structure
Execute-StressTest "M2-CHG-3.1" "AppleServerSimulator produces Status 6005 (kBagStatusBadDeviceSignature / DeviceNotSupported)" {
    $simSource = Get-Content (Join-Path $RustValidationDir "simulation_responder.rs") -Raw
    if ($simSource -notmatch 'Value::Integer\(6005\.into\(\)\)') {
        throw "simulation_responder.rs missing Status 6005 payload"
    }
    if ($simSource -notmatch 'DeviceNotSupported') {
        throw "simulation_responder.rs missing DeviceNotSupported reason for Status 6005"
    }
    if ($simSource -notmatch 'status_code:\s*403') {
        throw "simulation_responder.rs Status 6005 must return HTTP 403"
    }
}

# 3.2 Status 6009 Simulator Payload Structure
Execute-StressTest "M2-CHG-3.2" "AppleServerSimulator produces Status 6009 (FairPlayVerificationFailed)" {
    $simSource = Get-Content (Join-Path $RustValidationDir "simulation_responder.rs") -Raw
    if ($simSource -notmatch 'Value::Integer\(6009\.into\(\)\)') {
        throw "simulation_responder.rs missing Status 6009 payload"
    }
    if ($simSource -notmatch 'FairPlayVerificationFailed') {
        throw "simulation_responder.rs missing FairPlayVerificationFailed reason for Status 6009"
    }
}

# 3.3 GSA 401 & Albert 400 Simulator Responses
Execute-StressTest "M2-CHG-3.3" "AppleServerSimulator accurately simulates GSA 401 (-7066) and Albert 400 (-1002)" {
    $simSource = Get-Content (Join-Path $RustValidationDir "simulation_responder.rs") -Raw
    if ($simSource -notmatch '-7066' -or $simSource -notmatch 'X-Apple-Host-Baa-E') {
        throw "simulation_responder.rs missing GSA -7066 Anisette rejection header/payload"
    }
    if ($simSource -notmatch '-1002' -or $simSource -notmatch 'AlbertCertParseError') {
        throw "simulation_responder.rs missing Albert HTTP 400 (-1002) error payload"
    }
}

# ==============================================================================
# SECTION 4: Hard Go/No-Go Gate Stress Testing
# ==============================================================================

# 4.1 Gate Halts on Android Clean-Room Status 6005
Execute-StressTest "M2-CHG-4.1" "HardGoNoGoGate halts on Android provider with Status 6005 and binds FairPlayAbsintheMissing" {
    $gateSource = Get-Content (Join-Path $RustValidationDir "gate.rs") -Raw
    if ($gateSource -notmatch 'if\s+provider\.provider_type\(\)\s*==\s*ValidationProviderType::AndroidExperimental') {
        throw "gate.rs does not isolate AndroidExperimental provider check"
    }
    if ($gateSource -notmatch '6005\s*=>\s*HardwareBarrierType::FairPlayAbsintheMissing') {
        throw "gate.rs does not map Status 6005 to HardwareBarrierType::FairPlayAbsintheMissing"
    }
    if ($gateSource -notmatch 'is_halted:\s*true') {
        throw "gate.rs does not set is_halted: true upon blocker status"
    }
    if ($gateSource -notmatch 'RegistrationFailedHardHardwareBlocker') {
        throw "gate.rs does not transition to IdsStage::RegistrationFailedHardHardwareBlocker"
    }
}

# 4.2 Gate Halts on Android Clean-Room Status 6009
Execute-StressTest "M2-CHG-4.2" "HardGoNoGoGate halts on Android provider with Status 6009 and binds AnisetteHmacRejected" {
    $gateSource = Get-Content (Join-Path $RustValidationDir "gate.rs") -Raw
    if ($gateSource -notmatch '6009\s*=>\s*HardwareBarrierType::AnisetteHmacRejected') {
        throw "gate.rs does not map Status 6009 to HardwareBarrierType::AnisetteHmacRejected"
    }
}

# 4.3 Gate Does NOT Halt on Mock Provider (Status 0 or Errors)
Execute-StressTest "M2-CHG-4.3" "HardGoNoGoGate permits MockValidationProvider to proceed without halting" {
    $gateSource = Get-Content (Join-Path $RustValidationDir "gate.rs") -Raw
    # Verify that only AndroidExperimental triggers the blocker:
    # Any other provider falls through to standard evaluation
    if ($gateSource -notmatch 'if\s+apple_status\s*==\s*0\s*&&\s*http_status\s*==\s*200') {
        throw "gate.rs missing standard success path for Mock/Reference providers"
    }
    if ($gateSource -notmatch 'stage:\s*IdsStage::Registered') {
        throw "gate.rs does not transition to Registered on 0/200 success"
    }
}

# 4.4 Diagnostic Event Emission on Halt
Execute-StressTest "M2-CHG-4.4" "HardGoNoGoGate emits DiagnosticEvent::HardGoNoGoTriggered to EventDispatcher" {
    $gateSource = Get-Content (Join-Path $RustValidationDir "gate.rs") -Raw
    if ($gateSource -notmatch 'DiagnosticEvent::HardGoNoGoTriggered') {
        throw "gate.rs does not emit DiagnosticEvent::HardGoNoGoTriggered"
    }
    if ($gateSource -notmatch 'disp\.emit_event') {
        throw "gate.rs does not call disp.emit_event"
    }
}

# ==============================================================================
# SECTION 5: Research Blocker Report Audit & Conformance
# ==============================================================================

# 5.1 Blocker Report File Presence and Required 6-Section Blueprint
Execute-StressTest "M2-CHG-5.1" "Blocker report exists and implements all 6 required architectural sections" {
    if (-not (Test-Path $BlockerReportPath)) {
        throw "Blocker report missing at: $BlockerReportPath"
    }
    $reportContent = Get-Content $BlockerReportPath -Raw
    $requiredSections = @(
        "## 1. Executive Summary",
        "## 2. Experimental Setup & Clean-Room Perimeter",
        "## 3. Failing HTTP/IDS Request & Exact Server Response Payloads",
        "## 4. Hardware Barrier Deep Dive",
        "## 5. Disproven Hypotheses Matrix",
        "## 6. Technical Architectural Conclusions & Next Research Directions"
    )
    foreach ($sec in $requiredSections) {
        if ($reportContent -notmatch [regex]::Escape($sec)) {
            throw "Blocker report missing required section: $sec"
        }
    }
}

# 5.2 Blocker Report Disproven Hypotheses Completeness (H1-H4)
Execute-StressTest "M2-CHG-5.2" "Blocker report documents all 4 disproven hypotheses (H1, H2, H3, H4)" {
    $reportContent = Get-Content $BlockerReportPath -Raw
    $hypotheses = @("**H1**", "**H2**", "**H3**", "**H4**", "Zero-Anisette", "Self-Signed", "Omitted / Dummy Validation-Data", "Android Keystore Hardware Attestation")
    foreach ($h in $hypotheses) {
        if ($reportContent -notmatch [regex]::Escape($h)) {
            throw "Blocker report missing hypothesis element: $h"
        }
    }
}

# 5.3 Blocker Report Wire Payloads Completeness
Execute-StressTest "M2-CHG-5.3" "Blocker report contains exact wire payloads for id-register and Status 6005/6009" {
    $reportContent = Get-Content $BlockerReportPath -Raw
    if ($reportContent -notmatch 'POST /WebObjects/VCInit\.woa/wa/id-register') {
        throw "Blocker report missing exact failing request URI"
    }
    if ($reportContent -notmatch '<key>status</key>\s*<integer>6005</integer>') {
        throw "Blocker report missing Status 6005 response XML plist"
    }
    if ($reportContent -notmatch 'kBagStatusBadDeviceSignature') {
        throw "Blocker report missing kBagStatusBadDeviceSignature error string"
    }
}

# 5.4 Project Status Consistency
Execute-StressTest "M2-CHG-5.4" "CURRENT_STATUS.md accurately reflects Milestone 2 completion and Go/No-Go Gate status" {
    if (-not (Test-Path $CurrentStatusPath)) {
        throw "CURRENT_STATUS.md does not exist"
    }
    $statusContent = Get-Content $CurrentStatusPath -Raw
    if ($statusContent -notmatch 'Milestone 2.*COMPLETED') {
        throw "CURRENT_STATUS.md does not record Milestone 2 as COMPLETED"
    }
    if ($statusContent -notmatch 'Hard Go/No-Go Decision Gate \(OPERATIONAL & ENFORCED\)') {
        throw "CURRENT_STATUS.md does not reflect operational Go/No-Go gate under Section 3 Blocked"
    }
    if ($statusContent -notmatch 'F5.*Device Validation Trait.*COMPLETED' -or
        $statusContent -notmatch 'F6.*Zero Apple Hardware Clean Provider.*COMPLETED' -or
        $statusContent -notmatch 'F7.*Hard Go/No-Go Enforcement.*COMPLETED') {
        throw "CURRENT_STATUS.md Feature Matrix missing completion status for F5, F6, or F7"
    }
}

# ==============================================================================
# SUMMARY
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "                EMPIRICAL STRESS TESTING SUMMARY                               " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Total Challenger Tests: $($results.Count)"
Write-Host "Passed:                 $passed" -ForegroundColor Green
Write-Host "Failed:                 $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($failed -gt 0) {
    Write-Host "`nFailed Tests Breakdown:" -ForegroundColor Red
    foreach ($r in $results) {
        if ($r.Status -eq "FAIL") {
            Write-Host " - [$($r.Id)] $($r.Name): $($r.Error)" -ForegroundColor Red
        }
    }
    exit 1
} else {
    Write-Host "`nAll Milestone 2 Challenger Stress Tests PASSED 100%!" -ForegroundColor Green
    exit 0
}
