# Point Godot editor at local JDK + Android SDK for headless export.
# Usage: .\tools\configure_godot_android.ps1

$ErrorActionPreference = "Stop"
$GodotConfigDir = Join-Path $env:APPDATA "Godot"
$SettingsPath = Join-Path $GodotConfigDir "editor_settings-4.6.tres"

function Find-JdkHome {
    $candidates = @(
        (Get-ChildItem "C:\Program Files\Microsoft\jdk-*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1),
        (Get-ChildItem "C:\Program Files\Eclipse Adoptium\jdk-17*" -ErrorAction SilentlyContinue | Select-Object -First 1)
    ) | Where-Object { $_ -ne $null }
    if ($candidates.Count -gt 0) { return $candidates[0].FullName.Replace("\", "/") }
    return $null
}

$jdk = Find-JdkHome
$sdk = (Join-Path $env:LOCALAPPDATA "Android\Sdk").Replace("\", "/")
if (-not $jdk) { throw "JDK 17 not found. Run winget install Microsoft.OpenJDK.17" }
if (-not (Test-Path ($sdk -replace "/", "\"))) { throw "Android SDK missing. Run .\tools\install_android_sdk.ps1" }

if (-not (Test-Path $SettingsPath)) { throw "Missing $SettingsPath - open Godot once to create editor settings" }

$content = Get-Content $SettingsPath -Raw
$content = $content -replace 'export/android/java_sdk_path = "[^"]*"', "export/android/java_sdk_path = `"$jdk`""
$content = $content -replace 'export/android/android_sdk_path = "[^"]*"', "export/android/android_sdk_path = `"$sdk`""
if ($content -notmatch 'export/android/java_sdk_path') {
    $content = $content.TrimEnd() + "`nexport/android/java_sdk_path = `"$jdk`"`n"
}
if ($content -notmatch 'export/android/android_sdk_path') {
    $content = $content.TrimEnd() + "`nexport/android/android_sdk_path = `"$sdk`"`n"
}
if ($content -notmatch 'export/android/force_system_user_tools') {
    $content = $content.TrimEnd() + "`nexport/android/force_system_user_tools = `"true`"`n"
}

[System.IO.File]::WriteAllText($SettingsPath, $content)
Write-Host "Updated Godot editor settings:" -ForegroundColor Green
Write-Host "  java_sdk_path = $jdk"
Write-Host "  android_sdk_path = $sdk"
