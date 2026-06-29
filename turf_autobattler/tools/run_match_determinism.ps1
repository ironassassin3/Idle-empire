param(
    [string]$GodotExe = $env:GODOT_EXE
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

if (-not $GodotExe) {
    $GodotExe = "E:\Downloads\Godot_v4.6.3-stable_win64_console.exe"
}

if (-not (Test-Path $GodotExe)) {
    Write-Error "Godot not found at '$GodotExe'. Set GODOT_EXE or install Godot."
}

function Get-Fingerprint {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $GodotExe `
        --headless `
        --path $ProjectRoot `
        --main-scene res://tools/match_headless_main.tscn `
        -- `
        "--print-fingerprint" 2>&1 | Out-String
    $ErrorActionPreference = $prevEap
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Fingerprint run failed:`n$output"
    }
    if ($output -match 'MATCH_FINGERPRINT=(\d+)') {
        return $Matches[1]
    }
    Write-Error "Fingerprint not found in output:`n$output"
}

$fpA = Get-Fingerprint
$fpB = Get-Fingerprint
if ($fpA -ne $fpB) {
    Write-Error "Cross-process determinism FAIL: $fpA vs $fpB"
}
Write-Output "CrossProcessDeterminism OK fingerprint=$fpA"
