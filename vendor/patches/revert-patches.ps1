# vendor/patches/revert-patches.ps1
# Reverts all patches in reverse order to restore pristine upstream tree
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
    [array]::Reverse($patchFiles)
} else {
    $patchFiles = Get-ChildItem -Path $PatchesDir -Filter "*.patch" | Sort-Object Name -Descending | ForEach-Object { $_.FullName }
}

if ($patchFiles.Count -eq 0) {
    Write-Host "[INFO] No patches to revert." -ForegroundColor Yellow
    exit 0
}

Write-Host "Reverting $($patchFiles.Count) patch(es) in reverse order..." -ForegroundColor Cyan
foreach ($patch in $patchFiles) {
    $patchName = Split-Path -Leaf $patch
    Write-Host "Reverting $patchName..."
    git -C $VendorDir apply -R $patch
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to revert $patchName"
        exit 1
    }
    Write-Host "[REVERTED] $patchName" -ForegroundColor Green
}
Write-Host "All patches reverted successfully." -ForegroundColor Green
