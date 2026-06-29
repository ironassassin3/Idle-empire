# Turf Autobattler — publish readiness helper (headless gate + optional export).
# Usage:
#   .\tools\publish_pass.ps1 check
#   .\tools\publish_pass.ps1 smoke
#   .\tools\publish_pass.ps1 export-win
#   .\tools\publish_pass.ps1 export-android
#
# Set GODOT_BIN to override Godot path. Copy export_presets.cfg.example → export_presets.cfg first.

param(
    [Parameter(Position = 0)]
    [ValidateSet("check", "smoke", "export-win", "export-android")]
    [string]$Action = "check"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GodotVersion = "4.6.3.stable"

function Find-Godot {
    if ($env:GODOT_BIN -and (Test-Path $env:GODOT_BIN)) { return $env:GODOT_BIN }
    $candidates = @(
        "E:\Downloads\Godot_v4.6.3-stable_win64_console.exe",
        "E:\Downloads\Godot_v4.6.3-stable_win64.exe",
        "C:\Tools\Godot_4.6.3\Godot_v4.6.3-stable_win64.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Test-ExportTemplates {
    $tpl = Join-Path $env:APPDATA "Godot\export_templates\$GodotVersion\android_debug.apk"
    return Test-Path $tpl
}

function Test-ExportPresets {
    return Test-Path (Join-Path $ProjectRoot "export_presets.cfg")
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

function Show-Check {
    $godot = Find-Godot
    $rows = @(
        @{ Item = "Godot 4.6.3"; Ok = [bool]$godot; Detail = if ($godot) { $godot } else { "Set GODOT_BIN" } },
        @{ Item = "Export templates"; Ok = (Test-ExportTemplates); Detail = "$env:APPDATA\Godot\export_templates\$GodotVersion\" },
        @{ Item = "export_presets.cfg"; Ok = (Test-ExportPresets); Detail = "Copy from export_presets.cfg.example" },
        @{ Item = "Headless runner"; Ok = (Test-Path (Join-Path $ProjectRoot "tools\headless_main.tscn")); Detail = "tools/headless_main.tscn" }
    )
    Write-Host ""
    Write-Host "Turf Autobattler publish toolchain" -ForegroundColor Cyan
    Write-Host ""
    foreach ($r in $rows) {
        $mark = if ($r.Ok) { "[OK]" } else { "[--]" }
        $col = if ($r.Ok) { "Green" } else { "Yellow" }
        Write-Host $mark -ForegroundColor $col -NoNewline
        Write-Host " $($r.Item)"
        Write-Host "      $($r.Detail)"
    }
    Write-Host ""
    if (-not (Test-ExportPresets)) {
        Write-Host "Tip: Copy-Item export_presets.cfg.example export_presets.cfg" -ForegroundColor Yellow
    }
}

function Invoke-Smoke {
    $godot = Find-Godot
    if (-not $godot) { throw "Godot not found. Set GODOT_BIN." }
    Write-Host "Headless load..." -ForegroundColor Cyan
    $loadExit = Invoke-Godot $godot --headless --quit --path $ProjectRoot
    if ($loadExit -ne 0) { throw "Headless load failed (exit $loadExit)" }
    Write-Host "Golden replays + sim soak..." -ForegroundColor Cyan
    & (Join-Path $ProjectRoot "tools\run_headless.ps1") -Seed 12345 -Iterations 50 -GodotExe $godot
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "Headless runner failed" }
    Write-Host "Match determinism (8-bot + cross-process)..." -ForegroundColor Cyan
    $env:GODOT_EXE = $godot
    & (Join-Path $ProjectRoot "tools\run_match_determinism.ps1")
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "Match determinism failed" }
    Write-Host "Smoke PASS" -ForegroundColor Green
}

function Invoke-Export {
    param([string]$PresetName, [string]$OutPath, [string]$PresetsFile = "")
    $godot = Find-Godot
    if (-not $godot) { throw "Godot not found" }
    if (-not (Test-ExportTemplates)) { throw "Export templates missing - use Editor Manage Export Templates" }
    $presetsPath = Join-Path $ProjectRoot "export_presets.cfg"
    $backupPath = Join-Path $ProjectRoot "export_presets.cfg.bak"
    $swapped = $false
    if ($PresetsFile -ne "") {
        if (Test-Path $presetsPath) { Copy-Item -Force $presetsPath $backupPath }
        Copy-Item -Force $PresetsFile $presetsPath
        $swapped = $true
    } elseif (-not (Test-ExportPresets)) {
        Copy-Item (Join-Path $ProjectRoot "export_presets.cfg.example") $presetsPath
        Write-Host "Created export_presets.cfg from example." -ForegroundColor Yellow
    }
    $outDir = Split-Path $OutPath -Parent
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    Write-Host "Exporting $PresetName -> $OutPath" -ForegroundColor Cyan
    try {
        $exportExit = Invoke-Godot $godot --path $ProjectRoot --headless --export-debug $PresetName $OutPath
        if ($exportExit -ne 0) { throw "Export failed (exit $exportExit)" }
    } finally {
        if ($swapped) {
            if (Test-Path $backupPath) {
                Move-Item -Force $backupPath $presetsPath
            } else {
                Remove-Item -Force $presetsPath -ErrorAction SilentlyContinue
            }
        }
    }
    if (-not (Test-Path $OutPath)) { throw "Export artifact missing at $OutPath" }
    $mb = [math]::Round((Get-Item $OutPath).Length / 1MB, 1)
    Write-Host ("Artifact: {0} ({1} MB)" -f $OutPath, $mb) -ForegroundColor Green
}

Push-Location $ProjectRoot
try {
    switch ($Action) {
        "check" { Show-Check }
        "smoke" { Invoke-Smoke }
        "export-win" { Invoke-Export "Windows Desktop" (Join-Path $ProjectRoot "build\TurfAutobattler.exe") (Join-Path $ProjectRoot "tools\export_presets.windows.cfg") }
        "export-android" { Invoke-Export "Android" (Join-Path $ProjectRoot "build\TurfAutobattler.apk") (Join-Path $ProjectRoot "tools\export_presets.android.cfg") }
    }
} finally {
    Pop-Location
}
