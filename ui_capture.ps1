# ui_capture.ps1 — next-gen capture harness wrapper (SubViewport, batch, exact px).
# Single shot:
#   .\ui_capture.ps1 -Shell -Tab 0 -Size 1080x1920 -Cash 500 -Out shots\bldgs.png
#   .\ui_capture.ps1 -Scene godot\design\offer_card.tscn -Size 720x1280
# Batch (one engine launch for the whole matrix):
#   .\ui_capture.ps1 -Spec capture_spec.json
# Spec = JSON array of jobs: {shell, scene, tab, w, h, out, frames, cash,
# city_tier, heat, districts, prestige_tokens, no_overlays}.
# Needs a real GPU window for readback — do not run over pure SSH/headless.
param(
    [string]$Spec = "",
    [switch]$Shell,
    [string]$Scene = "",
    [int]$Tab = 0,
    [string]$Size = "720x1280",
    [string]$Out = "",
    [int]$Frames = 60,
    [double]$Cash = 0,
    [switch]$NoOverlays,
    [switch]$DebugRects
)

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$GodotProject = Join-Path $RepoRoot "godot"
$ShotsDir = Join-Path $GodotProject "design\shots"

function Find-Godot {
    if ($env:GODOT_BIN -and (Test-Path $env:GODOT_BIN)) { return $env:GODOT_BIN }
    $candidates = @(
        "E:\Downloads\Godot_v4.6.3-stable_win64.exe",
        "C:\Tools\Godot_4.6.3\Godot_v4.6.3-stable_win64.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.6.3-stable_win64.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$godot = Find-Godot
if (-not $godot) { Write-Error "Godot not found. Set GODOT_BIN."; exit 1 }
New-Item -ItemType Directory -Force -Path $ShotsDir | Out-Null

$userArgs = @()
if ($Spec) {
    $specPath = [IO.Path]::GetFullPath($Spec).Replace("\", "/")
    if (-not (Test-Path $specPath)) { Write-Error "Spec not found: $specPath"; exit 1 }
    $userArgs = @("--spec", ('"{0}"' -f $specPath))
} else {
    if (-not $Shell -and -not $Scene) { Write-Error "Need -Shell, -Scene, or -Spec"; exit 1 }
    $parts = $Size.ToLower().Split("x")
    if ($parts.Count -ne 2) { Write-Error "Bad -Size '$Size' (expected WxH)"; exit 1 }
    if (-not $Out) { $Out = Join-Path $ShotsDir ("cap_{0}_{1}.png" -f $Tab, $Size) }
    $png = [IO.Path]::GetFullPath($Out).Replace("\", "/")
    if ($Shell) { $userArgs += "--shell" }
    if ($Scene) {
        $res = $Scene.Replace("\", "/")
        if (-not $res.StartsWith("res://")) {
            if ($res.StartsWith("godot/")) { $res = $res.Substring(6) }
            $res = "res://" + $res.TrimStart("/")
        }
        $userArgs += @("--scene", $res)
    }
    $userArgs += @("--tab", $Tab, "--w", $parts[0], "--h", $parts[1],
        "--out", ('"{0}"' -f $png), "--frames", $Frames)
    if ($Cash -gt 0) { $userArgs += @("--cash", $Cash) }
    if ($NoOverlays) { $userArgs += "--no-overlays" }
    if ($DebugRects) { $userArgs += "--debug-rects" }
}

$stdoutLog = Join-Path $ShotsDir "_cap_stdout.log"
$stderrLog = Join-Path $ShotsDir "_cap_stderr.log"
$godotArgs = @(
    "--path", ('"{0}"' -f $GodotProject),
    "--resolution", "320x240",
    "-s", "res://scripts/tools/ui_capture.gd", "--"
) + $userArgs
$p = Start-Process -FilePath $godot -ArgumentList $godotArgs -Wait -PassThru `
    -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog
Get-Content $stdoutLog | Where-Object { $_ -match '^\{' } | ForEach-Object {
    Write-Host $_ -ForegroundColor Green
}
if ($p.ExitCode -ne 0) {
    Write-Host "ui_capture FAILED (exit $($p.ExitCode))" -ForegroundColor Red
    Get-Content $stderrLog | Select-Object -First 20
    exit 1
}
