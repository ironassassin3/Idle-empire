# Criminal Empire — device pass toolchain + export helper (P7/P8/P15).
# Usage:
#   .\device_pass.ps1 check          # toolchain status (default)
#   .\device_pass.ps1 smoke          # headless load + 30s soak + income parity
#   .\device_pass.ps1 export         # debug APK (needs JDK + SDK + templates)
#   .\device_pass.ps1 install        # adb install build/criminal-empire-debug.apk
#   .\device_pass.ps1 run            # export + install + launch on connected device
#   .\device_pass.ps1 aab            # signed release AAB for Play Console submission
#   .\device_pass.ps1 log            # tail Godot/Android logcat for the app
#
# Two Android presets, because a device pass and a Play upload need different formats:
#   "Android Debug" -> APK  (installable via adb; what every action except `aab` uses)
#   "Android"       -> AAB  (Play Console only; adb cannot install a bundle)
# Godot hard-fails on a format/extension mismatch, so never point one at the other's path.
#
# Set GODOT_BIN to override Godot path. Manual gates: DEVICE_TEST_CHECKLIST.md (15-min pass).

param(
    [Parameter(Position = 0)]
    [ValidateSet("check", "smoke", "export", "install", "run", "aab", "log")]
    [string]$Action = "check"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$GodotProject = Join-Path $RepoRoot "godot"
$PresetsFile = Join-Path $GodotProject "export_presets.cfg"
$DebugPreset = "Android Debug"
$ReleasePreset = "Android"
$ApkPath = Join-Path $GodotProject "build\criminal-empire-debug.apk"
$AabPath = Join-Path $GodotProject "build\criminal-empire.aab"
$Package = "com.ironassassin.criminalempire"
$GodotVersion = "4.6.3.stable"

function Find-Godot {
    if ($env:GODOT_BIN -and (Test-Path $env:GODOT_BIN)) { return $env:GODOT_BIN }
    $candidates = @(
        "E:\Downloads\Godot_v4.6.3-stable_win64.exe",
        "C:\Tools\Godot_4.6.3\Godot_v4.6.3-stable_win64.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.6.3-stable_win64.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Find-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $sdkAdb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) { return $sdkAdb }
    return $null
}

function Find-Python {
    # The bare `python` command on Windows is often the broken Store alias, so
    # prefer the `py` launcher, then a real python on PATH, then known installs.
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) { return $py.Source }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python -and $python.Source -notlike "*WindowsApps*") { return $python.Source }
    foreach ($c in @(
        (Join-Path $env:LOCALAPPDATA "Python\pythoncore-3.14-64\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Python\bin\python.exe"))) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

# Godot rewrites export_presets.cfg (dropping comments) whenever the editor saves a
# preset, so the "keep both Android presets in sync" rule cannot live in that file --
# it lives here, as a check.
$PresetSyncKeys = @(
    "exclude_filter",
    "gradle_build/use_gradle_build",
    "gradle_build/min_sdk",
    "gradle_build/target_sdk",
    "architectures/arm64-v8a",
    "version/code",
    "version/name",
    "package/unique_name",
    "screen/immersive_mode",
    "permissions/access_network_state",
    "permissions/internet",
    "permissions/post_notifications",
    "permissions/vibrate"
)

function Get-Preset {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Test-Path $PresetsFile)) { return $null }
    $lines = Get-Content $PresetsFile
    $index = $null
    $current = $null
    foreach ($line in $lines) {
        if ($line -match '^\[preset\.(\d+)\]\s*$') { $current = $Matches[1]; continue }
        if ($line -match '^\[') { $current = $null; continue }
        if ($current -and $line -match '^name="(.*)"\s*$' -and $Matches[1] -eq $Name) { $index = $current }
    }
    if ($null -eq $index) { return $null }
    $vals = @{}
    $capture = $false
    foreach ($line in $lines) {
        if ($line -match '^\[') {
            $capture = ($line.Trim() -eq "[preset.$index]") -or ($line.Trim() -eq "[preset.$index.options]")
            continue
        }
        if ($capture -and $line -match '^([^=]+)=(.*)$') { $vals[$Matches[1].Trim()] = $Matches[2].Trim() }
    }
    return $vals
}

function Get-PresetDrift {
    $rel = Get-Preset $ReleasePreset
    $dbg = Get-Preset $DebugPreset
    if (-not $rel) { return @("preset '$ReleasePreset' missing from export_presets.cfg") }
    if (-not $dbg) { return @("preset '$DebugPreset' missing from export_presets.cfg") }
    $issues = @()
    if ($rel["gradle_build/export_format"] -ne "1") { $issues += "'$ReleasePreset' export_format must be 1 (AAB) for Play" }
    if ($dbg["gradle_build/export_format"] -ne "0") { $issues += "'$DebugPreset' export_format must be 0 (APK) for adb install" }
    foreach ($key in $PresetSyncKeys) {
        if ($rel[$key] -ne $dbg[$key]) { $issues += "$key drift: $ReleasePreset=$($rel[$key]) vs $DebugPreset=$($dbg[$key])" }
    }
    return $issues
}

