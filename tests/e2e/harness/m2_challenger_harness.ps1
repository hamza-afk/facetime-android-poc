# tests/e2e/harness/m2_challenger_harness.ps1
# Master Empirical Stress-Testing, Blocker Integrity & Falsifiability Harness for Milestone 2
# Executed by Milestone 2 Challenger 2

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$BlockerReportPath = Join-Path $RepoRoot "docs\experiments\Standalone_Android_FaceTime_Registration_Blocker.md"
$Tier1Path = Join-Path $RepoRoot "tests\e2e\tier1_features.ps1"
$Tier4Path = Join-Path $RepoRoot "tests\e2e\tier4_real_world.ps1"
$WireCheckersPath = Join-Path $RepoRoot "tests\e2e\harness\ProtocolWireCheckers.ps1"
$RunTestsPath = Join-Path $RepoRoot "tests\e2e\run_tests.ps1"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     Milestone 2 Challenger 2 -- Empirical Verification & Falsifiability Harness " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Repository Root: $RepoRoot" -ForegroundColor Gray
Write-Host "Blocker Report:  $BlockerReportPath" -ForegroundColor Gray

function Invoke-IsolatedProcess([string]$arguments) {
    $pinfo = [System.Diagnostics.ProcessStartInfo]::new("powershell.exe", $arguments)
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $pinfo.WorkingDirectory = $RepoRoot
    $proc = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [PSCustomObject]@{
        ExitCode = $proc.ExitCode
        Output = "$stdout`n$stderr"
    }
}

$passed = 0
$failed = 0
$results = [System.Collections.Generic.List[hashtable]]::new()

function Execute-ChallengeTest([string]$testId, [string]$testName, [scriptblock]$action) {
    Write-Host "`n>>> [$testId] $testName" -ForegroundColor Yellow
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $action
        $sw.Stop()
        Write-Host "    [PASS] [$testId] ($($sw.ElapsedMilliseconds) ms)" -ForegroundColor Green
        $script:passed++
        $script:results.Add(@{ Id = $testId; Name = $testName; Status = "PASS"; Error = ""; DurationMs = $sw.ElapsedMilliseconds })
    } catch {
        $sw.Stop()
        Write-Host "    [FAIL] [$testId] ($($sw.ElapsedMilliseconds) ms): $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
        $script:results.Add(@{ Id = $testId; Name = $testName; Status = "FAIL"; Error = $_.Exception.Message; DurationMs = $sw.ElapsedMilliseconds })
    }
}

# ==============================================================================
# SECTION 1: Blocker Report Integrity Challenge
# ==============================================================================
Write-Host "`n--- SECTION 1: BLOCKER REPORT INTEGRITY CHALLENGE ---" -ForegroundColor Magenta

Execute-ChallengeTest "CHG2-REP-1.1" "Verify file existence and non-empty content" {
    if (-not (Test-Path $BlockerReportPath)) {
        throw "Blocker report file does not exist at $BlockerReportPath"
    }
    $content = Get-Content $BlockerReportPath -Raw
    if ($content.Length -lt 2000) {
        throw "Blocker report content is suspiciously small: $($content.Length) bytes"
    }
}

Execute-ChallengeTest "CHG2-REP-1.2" "Verify all 6 required architectural sections" {
    $content = Get-Content $BlockerReportPath -Raw
    $requiredSections = @(
        "## 1. Executive Summary",
        "## 2. Experimental Setup & Clean-Room Perimeter",
        "## 3. Failing HTTP/IDS Request & Exact Server Response Payloads",
        "## 4. Hardware Barrier Deep Dive",
        "## 5. Disproven Hypotheses Matrix",
        "## 6. Technical Architectural Conclusions & Next Research Directions"
    )
    foreach ($sec in $requiredSections) {
        if (-not $content.Contains($sec)) {
            throw "Blocker report missing mandatory section: '$sec'"
        }
    }
}

Execute-ChallengeTest "CHG2-REP-1.3" "Verify all 4 disproven hypotheses (H1-H4) and technical rationales" {
    $content = Get-Content $BlockerReportPath -Raw
    $requiredHypotheses = @(
        @{ Id = "H1"; Term = "Zero-Anisette Synthetic Generation"; Rationale = "GSA decrypts" },
        @{ Id = "H2"; Term = "Self-Signed APS Push Certificate"; Rationale = "Albert HTTP 400" },
        @{ Id = "H3"; Term = "Omitted / Dummy Validation-Data on IDS"; Rationale = "Status 6005" },
        @{ Id = "H4"; Term = "Android Keystore Hardware Attestation Substitution"; Rationale = "Keymaster" }
    )
    foreach ($h in $requiredHypotheses) {
        if (-not $content.Contains($h.Id)) {
            throw "Blocker report missing hypothesis identifier: $($h.Id)"
        }
        if (-not $content.Contains($h.Term)) {
            throw "Blocker report missing hypothesis term: $($h.Term)"
        }
        if (-not ($content -match $h.Rationale)) {
            throw "Blocker report missing rationale pattern '$($h.Rationale)' for $($h.Id)"
        }
    }
}

