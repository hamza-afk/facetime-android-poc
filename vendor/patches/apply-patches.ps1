# vendor/patches/apply-patches.ps1
# Applies all patches in vendor/patches/ to vendor/rustpush/
param(
    [switch]$CheckOnly
)
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$VendorDir = Join-Path $RepoRoot "vendor\rustpush"
$PatchesDir = $ScriptDir
$SeriesFile = Join-Path $PatchesDir "series"

if (-not (Test-Path $VendorDir)) {
    Write-Error "Vendor directory not found at $VendorDir"
    exit 1
}

$patchFiles = @()
if (Test-Path $SeriesFile) {
    Get-Content $SeriesFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $patchFiles += (Join-Path $PatchesDir $line)
        }
    }
} else {
    $patchFiles = Get-ChildItem -Path $PatchesDir -Filter "*.patch" | Sort-Object Name | ForEach-Object { $_.FullName }
}

if ($patchFiles.Count -eq 0) {
    Write-Host "[INFO] No patches found in $PatchesDir. Vendor tree remains pristine." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($patchFiles.Count) patch(es) to process." -ForegroundColor Cyan
foreach ($patch in $patchFiles) {
    $patchName = Split-Path -Leaf $patch
    if (-not (Test-Path $patch)) {
        Write-Error "Patch file missing: $patchName"
        exit 1
    }
    
    if ($CheckOnly) {
        Write-Host "Checking patch $patchName..."
        git -C $VendorDir apply --check $patch
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Dry run failed for $patchName"
            exit 1
        }
        Write-Host "[PASS] Dry run passed: $patchName" -ForegroundColor Green
    } else {
        Write-Host "Applying patch $patchName..."
        git -C $VendorDir apply $patch
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to apply $patchName"
            exit 1
        }
        Write-Host "[APPLIED] $patchName" -ForegroundColor Green
    }
}
Write-Host "All patches processed successfully." -ForegroundColor Green
