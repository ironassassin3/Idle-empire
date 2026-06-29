# Download and install Godot 4.6.3 export templates (Windows).
# Usage: .\tools\install_godot_templates.ps1

$ErrorActionPreference = "Stop"
$GodotVersion = "4.6.3.stable"
$TplDir = Join-Path $env:APPDATA "Godot\export_templates\$GodotVersion"
$Marker = Join-Path $TplDir "android_debug.apk"

if (Test-Path $Marker) {
    Write-Host "Export templates already installed at $TplDir" -ForegroundColor Green
    exit 0
}

$Url = "https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz"
$Tpz = Join-Path $env:TEMP "Godot_v4.6.3-stable_export_templates.tpz"
$Zip = Join-Path $env:TEMP "Godot_v4.6.3-stable_export_templates.zip"
$ExtractRoot = Join-Path $env:TEMP "Godot_v4.6.3-stable_export_templates"

New-Item -ItemType Directory -Force -Path $TplDir | Out-Null

if (-not (Test-Path $Tpz) -or (Get-Item $Tpz).Length -lt 900MB) {
    Write-Host "Downloading export templates (~1 GB)..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $Url -OutFile $Tpz
}

Copy-Item -Force $Tpz $Zip
if (Test-Path $ExtractRoot) { Remove-Item -Recurse -Force $ExtractRoot }
Expand-Archive -Path $Zip -DestinationPath $ExtractRoot -Force

$inner = Get-ChildItem $ExtractRoot -Directory | Select-Object -First 1
if ($null -eq $inner) { throw "Unexpected template archive layout" }
Copy-Item -Path (Join-Path $inner.FullName "*") -Destination $TplDir -Recurse -Force

if (-not (Test-Path $Marker)) { throw "Install failed: android_debug.apk missing" }
Write-Host "Installed export templates to $TplDir" -ForegroundColor Green