Execute-ChallengeTest "CHG2-REP-1.4" "Verify failing HTTP request wire envelope and decompressed plist" {
    $content = Get-Content $BlockerReportPath -Raw
    $requiredRequestTokens = @(
        "POST /WebObjects/VCInit.woa/wa/id-register HTTP/1.1",
        "Host: init.ess.apple.com",
        "x-protocol-version: 1760",
        "x-push-token:",
        "x-push-nonce:",
        "x-push-sig:",
        "x-push-cert:",
        "x-auth-user-id-0:",
        "x-auth-nonce-0:",
        "x-auth-sig-0:",
        "x-auth-cert-0:",
        "<key>validation-data</key>",
        "<key>services</key>",
        "com.apple.private.alloy.facetime.multi",
        "<key>public-message-identity-key</key>",
        "<key>public-message-ngm-device-prekey-data-key</key>"
    )
    foreach ($token in $requiredRequestTokens) {
        if (-not $content.Contains($token)) {
            throw "Blocker report missing request token: '$token'"
        }
    }
}

Execute-ChallengeTest "CHG2-REP-1.5" "Verify failing HTTP response envelope and rejection plist details" {
    $content = Get-Content $BlockerReportPath -Raw
    $requiredResponseTokens = @(
        "HTTP/1.1 403 Forbidden",
        "<key>status</key>",
        "<integer>6005</integer>",
        "<string>ValidationDataRejected</string>",
        "<string>kBagStatusBadDeviceSignature</string>",
        "Status 6009",
        "kBagStatusFairPlayVerificationFailed",
        "Albert HTTP 400",
        "AlbertCertParseError"
    )
    foreach ($token in $requiredResponseTokens) {
        if (-not $content.Contains($token)) {
            throw "Blocker report missing response token: '$token'"
        }
    }
}

# ==============================================================================
# SECTION 2: Test Falsifiability Challenge (Mutations & Non-Zero Exit Codes)
# ==============================================================================
Write-Host "`n--- SECTION 2: TEST FALSIFIABILITY CHALLENGE ---" -ForegroundColor Magenta

