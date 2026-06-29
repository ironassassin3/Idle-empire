# Criminal Empire + Turf Autobattler — automated ship verification gates.
# Usage: .\verify_ship.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Push-Location $RepoRoot
try {
    Write-Host "=== Criminal Empire smoke ===" -ForegroundColor Cyan
    & (Join-Path $RepoRoot "device_pass.ps1") smoke

    Write-Host ""
    Write-Host "=== Python sim branch validation ===" -ForegroundColor Cyan
    python sim_branch_validation.py
    if ($LASTEXITCODE -ne 0) { throw "sim_branch_validation failed" }

    Write-Host ""
    Write-Host "=== Turf Autobattler smoke ===" -ForegroundColor Cyan
    & (Join-Path $RepoRoot "turf_autobattler\tools\publish_pass.ps1") smoke

    Write-Host ""
    Write-Host "VERIFY_SHIP PASS" -ForegroundColor Green
} finally {
    Pop-Location
}
