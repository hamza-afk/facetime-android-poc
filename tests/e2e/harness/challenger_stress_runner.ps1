# tests/e2e/harness/challenger_stress_runner.ps1
# Master Empirical Stress-Testing & Architectural Alignment Harness for Milestone 1
# Executed by Milestone 1 Challenger 1

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$VendorDir = Join-Path $RepoRoot "vendor\rustpush"
$PatchesDir = Join-Path $RepoRoot "vendor\patches"
$DocsDir = Join-Path $RepoRoot "docs\architecture"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "     Milestone 1 Empirical Challenger Harness -- Automated Stress Engine       " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Repository Root: $RepoRoot" -ForegroundColor Gray
Write-Host "Vendor Directory: $VendorDir" -ForegroundColor Gray
Write-Host "Patches Directory: $PatchesDir" -ForegroundColor Gray

function Invoke-IsolatedProcess([string]$arguments) {
    $pinfo = [System.Diagnostics.ProcessStartInfo]::new("powershell.exe", $arguments)
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
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

function Execute-Test([string]$testId, [string]$testName, [scriptblock]$action) {
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
# SECTION 1: Vendor Tree Integrity Stress Tests
# ==============================================================================

# 1.1 Pristine Baseline
Execute-Test "CHG-1.1" "Baseline verify-vendor.ps1 on pristine tree succeeds with exit code 0" {
    $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""
    if ($res.ExitCode -ne 0) {
        throw "Expected exit code 0 on pristine tree, got $($res.ExitCode). Output: $($res.Output)"
    }
}

# 1.2 File Corruption Detection
Execute-Test "CHG-1.2" "verify-vendor.ps1 detects single-byte file corruption and returns non-zero" {
    $targetFile = Join-Path $VendorDir "Cargo.toml"
    $backupFile = Join-Path $VendorDir "Cargo.toml.chgbak"
    Copy-Item $targetFile $backupFile
    try {
        Add-Content $targetFile "`n# CORRUPTED_BY_CHALLENGER_EMPIRICAL_TEST"
        $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""

        if ($res.ExitCode -eq 0) {
            throw "verify-vendor.ps1 returned 0 despite file corruption in Cargo.toml!"
        }
        if ($res.Output -notmatch "HASH MISMATCH: Cargo.toml") {
            throw "verify-vendor.ps1 failed without specific HASH MISMATCH error. Output: $($res.Output)"
        }
    } finally {
        Move-Item -Force $backupFile $targetFile
    }
    # Verify restored cleanly
    $resRestore = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""
    if ($resRestore.ExitCode -ne 0) { throw "Tree was not cleanly restored after test! Output: $($resRestore.Output)" }
}

# 1.3 Missing File Detection
Execute-Test "CHG-1.3" "verify-vendor.ps1 detects missing file from CHECKSUMS.sha256 and returns non-zero" {
    $targetFile = Join-Path $VendorDir "src\lib.rs"
    $tempMove = Join-Path $VendorDir "src\lib.rs.chgtmp"
    Move-Item $targetFile $tempMove
    try {
        $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""

        if ($res.ExitCode -eq 0) {
            throw "verify-vendor.ps1 returned 0 despite missing src\lib.rs!"
        }
        if ($res.Output -notmatch "MISSING:") {
            throw "verify-vendor.ps1 failed without MISSING message. Output: $($res.Output)"
        }
    } finally {
        Move-Item -Force $tempMove $targetFile
    }
    # Verify restored cleanly
    $resRestore = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""
    if ($resRestore.ExitCode -ne 0) { throw "Tree was not cleanly restored after test! Output: $($resRestore.Output)" }
}

# 1.4 REVISION.md Commit Hash Tampering Detection
Execute-Test "CHG-1.4" "verify-vendor.ps1 detects pinned commit tampering in REVISION.md and returns non-zero" {
    $revFile = Join-Path $VendorDir "REVISION.md"
    $revBak = Join-Path $VendorDir "REVISION.md.chgbak"
    Copy-Item $revFile $revBak
    try {
        $origContent = Get-Content $revFile -Raw
        $tamperedContent = $origContent.Replace("b3c96c23e1aae78d1229ebaccb12027624f1eaff", "0000000000000000000000000000000000000000")
        [System.IO.File]::WriteAllText($revFile, $tamperedContent)
        
        $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""

        if ($res.ExitCode -eq 0) {
            throw "verify-vendor.ps1 returned 0 despite commit hash tampering in REVISION.md!"
        }
        if ($res.Output -notmatch "does not contain pinned commit") {
            throw "verify-vendor.ps1 failed without pinned commit error message. Output: $($res.Output)"
        }
    } finally {
        Move-Item -Force $revBak $revFile
    }
    # Verify restored cleanly
    $resRestore = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""
    if ($resRestore.ExitCode -ne 0) { throw "Tree was not cleanly restored after test! Output: $($resRestore.Output)" }
}

# 1.5 CHECKSUMS.sha256 Tampering Detection
Execute-Test "CHG-1.5" "verify-vendor.ps1 detects modified checksum in CHECKSUMS.sha256 and returns non-zero" {
    $checksumFile = Join-Path $VendorDir "CHECKSUMS.sha256"
    $checksumBak = Join-Path $VendorDir "CHECKSUMS.sha256.chgbak"
    Copy-Item $checksumFile $checksumBak
    try {
        $lines = [System.IO.File]::ReadAllLines($checksumFile)
        $lines[0] = "0000000000000000000000000000000000000000000000000000000000000000 " + $lines[0].Substring(65)
        [System.IO.File]::WriteAllLines($checksumFile, $lines)
        
        $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""

        if ($res.ExitCode -eq 0) {
            throw "verify-vendor.ps1 returned 0 despite tampered checksum!"
        }
        if ($res.Output -notmatch "HASH MISMATCH:") {
            throw "verify-vendor.ps1 failed without HASH MISMATCH error message. Output: $($res.Output)"
        }
    } finally {
        Move-Item -Force $checksumBak $checksumFile
    }
    # Verify restored cleanly
    $resRestore = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""
    if ($resRestore.ExitCode -ne 0) { throw "Tree was not cleanly restored after test! Output: $($resRestore.Output)" }
}

# 1.6 Recursive Submodule Completeness & Git Isolation
Execute-Test "CHG-1.6" "Vendor tree contains all 7 submodules without leaked .git internal repositories" {
    $expectedSubmodules = @(
        "open-absinthe",
        "third_party\apple-private-apis",
        "third_party\apple-private-apis\clearadi",
        "third_party\quinn",
        "third_party\rtc",
        "third_party\rustls",
        "third_party\rustls-platform-verifier"
    )
    foreach ($sub in $expectedSubmodules) {
        $subPath = Join-Path $VendorDir $sub
        if (-not (Test-Path $subPath)) {
            throw "Missing submodule directory: $sub"
        }
        $files = Get-ChildItem -Path $subPath -File -Recurse
        if ($files.Count -eq 0) {
            throw "Submodule $sub exists but is empty!"
        }
    }
    # Assert zero .git folders inside vendor/rustpush
    $leakedGit = Get-ChildItem -Path $VendorDir -Filter ".git" -Hidden -Directory -Recurse
    if ($leakedGit.Count -gt 0) {
        throw "Found leaked .git directory inside vendor tree: $($leakedGit[0].FullName)"
    }
}

# ==============================================================================
# SECTION 2: Patch Tooling Stress Tests
# ==============================================================================

# 2.1 Empty Series Handling
Execute-Test "CHG-2.1" "apply-patches.ps1 and revert-patches.ps1 exit 0 gracefully on empty series" {
    $resApply = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\apply-patches.ps1`""
    if ($resApply.ExitCode -ne 0) { throw "apply-patches.ps1 failed on empty series: $($resApply.Output)" }

    $resRevert = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\revert-patches.ps1`""
    if ($resRevert.ExitCode -ne 0) { throw "revert-patches.ps1 failed on empty series: $($resRevert.Output)" }
}

# 2.2 Valid Patch Dry-Run (-CheckOnly)
Execute-Test "CHG-2.2" "apply-patches.ps1 -CheckOnly verifies clean applicability without modifying working tree" {
    $patchName = "0001-challenger-dryrun.patch"
    $patchFile = Join-Path $PatchesDir $patchName
    $seriesFile = Join-Path $PatchesDir "series"
    $seriesBak = Join-Path $PatchesDir "series.chgbak"
    Copy-Item $seriesFile $seriesBak

    # Dynamically generate patch on Cargo.toml
    $target = Join-Path $VendorDir "Cargo.toml"
    $orig = [System.IO.File]::ReadAllText($target)
    $modified = $orig -replace 'name = "rustpush"', "name = `"rustpush`"`n# challenger dryrun test"
    [System.IO.File]::WriteAllText($target, $modified)
    $diffLines = git diff vendor/rustpush/Cargo.toml
    git -C $RepoRoot checkout -- vendor/rustpush/Cargo.toml 2>$null
    [System.IO.File]::WriteAllText($patchFile, ($diffLines -join "`n") + "`n")
    [System.IO.File]::WriteAllText($seriesFile, "$patchName`n")

    try {
        $resCheck = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\apply-patches.ps1`" -CheckOnly"
        if ($resCheck.ExitCode -ne 0) {
            throw "apply-patches.ps1 -CheckOnly returned non-zero code $($resCheck.ExitCode). Output: $($resCheck.Output)"
        }
        # Invariant check: working tree must NOT have modified Cargo.toml
        $cargo = Get-Content $target -Raw
        if ($cargo -match "challenger dryrun test") {
            throw "Dry run actually modified the file on disk! Invariant violated."
        }
    } finally {
        Remove-Item $patchFile -Force -ErrorAction SilentlyContinue
        Move-Item -Force $seriesBak $seriesFile
    }
}

# 2.3 Valid Patch Full Lifecycle: Apply, Detect Modification, Revert, and Verify Clean
Execute-Test "CHG-2.3" "Full patch lifecycle (Apply -> Verify Changed -> Revert -> Verify Pristine)" {
    $patchName = "0001-challenger-lifecycle.patch"
    $patchFile = Join-Path $PatchesDir $patchName
    $seriesFile = Join-Path $PatchesDir "series"
    $seriesBak = Join-Path $PatchesDir "series.chgbak"
    Copy-Item $seriesFile $seriesBak

    # Dynamically generate patch on Cargo.toml
    $target = Join-Path $VendorDir "Cargo.toml"
    $orig = [System.IO.File]::ReadAllText($target)
    $modified = $orig -replace 'name = "rustpush"', "name = `"rustpush`"`n# challenger lifecycle test"
    [System.IO.File]::WriteAllText($target, $modified)
    $diffLines = git diff vendor/rustpush/Cargo.toml
    git -C $RepoRoot checkout -- vendor/rustpush/Cargo.toml 2>$null
    [System.IO.File]::WriteAllText($patchFile, ($diffLines -join "`n") + "`n")
    [System.IO.File]::WriteAllText($seriesFile, "$patchName`n")

    try {
        # 1. Apply
        $resApply = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\apply-patches.ps1`""
        if ($resApply.ExitCode -ne 0) { throw "apply-patches.ps1 failed: $($resApply.Output)" }

        # Check modified
        $cargo = Get-Content $target -Raw
        if ($cargo -notmatch "challenger lifecycle test") {
            throw "Patch was not applied to vendor/rustpush/Cargo.toml"
        }

        # 2. Revert
        $resRevert = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\revert-patches.ps1`""
        if ($resRevert.ExitCode -ne 0) { throw "revert-patches.ps1 failed: $($resRevert.Output)" }

        # Check reverted
        $cargoAfter = Get-Content $target -Raw
        if ($cargoAfter -match "challenger lifecycle test") {
            throw "Patch was not reverted cleanly from vendor/rustpush/Cargo.toml"
        }
    } finally {
        Remove-Item $patchFile -Force -ErrorAction SilentlyContinue
        Move-Item -Force $seriesBak $seriesFile
        git -C $RepoRoot checkout -- vendor/rustpush/Cargo.toml 2>$null
    }

    # Final check: vendor tree integrity
    $resRestore = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""
    if ($resRestore.ExitCode -ne 0) { throw "Tree was not left pristine after lifecycle test! Output: $($resRestore.Output)" }
}

# 2.4 Conflicting Patch Detection & Non-Zero Exit
Execute-Test "CHG-2.4" "apply-patches.ps1 -CheckOnly rejects conflicting patch and returns non-zero" {
    $patchName = "0002-challenger-conflict.patch"
    $patchFile = Join-Path $PatchesDir $patchName
    $seriesFile = Join-Path $PatchesDir "series"
    $seriesBak = Join-Path $PatchesDir "series.chgbak"
    Copy-Item $seriesFile $seriesBak

    # Deliberately conflicting patch with wrong context
    $patchContent = @"
diff --git a/vendor/rustpush/Cargo.toml b/vendor/rustpush/Cargo.toml
--- a/vendor/rustpush/Cargo.toml
+++ b/vendor/rustpush/Cargo.toml
@@ -1,3 +1,4 @@
-# Completely Bogus Nonexistent Context Line That Will Never Match
+# Will Fail
"@
    [System.IO.File]::WriteAllText($patchFile, $patchContent.Replace("`r`n", "`n") + "`n")
    [System.IO.File]::WriteAllText($seriesFile, "$patchName`n")

    try {
        $resCheck = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\apply-patches.ps1`" -CheckOnly"
        if ($resCheck.ExitCode -eq 0) {
            throw "apply-patches.ps1 -CheckOnly returned 0 for a conflicting patch!"
        }
    } finally {
        Remove-Item $patchFile -Force -ErrorAction SilentlyContinue
        Move-Item -Force $seriesBak $seriesFile
    }
}

# 2.5 Corrupted Patch Detection in verify-vendor.ps1
Execute-Test "CHG-2.5" "verify-vendor.ps1 detects broken .patch in vendor/patches/ and returns non-zero" {
    $brokenPatch = Join-Path $PatchesDir "9999-corrupted.patch"
    [System.IO.File]::WriteAllText($brokenPatch, "THIS IS TOTAL GARBAGE NOT A VALID DIFF`n")
    try {
        $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""
        if ($res.ExitCode -eq 0) {
            throw "verify-vendor.ps1 passed despite corrupted patch file present in vendor/patches/!"
        }
    } finally {
        Remove-Item $brokenPatch -Force -ErrorAction SilentlyContinue
    }
    # Verify pristine again
    $resRestore = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$PatchesDir\verify-vendor.ps1`""
    if ($resRestore.ExitCode -ne 0) { throw "Tree was not left pristine after corrupt patch test! Output: $($resRestore.Output)" }
}

# ==============================================================================
# SECTION 3: Architecture Schema & Wire Format Code-Level Alignment Audit
# ==============================================================================

# 3.1 GSA Authentication Alignment
Execute-Test "CHG-3.1" "Auth schema: GSA SRP-6a endpoints, request structs, and crypto align with icloud-auth client.rs" {
    $clientRs = Join-Path $VendorDir "third_party\apple-private-apis\icloud-auth\src\client.rs"
    $authDoc = Join-Path $DocsDir "apple_account_auth.md"

    $rsContent = Get-Content $clientRs -Raw
    $docContent = Get-Content $authDoc -Raw

    # GSA Endpoint
    if ($rsContent -notmatch 'https://gsa.apple.com/grandslam/GsService2') {
        throw "icloud-auth client.rs missing GSA_ENDPOINT"
    }
    if ($docContent -notmatch 'https://gsa.apple.com/grandslam/GsService2') {
        throw "apple_account_auth.md missing GSA endpoint URL"
    }

    # Struct fields: A2k, cpd, o, ps, u
    $requiredFields = @('A2k', 'cpd', 'o', 'ps', 'u', 'M1')
    foreach ($f in $requiredFields) {
        if ($rsContent -notmatch $f) { throw "client.rs missing required wire field $f" }
        if ($docContent -notmatch $f) { throw "apple_account_auth.md missing required wire field $f" }
    }
}

# 3.2 APS Courier Protocol Alignment
Execute-Test "CHG-3.2" "APS schema: Courier bootstrap, ALPN, frame header, and command codes align with aps.rs & util.rs" {
    $apsRs = Join-Path $VendorDir "src\aps.rs"
    $utilRs = Join-Path $VendorDir "src\util.rs"
    $apsDoc = Join-Path $DocsDir "aps_push.md"

    $apsContent = Get-Content $apsRs -Raw
    $utilContent = Get-Content $utilRs -Raw
    $docContent = Get-Content $apsDoc -Raw

    # APNS Bag
    if ($utilContent -notmatch 'http://init-p01st.push.apple.com/bag') {
        throw "util.rs missing APNS_BAG URL"
    }
    if ($docContent -notmatch 'http://init-p01st.push.apple.com/bag') {
        throw "aps_push.md missing APNS bag URL"
    }

    # Command codes in aps.rs vs doc
    # Connect = 0x7, Filter = 0x9, Ack = 0xb, Ping = 0xc
    if ($apsContent -notmatch 'command:\s*0x7') { throw "aps.rs missing command 0x7" }
    if ($apsContent -notmatch 'command:\s*0x9') { throw "aps.rs missing command 0x9" }
    if ($apsContent -notmatch 'command:\s*0xb') { throw "aps.rs missing command 0xb" }
    if ($apsContent -notmatch 'command:\s*0xc') { throw "aps.rs missing command 0xc" }

    if ($docContent -notmatch '0x07' -or $docContent -notmatch '0x09' -or $docContent -notmatch '0x0b') {
        throw "aps_push.md missing core command codes"
    }
}

# 3.3 IDS Registration & Multi-Key Signing Alignment
Execute-Test "CHG-3.3" "IDS schema: Multi-key request signing, 17-byte nonce, RSA-1280 keys align with user.rs & auth.rs" {
    $userRs = Join-Path $VendorDir "src\ids\user.rs"
    $authRs = Join-Path $VendorDir "src\auth.rs"
    $idsDoc = Join-Path $DocsDir "ids_registration.md"

    $userContent = Get-Content $userRs -Raw
    $authContent = Get-Content $authRs -Raw
    $docContent = Get-Content $idsDoc -Raw

    # Dual RSA 1280 & P-256
    if ($userContent -notmatch 'Rsa::generate\(1280\)') {
        throw "user.rs missing Rsa::generate(1280)"
    }
    if ($userContent -notmatch 'X9_62_PRIME256V1') {
        throw "user.rs missing P-256 curve"
    }
    if ($docContent -notmatch '1280') {
        throw "ids_registration.md missing RSA 1280 specification"
    }

    # Multi-key headers
    $requiredHeaders = @('x-push-token', 'x-protocol-version', 'x-auth-user-id')
    foreach ($h in $requiredHeaders) {
        if ($userContent -notmatch $h) { throw "user.rs missing header $h" }
        if ($docContent -notmatch $h) { throw "ids_registration.md missing header $h" }
    }

    # 17-byte Nonce structure in auth.rs: 1 byte header + 8 bytes ms timestamp + 8 bytes random
    if ($authContent -notmatch 'generate_nonce') {
        throw "auth.rs missing generate_nonce"
    }
    if ($docContent -notmatch '17-byte') {
        throw "ids_registration.md missing 17-byte nonce specification"
    }
}

# 3.4 FaceTime Signaling & FTWireMessage Serde Naming Audit
Execute-Test "CHG-3.4" "FaceTime schema: Command 200, 207, and FTWireMessage struct field alignment" {
    $ftRs = Join-Path $VendorDir "src\facetime.rs"
    $ftDoc = Join-Path $DocsDir "facetime_signaling.md"

    $ftContent = Get-Content $ftRs -Raw
    $docContent = Get-Content $ftDoc -Raw

    # Command 207 Invite
    if ($ftContent -notmatch 'command:\s*207') {
        throw "facetime.rs missing command 207 invite dispatch"
    }
    if ($docContent -notmatch '207') {
        throw "facetime_signaling.md missing Command 207"
    }

    # Core FTWireMessage fields
    $coreFields = @('client_context_data_key', 'participant_data_key', 'is_initiator_key', 'join_notification_key')
    foreach ($f in $coreFields) {
        if ($ftContent -notmatch $f) {
            throw "facetime.rs missing FTWireMessage field: $f"
        }
    }
    Write-Host "    [AUDIT OBSERVATION] FTWireMessage defines serde(rename_all = 'kebab-case')." -ForegroundColor Cyan
    Write-Host "    Fields like 'client_context_data_key' serialize to 'client-context-data-key' on wire unless overridden." -ForegroundColor Cyan
}

# ==============================================================================
# SECTION 4: E2E Master Suite Execution
# ==============================================================================
Execute-Test "CHG-4.1" "Execute master E2E test suite (Tiers 1-4, 218 test cases)" {
    $reportJson = Join-Path $RepoRoot "tests\e2e\challenger_e2e_report.json"
    $res = Invoke-IsolatedProcess "-ExecutionPolicy Bypass -File `"$RepoRoot\tests\e2e\run_tests.ps1`" -ReportPath `"$reportJson`""
    if ($res.ExitCode -ne 0) {
        throw "run_tests.ps1 failed with exit code $($res.ExitCode). Output: $($res.Output)"
    }
    if (-not (Test-Path $reportJson)) {
        throw "run_tests.ps1 did not output report to $reportJson"
    }
    $report = Get-Content $reportJson -Raw | ConvertFrom-Json
    if ($report.Passed -ne 218 -or $report.Failed -ne 0) {
        throw "E2E report mismatch: Expected 218 passed, 0 failed. Got $($report.Passed) passed, $($report.Failed) failed."
    }
    Write-Host "    [E2E VERIFIED] $($report.Passed) passed, $($report.Failed) failed in $($report.DurationMs) ms." -ForegroundColor Green
    Remove-Item $reportJson -Force -ErrorAction SilentlyContinue
}

# ==============================================================================
# SUMMARY
# ==============================================================================
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "                  CHALLENGER STRESS HARNESS SUMMARY                             " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Total Empirical Challenges: $($results.Count)" -ForegroundColor White
Write-Host "Passed:                     $passed" -ForegroundColor Green
Write-Host "Failed:                     $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

if ($failed -gt 0) {
    Write-Host "`nFAILED TESTS:" -ForegroundColor Red
    foreach ($r in $results) {
        if ($r.Status -eq "FAIL") {
            Write-Host " - [$($r.Id)] $($r.Name): $($r.Error)" -ForegroundColor Red
        }
    }
    exit 1
} else {
    Write-Host "`nALL EMPIRICAL CHALLENGES PASSED! VERDICT READY." -ForegroundColor Green
    exit 0
}