Execute-ChallengeTest "CHG2-FAL-2.1" "Mutation F5.3: Corrupting MOCK_MODE header causes test failure and exit code 1" {
    $origContent = Get-Content $Tier1Path -Raw
    $bakPath = "$Tier1Path.f5bak"
    Copy-Item $Tier1Path $bakPath
    try {
        $mutatedContent = $origContent.Replace('"MOCK_MODE"', '"CORRUPTED_INCORRECT_MODE"')
        Set-Content -Path $Tier1Path -Value $mutatedContent -NoNewline

        $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`" -Feature 5"
        if ($res.ExitCode -eq 0) {
            throw "Falsifiability failed: run_tests.ps1 returned 0 despite mutated MOCK_MODE header!"
        }
        if ($res.Output -notmatch 'FAIL.*T1\.F5\.[23]') {
            throw "Falsifiability failed: expected T1.F5.2/3 failure not found in output. Output: $($res.Output)"
        }
    } finally {
        Move-Item -Force $bakPath $Tier1Path
    }

    # Verify recovery
    $resRecover = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`" -Feature 5"
    if ($resRecover.ExitCode -ne 0) {
        throw "Failed to recover cleanly after F5 mutation! ExitCode=$($resRecover.ExitCode)"
    }
}

Execute-ChallengeTest "CHG2-FAL-2.2" "Mutation F6.2: Injecting genuine Apple serial triggers anti-cheating failure and exit code 1" {
    $origContent = Get-Content $Tier1Path -Raw
    $bakPath = "$Tier1Path.f6bak"
    Copy-Item $Tier1Path $bakPath
    try {
        # Inject genuine 12-char Apple serial C02X1234JHC8
        $mutatedContent = $origContent.Replace('"ANDROID-SYNTHETIC-999"', '"C02X1234JHC8"')
        Set-Content -Path $Tier1Path -Value $mutatedContent -NoNewline

        $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`" -Feature 6"
        if ($res.ExitCode -eq 0) {
            throw "Falsifiability failed: run_tests.ps1 returned 0 despite genuine Apple serial injection!"
        }
        if ($res.Output -notmatch 'Anti-Cheating Failure: Genuine Apple serial number detected') {
            throw "Falsifiability failed: anti-cheating exception not found in output. Output: $($res.Output)"
        }
    } finally {
        Move-Item -Force $bakPath $Tier1Path
    }

    # Verify recovery
    $resRecover = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`" -Feature 6"
    if ($resRecover.ExitCode -ne 0) {
        throw "Failed to recover cleanly after F6 mutation! ExitCode=$($resRecover.ExitCode)"
    }
}

Execute-ChallengeTest "CHG2-FAL-2.3" "Mutation F7.1: Mutating Go/No-Go server status 6005 to 200 causes exit code 1" {
    $origContent = Get-Content $Tier1Path -Raw
    $bakPath = "$Tier1Path.f7bak"
    Copy-Item $Tier1Path $bakPath
    try {
        $mutatedContent = $origContent.Replace('$serverStatus = 6005', '$serverStatus = 200')
        Set-Content -Path $Tier1Path -Value $mutatedContent -NoNewline

        $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`" -Feature 7"
        if ($res.ExitCode -eq 0) {
            throw "Falsifiability failed: run_tests.ps1 returned 0 despite mutating Go/No-Go status to 200!"
        }
        if ($res.Output -notmatch 'Server rejection 6005 must trigger Go/No-Go halt') {
            throw "Falsifiability failed: expected Go/No-Go halt assertion failure. Output: $($res.Output)"
        }
    } finally {
        Move-Item -Force $bakPath $Tier1Path
    }

    # Verify recovery
    $resRecover = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`" -Feature 7"
    if ($resRecover.ExitCode -ne 0) {
        throw "Failed to recover cleanly after F7 mutation! ExitCode=$($resRecover.ExitCode)"
    }
}

Execute-ChallengeTest "CHG2-FAL-2.4" "Mutation WireChecker: Breaking Android provider prefix rule causes exit code 1" {
    $origContent = Get-Content $WireCheckersPath -Raw
    $bakPath = "$WireCheckersPath.wirebak"
    Copy-Item $WireCheckersPath $bakPath
    try {
        # Force ValidateProviderOutput to fail for AndroidExperimental
        $mutatedContent = $origContent.Replace("if (`$srl -notmatch 'ANDROID|CLEANROOM') { return `$false }", "return `$false")
        Set-Content -Path $WireCheckersPath -Value $mutatedContent -NoNewline

        $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`" -Feature 6"
        if ($res.ExitCode -eq 0) {
            throw "Falsifiability failed: run_tests.ps1 returned 0 despite breaking ProtocolWireCheckers ValidateProviderOutput!"
        }
        if ($res.Output -notmatch 'FAIL.*T1\.F6\.5') {
            throw "Falsifiability failed: expected T1.F6.5 failure. Output: $($res.Output)"
        }
    } finally {
        Move-Item -Force $bakPath $WireCheckersPath
    }

    # Verify recovery
    $resRecover = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`" -Feature 6"
    if ($resRecover.ExitCode -ne 0) {
        throw "Failed to recover cleanly after WireChecker mutation! ExitCode=$($resRecover.ExitCode)"
    }
}

Execute-ChallengeTest "CHG2-FAL-2.5" "Mutation Tier 4: Mutating Hard Go/No-Go scenario expected status causes exit code 1" {
    $origContent = Get-Content $Tier4Path -Raw
    $bakPath = "$Tier4Path.t4bak"
    Copy-Item $Tier4Path $bakPath
    try {
        $mutatedContent = $origContent.Replace('Assert-Equal 6005 $res.status', 'Assert-Equal 200 $res.status')
        Set-Content -Path $Tier4Path -Value $mutatedContent -NoNewline

        $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`" -Tier 4"
        if ($res.ExitCode -eq 0) {
            throw "Falsifiability failed: run_tests.ps1 returned 0 despite mutating Scenario 3 expected status!"
        }
        if ($res.Output -notmatch 'FAIL.*T4\.RW\.3') {
            throw "Falsifiability failed: expected T4.RW.3 failure. Output: $($res.Output)"
        }
    } finally {
        Move-Item -Force $bakPath $Tier4Path
    }

    # Verify recovery
    $resRecover = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`" -Tier 4"
    if ($resRecover.ExitCode -ne 0) {
        throw "Failed to recover cleanly after Tier 4 mutation! ExitCode=$($resRecover.ExitCode)"
    }
}

# ==============================================================================
# SECTION 3: Master E2E Suite Execution Across All 4 Tiers
# ==============================================================================
Write-Host "`n--- SECTION 3: MASTER E2E SUITE EXECUTION ---" -ForegroundColor Magenta

Execute-ChallengeTest "CHG2-E2E-3.1" "Execute master E2E test suite across all 4 tiers (218 / 218 tests)" {
    $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RunTestsPath`""
    if ($res.ExitCode -ne 0) {
        throw "Master E2E suite returned non-zero exit code: $($res.ExitCode). Output: $($res.Output)"
    }
    if ($res.Output -notmatch 'Total Tests:\s+218') {
        throw "Master E2E suite did not run 218 tests. Output: $($res.Output)"
    }
    if ($res.Output -notmatch 'Passed:\s+218') {
        throw "Master E2E suite did not pass all 218 tests. Output: $($res.Output)"
    }
    if ($res.Output -notmatch 'Failed:\s+0') {
        throw "Master E2E suite had failures. Output: $($res.Output)"
    }
}

# ==============================================================================
# Summary
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "                CHALLENGER 2 EMPIRICAL SUMMARY                                  " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Total Challenge Tests: $($results.Count)" -ForegroundColor White
Write-Host "Passed:                $passed" -ForegroundColor Green
Write-Host "Failed:                $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
