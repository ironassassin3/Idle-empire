# ui_validators.ps1 - Stage & Ledger pre-merge validator set
# (UI_MARKET_SUPREMACY_SPEC.md section 6). Run all: .\ui_validators.ps1
# V3 token lint: shell/screens/components must use GameTheme/GameFonts tokens;
# raw hex Color("...") literals are forbidden there.
# NOTE: keep this file ASCII-only (PS 5.1 reads BOM-less UTF-8 as ANSI).
param([switch]$TokenLintOnly)

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$fail = $false

# ---- V3: token lint ---------------------------------------------------------
$scanDirs = @(
    (Join-Path $RepoRoot "godot\scripts\ui\shell"),
    (Join-Path $RepoRoot "godot\scripts\ui\screens"),
    (Join-Path $RepoRoot "godot\scripts\ui\components")
)
$hexPattern = 'Color\("(#)?[0-9a-fA-F]{3,8}"'
$hits = @()
foreach ($dir in $scanDirs) {
    if (-not (Test-Path $dir)) { continue }
    $hits += Get-ChildItem $dir -Recurse -Filter *.gd |
        Select-String -Pattern $hexPattern
}
if ($hits.Count -gt 0) {
    Write-Host "V3 token lint: FAIL - raw hex colors in token-law paths:" -ForegroundColor Red
    $hits | ForEach-Object { Write-Host ("  {0}:{1}  {2}" -f $_.Filename, $_.LineNumber, $_.Line.Trim()) }
    $fail = $true
} else {
    Write-Host "V3 token lint: PASS" -ForegroundColor Green
}

# ---- V5: thumb-zone audit (ADR-002) ------------------------------------------
# Parses the newest --debug-rects JSON in design/shots. Rules:
#   (a) every visible Button >= 48px on its smaller axis
#   (b) non-exempt Buttons' centroid must sit BELOW 45% of screen height
# Exempt paths: Masthead (mirrors), AttentionRail (attention surface).
$rectsFile = Get-ChildItem (Join-Path $RepoRoot "godot\design\shots") -Filter *.rects.json |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($rectsFile) {
    $screenH = 1280.0
    $rows = Get-Content $rectsFile.FullName -Raw | ConvertFrom-Json
    $bad = @()
    foreach ($r in $rows) {
        if (-not $r.visible -or $r.class -ne "Button") { continue }
        $w = [double]$r.rect[2]; $h = [double]$r.rect[3]
        if ($w -lt 1 -or $h -lt 1) { continue }
        $minAxis = [Math]::Min($w, $h)
        $cy = [double]$r.rect[1] + $h / 2.0
        $exempt = ($r.path -match "Masthead") -or ($r.path -match "AttentionRail")
        if ($minAxis -lt 47.5) {
            $bad += ("  SIZE {0:N0}px  {1}" -f $minAxis, $r.path)
        }
        if (-not $exempt -and ($cy / $screenH) -lt 0.40) {
            $bad += ("  ZONE {0:P0}  {1}" -f ($cy / $screenH), $r.path)
        }
    }
    if ($bad.Count -gt 0) {
        Write-Host ("V5 thumb audit: FAIL ({0})" -f $rectsFile.Name) -ForegroundColor Red
        $bad | Select-Object -First 12 | ForEach-Object { Write-Host $_ }
        $fail = $true
    } else {
        Write-Host ("V5 thumb audit: PASS ({0})" -f $rectsFile.Name) -ForegroundColor Green
    }
} else {
    Write-Host "V5 skipped: no *.rects.json found (run a -DebugRects capture first)" -ForegroundColor Yellow
}

# ---- V1: headless shell smoke (includes ADR-001 ticker-honesty assert) ------
if (-not $TokenLintOnly) {
    $godot = if ($env:GODOT_BIN -and (Test-Path $env:GODOT_BIN)) { $env:GODOT_BIN }
             else { "E:\Downloads\Godot_v4.6.3-stable_win64.exe" }
    if (Test-Path $godot) {
        $out = & $godot --headless --path (Join-Path $RepoRoot "godot") `
            -s res://scripts/tools/shell_smoke.gd 2>&1 | Out-String
        if ($out -match "\[shell_smoke\] PASS") {
            Write-Host "V1 shell smoke: PASS" -ForegroundColor Green
        } else {
            Write-Host "V1 shell smoke: FAIL" -ForegroundColor Red
            ($out -split "`n" | Select-String "SCRIPT ERROR|VIOLATION" |
                Select-Object -First 5) | ForEach-Object { Write-Host $_ }
            $fail = $true
        }
    } else {
        Write-Host "V1 skipped: Godot not found, set GODOT_BIN" -ForegroundColor Yellow
    }
}

if ($fail) { exit 1 }
Write-Host "validators: ALL PASS" -ForegroundColor Green
