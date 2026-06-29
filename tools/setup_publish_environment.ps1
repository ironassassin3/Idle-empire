# One-shot publish environment setup (Windows).
# Usage: .\tools\setup_publish_environment.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Godot export templates ===" -ForegroundColor Cyan
& (Join-Path $RepoRoot "tools\install_godot_templates.ps1")

Write-Host ""
Write-Host "=== Android SDK (cmdline) ===" -ForegroundColor Cyan
& (Join-Path $RepoRoot "tools\install_android_sdk.ps1")

Write-Host ""
Write-Host "=== Godot Android paths ===" -ForegroundColor Cyan
& (Join-Path $RepoRoot "tools\configure_godot_android.ps1")

Write-Host ""
Write-Host "=== Criminal Empire Android template ===" -ForegroundColor Cyan
& (Join-Path $RepoRoot "tools\install_android_build_template.ps1")

Write-Host ""
Write-Host "=== Turf Android template ===" -ForegroundColor Cyan
& (Join-Path $RepoRoot "turf_autobattler\tools\install_android_build_template.ps1")

Write-Host ""
Write-Host "=== Verification ===" -ForegroundColor Cyan
& (Join-Path $RepoRoot "device_pass.ps1") check
& (Join-Path $RepoRoot "turf_autobattler\tools\publish_pass.ps1") check

Write-Host ""
Write-Host "Run full gates: .\verify_ship.ps1" -ForegroundColor Green
Write-Host "Desktop Turf build: cd turf_autobattler; .\tools\publish_pass.ps1 export-win" -ForegroundColor Green
Write-Host "Android APK (when export validates): .\device_pass.ps1 export" -ForegroundColor Green