function Test-ExportTemplates {
    $tpl = Join-Path $env:APPDATA "Godot\export_templates\$GodotVersion\android_debug.apk"
    return Test-Path $tpl
}

function Test-AndroidSdk {
    $sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
    return (Test-Path (Join-Path $sdk "platform-tools\adb.exe"))
}

function Test-Jdk {
    $jdkHome = Find-JdkHome
    if ($jdkHome) { return $true }
    $cmd = Get-Command java -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    $ver = & java -version 2>&1 | Out-String
    return $ver -match 'version "17'
}

function Find-JdkHome {
    $candidates = @(
        (Get-ChildItem "C:\Program Files\Microsoft\jdk-*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1),
        (Get-ChildItem "C:\Program Files\Eclipse Adoptium\jdk-17*" -ErrorAction SilentlyContinue | Select-Object -First 1)
    ) | Where-Object { $_ -ne $null }
    if ($candidates.Count -gt 0) { return $candidates[0].FullName }
    return $null
}

function Show-Check {
    $godot = Find-Godot
    $adb = Find-Adb
    $presetDrift = @(Get-PresetDrift)
    $rows = @(
        @{ Item = "Godot 4.6.3"; Ok = [bool]$godot; Detail = if ($godot) { $godot } else { "Set GODOT_BIN or install Godot" } },
        @{ Item = "Export templates"; Ok = (Test-ExportTemplates); Detail = "$env:APPDATA\Godot\export_templates\$GodotVersion\" },
        @{ Item = "JDK 17"; Ok = (Test-Jdk); Detail = "winget install Microsoft.OpenJDK.17" },
        @{ Item = "Android SDK"; Ok = (Test-AndroidSdk); Detail = "%LOCALAPPDATA%\Android\Sdk (Android Studio SDK Manager)" },
        @{ Item = "adb"; Ok = [bool]$adb; Detail = if ($adb) { $adb } else { "Install Platform-Tools via SDK Manager" } },
        @{ Item = "Android build template"; Ok = (Test-Path (Join-Path $GodotProject "android\build")); Detail = "Godot: Project -> Install Android Build Template" },
        @{ Item = "Export presets"; Ok = ($presetDrift.Count -eq 0); Detail = if ($presetDrift.Count -eq 0) { "'$DebugPreset' APK + '$ReleasePreset' AAB in sync" } else { $presetDrift -join "; " } }
    )

    Write-Host ""
    Write-Host "Device pass toolchain" -ForegroundColor Cyan
    Write-Host "Checklist: DEVICE_TEST_CHECKLIST.md"
    Write-Host ""
    foreach ($r in $rows) {
        $mark = if ($r.Ok) { "[OK]" } else { "[--]" }
        $col = if ($r.Ok) { "Green" } else { "Yellow" }
        Write-Host $mark -ForegroundColor $col -NoNewline
        Write-Host " $($r.Item)"
        Write-Host "      $($r.Detail)"
    }

    if ($adb) {
        Write-Host ""
        Write-Host "Connected devices:" -ForegroundColor Cyan
        & $adb devices
    }

    $ready = ($rows | Where-Object { $_.Item -in @("Godot 4.6.3", "Export templates", "JDK 17", "Android SDK", "Android build template", "Export presets") } | Where-Object { -not $_.Ok }).Count -eq 0
    Write-Host ""
    if ($ready) {
        Write-Host "Ready for: .\device_pass.ps1 export" -ForegroundColor Green
    } else {
        Write-Host "Next: complete [--] items above - see ANDROID_SETUP.md" -ForegroundColor Yellow
        Write-Host "Desktop-only (no phone): F5 in Godot + DEVICE_TEST_CHECKLIST.md section A" -ForegroundColor Yellow
    }
    if (-not $godot) { exit 1 }
}

function Invoke-Godot {
    param(
        [Parameter(Mandatory = $true)][string]$Godot,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args
    )
    & $Godot @Args 2>&1 | Out-Null
    if ($null -eq $LASTEXITCODE) {
        if ($?) { return 0 }
        return 1
    }
    return [int]$LASTEXITCODE
}

function Invoke-Smoke {
    $godot = Find-Godot
    if (-not $godot) { throw "Godot not found. Set GODOT_BIN." }
    Write-Host "Headless project load..." -ForegroundColor Cyan
    $loadExit = Invoke-Godot $godot --headless --quit --path $GodotProject
    if ($loadExit -ne 0) { throw "Godot headless load failed (exit $loadExit)" }
    # Sheet bounds: needs a real (offscreen) window - the layout does not settle
    # under --headless, so the check would silently pass there. Called directly
    # rather than through Invoke-Godot: that wrapper merges stderr, which in
    # PowerShell 5.1 swallows a native exe's run and its exit code.
    Write-Host "Sheet bounds (nav dock stays on screen)..." -ForegroundColor Cyan
    & $godot --path $GodotProject --resolution 320x240 --position 3000,3000 -s res://scripts/tools/deck_bounds_smoke.gd
    if ($LASTEXITCODE -ne 0) { throw "deck_bounds_smoke failed - the content sheet overflows the viewport" }
    Write-Host "Soak + income parity (30s)..." -ForegroundColor Cyan
    $python = Find-Python
    if (-not $python) { throw "Python not found (install the 'py' launcher or add python to PATH)." }
    Push-Location $RepoRoot
    try {
        & $python sim_godot_soak.py --godot $godot --seconds 30
        if ($LASTEXITCODE -ne 0) { throw "sim_godot_soak failed" }
    } finally {
        Pop-Location
    }
    Write-Host "Smoke PASS" -ForegroundColor Green
}

function Assert-AndroidToolchain {
    if (-not (Test-ExportTemplates)) { throw "Export templates missing - Editor -> Manage Export Templates" }
    if (-not (Test-Jdk)) { throw "JDK 17 missing - winget install Microsoft.OpenJDK.17" }
    if (-not (Test-AndroidSdk)) { throw "Android SDK missing - run .\tools\install_android_sdk.ps1" }
    if (-not (Test-Path (Join-Path $GodotProject "android\build\.build_version"))) {
        & (Join-Path $RepoRoot "tools\install_android_build_template.ps1")
    }
    $drift = Get-PresetDrift
    if ($drift) { throw ("Export preset problem:`n  - " + ($drift -join "`n  - ")) }
}

function Invoke-Export {
    $godot = Find-Godot
    if (-not $godot) { throw "Godot not found" }
    Assert-AndroidToolchain
    $outDir = Split-Path $ApkPath -Parent
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    Write-Host "Exporting debug APK ($DebugPreset preset)..." -ForegroundColor Cyan
    $exportExit = Invoke-Godot $godot --path $GodotProject --headless --export-debug $DebugPreset $ApkPath
    if ($exportExit -ne 0) { throw "Export failed (exit $exportExit)" }
    if (-not (Test-Path $ApkPath)) { throw "APK not found at $ApkPath" }
    $mb = [math]::Round((Get-Item $ApkPath).Length / 1MB, 1)
    Write-Host ("APK: {0} ({1} MB)" -f $ApkPath, $mb) -ForegroundColor Green
}

function Invoke-ExportAab {
    $godot = Find-Godot
    if (-not $godot) { throw "Godot not found" }
    Assert-AndroidToolchain
    $outDir = Split-Path $AabPath -Parent
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    Write-Host "Exporting release AAB ($ReleasePreset preset)..." -ForegroundColor Cyan
    $exportExit = Invoke-Godot $godot --path $GodotProject --headless --export-release $ReleasePreset $AabPath
    if ($exportExit -ne 0) { throw "Export failed (exit $exportExit) - release keystore configured? See ANDROID_SETUP.md" }
    if (-not (Test-Path $AabPath)) { throw "AAB not found at $AabPath" }
    $mb = [math]::Round((Get-Item $AabPath).Length / 1MB, 1)
    Write-Host ("AAB: {0} ({1} MB)" -f $AabPath, $mb) -ForegroundColor Green
    Write-Host "Play Console upload only - adb cannot install a bundle. Device pass uses .\device_pass.ps1 run." -ForegroundColor Cyan
}

function Invoke-Install {
    $adb = Find-Adb
    if (-not $adb) { throw "adb not found" }
    if (-not (Test-Path $ApkPath)) { throw "APK missing - run .\device_pass.ps1 export first" }
    $devices = (& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "device$" })
    if (-not $devices) { throw "No authorized device - enable USB debugging on Moto G" }
    Write-Host "Installing $ApkPath ..." -ForegroundColor Cyan
    & $adb install -r $ApkPath
    if ($LASTEXITCODE -ne 0) { throw "adb install failed" }
    Write-Host "Installed. Launch from app drawer or: adb shell monkey -p $Package 1" -ForegroundColor Green
}

function Invoke-Run {
    Invoke-Export
    Invoke-Install
    $adb = Find-Adb
    & $adb shell monkey -p $Package -c android.intent.category.LAUNCHER 1 | Out-Null
    Write-Host "Launched $Package on device." -ForegroundColor Green
    Write-Host "On device: Config -> Show FPS -> ON, then walk DEVICE_TEST_CHECKLIST.md section B." -ForegroundColor Cyan
}

function Invoke-Log {
    $adb = Find-Adb
    if (-not $adb) { throw "adb not found" }
    Write-Host "Logcat (Ctrl+C to stop). Launch the app on device first." -ForegroundColor Cyan
    & $adb logcat -c
    & $adb logcat -s godot:V Godot:V DEBUG:I AndroidRuntime:E
}

Push-Location $RepoRoot
try {
    switch ($Action) {
        "check" { Show-Check }
        "smoke" { Invoke-Smoke }
        "export" { Invoke-Export }
        "install" { Invoke-Install }
        "run" { Invoke-Run }
        "aab" { Invoke-ExportAab }
        "log" { Invoke-Log }
    }
} finally {
    Pop-Location
}
