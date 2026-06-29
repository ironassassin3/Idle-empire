# Install Android Gradle template using Godot's expected nested layout.
# Usage: .\tools\install_android_build_template.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$OuterRoot = Join-Path $RepoRoot "godot\android\build"
$InnerRoot = Join-Path $OuterRoot "build"
$Marker = Join-Path $OuterRoot ".build_version"
$SourceZip = Join-Path $env:APPDATA "Godot\export_templates\4.6.3.stable\android_source.zip"

if (-not (Test-Path $SourceZip)) { throw "Missing android_source.zip - run tools/install_godot_templates.ps1" }

if (Test-Path $OuterRoot) { Remove-Item -Recurse -Force $OuterRoot }
New-Item -ItemType Directory -Force -Path $InnerRoot | Out-Null
Expand-Archive -Path $SourceZip -DestinationPath $InnerRoot -Force

$instrumented = Join-Path $InnerRoot "src\instrumented"
if (Test-Path $instrumented) { Remove-Item -Recurse -Force $instrumented }

"4.6.3.stable" | Set-Content -Encoding ASCII -NoNewline $Marker

if (-not (Test-Path (Join-Path $InnerRoot "gradlew.bat"))) {
    throw "Gradle wrapper missing after template install"
}
Write-Host "Android build template ready at $OuterRoot" -ForegroundColor Green
