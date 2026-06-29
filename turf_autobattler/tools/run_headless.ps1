param(
    [int]$Seed = 12345,
    [int]$Iterations = 100,
    [string]$GodotExe = $env:GODOT_EXE
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

if (-not $GodotExe) {
    $GodotExe = "E:\Downloads\Godot_v4.6.3-stable_win64_console.exe"
}

if (-not (Test-Path $GodotExe)) {
    Write-Error "Godot not found at '$GodotExe'. Set GODOT_EXE or install export templates."
}

& $GodotExe `
    --headless `
    --path $ProjectRoot `
    --main-scene res://tools/headless_main.tscn `
    -- `
    "--seed=$Seed" `
    "--iterations=$Iterations"

if ($null -eq $LASTEXITCODE) {
    if (-not $?) { exit 1 }
} elseif ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
