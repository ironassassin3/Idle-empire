# Install Android Gradle template for turf_autobattler.
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OuterRoot = Join-Path $ProjectRoot "android\build"
$InnerRoot = Join-Path $OuterRoot "build"
$SourceZip = Join-Path $env:APPDATA "Godot\export_templates\4.6.3.stable\android_source.zip"
if (-not (Test-Path $SourceZip)) { throw "Missing android_source.zip" }
if (Test-Path $OuterRoot) { Remove-Item -Recurse -Force $OuterRoot }
New-Item -ItemType Directory -Force -Path $InnerRoot | Out-Null
Expand-Archive -Path $SourceZip -DestinationPath $InnerRoot -Force
$instrumented = Join-Path $InnerRoot "src\instrumented"
if (Test-Path $instrumented) { Remove-Item -Recurse -Force $instrumented }
"4.6.3.stable" | Set-Content -Encoding ASCII -NoNewline (Join-Path $OuterRoot ".build_version")
Write-Host "Turf Android template at $OuterRoot" -ForegroundColor Green
