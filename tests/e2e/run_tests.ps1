# run_tests.ps1
# Master Opaque-Box E2E Test Suite Runner for FaceTime Android PoC
# Supports Tiers 1-4, Feature-level filtering, JSON reporting, and verbose tracing

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$Tier = 0,

    [Parameter(Mandatory=$false)]
    [int]$Feature = 0,

    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput,

    [Parameter(Mandatory=$false)]
    [string]$ReportPath = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Security

# 1. Load Test Harness & Mocks
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "       FaceTime Android PoC -- Opaque-Box E2E Test Suite Runner                 " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

. (Join-Path $scriptDir "harness/TestAssertions.ps1")
. (Join-Path $scriptDir "harness/MockAppleServers.ps1")
. (Join-Path $scriptDir "harness/KeystoreSimulator.ps1")
. (Join-Path $scriptDir "harness/DiagnosticAuditor.ps1")
. (Join-Path $scriptDir "harness/ProtocolWireCheckers.ps1")

# 2. Load Test Tiers
. (Join-Path $scriptDir "tier1_features.ps1")
. (Join-Path $scriptDir "tier2_boundary.ps1")
. (Join-Path $scriptDir "tier3_cross_feature.ps1")
. (Join-Path $scriptDir "tier4_real_world.ps1")

$allTests = [System.Collections.Generic.List[hashtable]]::new()
$allTests.AddRange($tier1Tests)
$allTests.AddRange($tier2Tests)
$allTests.AddRange($tier3Tests)
$allTests.AddRange($tier4Tests)

# 3. Filter Tests
$filteredTests = [System.Collections.Generic.List[hashtable]]::new()
foreach ($t in $allTests) {
    if ($Tier -gt 0 -and $t.Tier -ne $Tier) { continue }
    if ($Feature -gt 0 -and (-not $t.ContainsKey("Feature") -or $t.Feature -ne $Feature)) { continue }
    $filteredTests.Add($t)
}

if ($filteredTests.Count -eq 0) {
    Write-Host "No tests matched the requested filters (Tier: $Tier, Feature: $Feature)" -ForegroundColor Yellow
    exit 0
}

Write-Host "Target Configuration: Total tests queued: $($filteredTests.Count)" -ForegroundColor Gray
if ($Tier -gt 0) { Write-Host " - Filter: Tier $Tier" -ForegroundColor Gray }
if ($Feature -gt 0) { Write-Host " - Filter: Feature $Feature" -ForegroundColor Gray }
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

# 4. Execution Loop
$passed = 0
$failed = 0
$results = [System.Collections.Generic.List[hashtable]]::new()
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($t in $filteredTests) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $status = "PASS"
    $errorMsg = ""
    try {
        & $t.Action
        $passed++
        $sw.Stop()
        if ($VerboseOutput) {
            $ms = $sw.ElapsedMilliseconds
            Write-Host "[PASS] [$($t.Id)] $($t.Name) ($ms ms)" -ForegroundColor Green
        }
    } catch {
        $failed++
        $sw.Stop()
        $status = "FAIL"
        $errorMsg = $_.Exception.Message
        $ms = $sw.ElapsedMilliseconds
        Write-Host "[FAIL] [$($t.Id)] $($t.Name) ($ms ms)" -ForegroundColor Red
        Write-Host "       Error: $errorMsg" -ForegroundColor DarkRed
    }

    $results.Add(@{
        "Id" = $t.Id;
        "Tier" = $t.Tier;
        "Feature" = if ($t.ContainsKey("Feature")) { $t.Feature } else { $null };
        "Name" = $t.Name;
        "Status" = $status;
        "DurationMs" = $sw.ElapsedMilliseconds;
        "Error" = $errorMsg;
    })
}

$stopwatch.Stop()

# 5. Output Summary
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                          E2E EXECUTION SUMMARY                                 " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Total Tests:    $($filteredTests.Count)" -ForegroundColor White
Write-Host "Passed:         $passed" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "Failed:         $failed" -ForegroundColor Red
} else {
    Write-Host "Failed:         0" -ForegroundColor Green
}
Write-Host "Execution Time: $($stopwatch.ElapsedMilliseconds) ms" -ForegroundColor Gray

# Tier Breakdown
$t1Count = ($results | Where-Object { $_.Tier -eq 1 -and $_.Status -eq 'PASS' }).Count
$t2Count = ($results | Where-Object { $_.Tier -eq 2 -and $_.Status -eq 'PASS' }).Count
$t3Count = ($results | Where-Object { $_.Tier -eq 3 -and $_.Status -eq 'PASS' }).Count
$t4Count = ($results | Where-Object { $_.Tier -eq 4 -and $_.Status -eq 'PASS' }).Count

$c1 = if ($t1Count -eq $tier1Tests.Count) { "Green" } else { "Yellow" }
$c2 = if ($t2Count -eq $tier2Tests.Count) { "Green" } else { "Yellow" }
$c3 = if ($t3Count -eq $tier3Tests.Count) { "Green" } else { "Yellow" }
$c4 = if ($t4Count -eq $tier4Tests.Count) { "Green" } else { "Yellow" }

Write-Host "Breakdown by Tier:" -ForegroundColor Gray
Write-Host " - Tier 1 (Feature Coverage):            $t1Count / $($tier1Tests.Count) passed" -ForegroundColor $c1
Write-Host " - Tier 2 (Boundary and Corner Cases):   $t2Count / $($tier2Tests.Count) passed" -ForegroundColor $c2
Write-Host " - Tier 3 (Cross-Feature Interactions):  $t3Count / $($tier3Tests.Count) passed" -ForegroundColor $c3
Write-Host " - Tier 4 (Real-World Scenarios):        $t4Count / $($tier4Tests.Count) passed" -ForegroundColor $c4

# 6. Generate JSON Report if requested
if (-not [string]::IsNullOrEmpty($ReportPath)) {
    $reportObj = @{
        "Suite" = "FaceTime Android PoC E2E Suite";
        "Timestamp" = (Get-Date -Format 'o');
        "Total" = $filteredTests.Count;
        "Passed" = $passed;
        "Failed" = $failed;
        "DurationMs" = $stopwatch.ElapsedMilliseconds;
        "Results" = $results;
    }
    $json = $reportObj | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($ReportPath, $json)
    Write-Host "Report saved to: $ReportPath" -ForegroundColor Cyan
}

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
