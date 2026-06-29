# Flatten Godot's nested android/build/build template layout for CLI export.
# Usage: .\tools\fix_android_build_template.ps1

$ErrorActionPreference = "Stop"
$Root = Join-Path (Split-Path -Parent $PSScriptRoot) "godot\android\build"
$Nested = Join-Path $Root "build"

if (-not (Test-Path $Nested)) {
    Write-Host "No nested build folder — template already flat or missing." -ForegroundColor Yellow
    exit 0
}

Get-ChildItem $Nested -Force | ForEach-Object {
    $dest = Join-Path $Root $_.Name
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Move-Item -Force $_.FullName $dest
}
Remove-Item -Recurse -Force $Nested

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    throw "Flatten failed — gradlew.bat missing at $Root"
}
Write-Host "Flattened Android build template at $Root" -ForegroundColor Green
