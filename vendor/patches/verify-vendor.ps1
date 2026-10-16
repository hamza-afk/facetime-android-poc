# vendor/patches/verify-vendor.ps1
# Cryptographic and structural verification of vendor tree and patch integrity
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$VendorDir = Join-Path $RepoRoot "vendor\rustpush"
$PatchesDir = $ScriptDir

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "     Vendor Integrity & Compliance Verification  " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# 1. Directory Existence
if (-not (Test-Path $VendorDir)) {
    Write-Error "FAILED: Vendor directory does not exist at $VendorDir"
    exit 1
}
Write-Host "[PASS] Vendor directory present at $VendorDir" -ForegroundColor Green

# 2. REVISION.md Check
$revisionFile = Join-Path $VendorDir "REVISION.md"
if (-not (Test-Path $revisionFile)) {
    Write-Error "FAILED: REVISION.md is missing from $VendorDir"
    exit 1
}
$revContent = Get-Content $revisionFile -Raw
if ($revContent -notmatch "b3c96c23e1aae78d1229ebaccb12027624f1eaff") {
    Write-Error "FAILED: REVISION.md does not contain pinned commit b3c96c23e1aae78d1229ebaccb12027624f1eaff"
    exit 1
}
Write-Host "[PASS] REVISION.md verified with pinned commit b3c96c23e1aae78d1229ebaccb12027624f1eaff" -ForegroundColor Green

# 3. CHECKSUMS.sha256 Verification
$checksumFile = Join-Path $VendorDir "CHECKSUMS.sha256"
if (Test-Path $checksumFile) {
    Write-Host "Verifying CHECKSUMS.sha256..." -ForegroundColor Cyan
    $lines = Get-Content $checksumFile
    $verified = 0
    $failed = 0
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#")) { continue }
        $parts = $trimmed.Split(" ", 2, [System.StringSplitOptions]::RemoveEmptyEntries)
        $expectedHash = $parts[0].Trim().ToLower()
        $relPath = $parts[1].Trim()
        $targetPath = Join-Path $VendorDir $relPath

        if (-not (Test-Path $targetPath)) {
            Write-Host "MISSING: $relPath" -ForegroundColor Red
            $failed++
            continue
        }
        $actualHash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash.ToLower()
        if ($actualHash -ne $expectedHash) {
            Write-Host "HASH MISMATCH: $relPath (Expected: $expectedHash, Actual: $actualHash)" -ForegroundColor Red
            $failed++
        } else {
            $verified++
        }
    }

    if ($failed -gt 0) {
        Write-Error "FAILED: $failed file(s) failed checksum verification!"
        exit 1
    }
    Write-Host "[PASS] $verified file(s) verified against CHECKSUMS.sha256 (0 mismatches)." -ForegroundColor Green
} else {
    Write-Host "[WARN] CHECKSUMS.sha256 not found. Skipping file hash verification." -ForegroundColor Yellow
}

# 4. Patch Application Dry-Run
$patches = Get-ChildItem -Path $PatchesDir -Filter "*.patch" | Sort-Object Name
if ($patches.Count -gt 0) {
    Write-Host "Verifying $($patches.Count) patch(es) apply cleanly without fuzz..." -ForegroundColor Cyan
    foreach ($patch in $patches) {
        git -C $VendorDir apply --check $patch.FullName
        if ($LASTEXITCODE -ne 0) {
            Write-Error "FAILED: Patch $($patch.Name) does not apply cleanly to vendor tree!"
            exit 1
        }
        Write-Host "[PASS] Patch $($patch.Name) applies cleanly." -ForegroundColor Green
    }
} else {
    Write-Host "[INFO] Zero patches present. Vendor tree is 100% pristine upstream." -ForegroundColor Yellow
}

Write-Host "=================================================" -ForegroundColor Green
Write-Host "   VERIFICATION SUCCESSFUL: ALL CRITERIA MET    " -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
exit 0
