# design_preview.ps1 — render a design scene to PNG (the /godot-design loop).
# Usage:
#   .\design_preview.ps1 -Scene godot\design\offer_card.tscn
#   .\design_preview.ps1 -Scene res://design/offer_card.tscn -Sizes 720x1280,1080x1920 -Cash 50000
# Output PNGs land in godot\design\shots\<scene>_<WxH>.png unless -Out is given.
# Set GODOT_BIN to override Godot path. Viewport readback needs a real window,
# so this opens (and closes) a Godot window per size — do not add --headless.
param(
    [Parameter(Mandatory = $true)][string]$Scene,
    [string]$Out = "",
    [string[]]$Sizes = @("720x1280"),
    [int]$Frames = 30,
    [double]$Cash = 0
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
if (-not $godot) {
    Write-Error "Godot not found. Set GODOT_BIN or install Godot 4.6.3."
    exit 1
}

# Normalize scene path to res:// relative to the godot/ project.
$res = $Scene.Replace("\", "/")
if (-not $res.StartsWith("res://")) {
    if ($res.StartsWith("godot/")) { $res = $res.Substring(6) }
    $res = "res://" + $res.TrimStart("/")
}

New-Item -ItemType Directory -Force -Path $ShotsDir | Out-Null
$name = [IO.Path]::GetFileNameWithoutExtension($Scene)
$failed = $false

$stdoutLog = Join-Path $ShotsDir "_last_stdout.log"
$stderrLog = Join-Path $ShotsDir "_last_stderr.log"

foreach ($size in $Sizes) {
    $parts = $size.ToLower().Split("x")
    if ($parts.Count -ne 2) { Write-Error "Bad size '$size' (expected WxH e.g. 720x1280)"; exit 1 }
    $w = $parts[0]; $h = $parts[1]
    if ($Out -and $Sizes.Count -eq 1) { $png = $Out } else { $png = Join-Path $ShotsDir ("{0}_{1}.png" -f $name, $size) }
    $png = [IO.Path]::GetFullPath($png)
    # Godot's win64 exe is GUI-subsystem: PowerShell won't wait and LASTEXITCODE
    # is meaningless, so run it via Start-Process -Wait with redirected output.
    $godotArgs = @(
        "--path", ('"{0}"' -f $GodotProject),
        "-s", "res://scripts/tools/design_preview.gd", "--",
        "--scene", $res, "--out", ('"{0}"' -f $png.Replace("\", "/")),
        "--w", $w, "--h", $h, "--frames", $Frames, "--cash", $Cash
    )
    $p = Start-Process -FilePath $godot -ArgumentList $godotArgs -Wait -PassThru `
        -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog
    if ($p.ExitCode -ne 0 -or -not (Test-Path $png)) {
        Write-Host "FAILED: $size (exit $($p.ExitCode))" -ForegroundColor Red
        Get-Content $stdoutLog
        Get-Content $stderrLog
        $failed = $true
    } else {
        Write-Host "shot: $png" -ForegroundColor Green
    }
}
if ($failed) { exit 1 }
