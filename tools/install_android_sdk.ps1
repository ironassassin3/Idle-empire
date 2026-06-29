# Install Android SDK command-line tools (platform-tools + build-tools + platform 34).
# Usage: .\tools\install_android_sdk.ps1

$ErrorActionPreference = "Stop"
$SdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$CmdlineRoot = Join-Path $SdkRoot "cmdline-tools\latest"
$SdkManager = Join-Path $CmdlineRoot "bin\sdkmanager.bat"
$Marker = Join-Path $SdkRoot "platform-tools\adb.exe"

function Find-JdkHome {
    $candidates = @(
        (Get-ChildItem "C:\Program Files\Microsoft\jdk-*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1),
        (Get-ChildItem "C:\Program Files\Eclipse Adoptium\jdk-17*" -ErrorAction SilentlyContinue | Select-Object -First 1)
    ) | Where-Object { $_ -ne $null }
    if ($candidates.Count -gt 0) { return $candidates[0].FullName }
    return $null
}

$JdkHome = Find-JdkHome
if (-not $JdkHome) { throw "JDK 17 not found. Run: winget install Microsoft.OpenJDK.17" }
$env:JAVA_HOME = $JdkHome
$env:Path = "$JdkHome\bin;" + $env:Path

if (Test-Path $Marker) {
    Write-Host "Android SDK already installed at $SdkRoot" -ForegroundColor Green
    exit 0
}

New-Item -ItemType Directory -Force -Path $SdkRoot | Out-Null

if (-not (Test-Path $SdkManager)) {
    $ZipUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    $ZipPath = Join-Path $env:TEMP "commandlinetools-win.zip"
    $ExtractRoot = Join-Path $env:TEMP "android-cmdline-tools"

    Write-Host "Downloading Android command-line tools..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath

    if (Test-Path $ExtractRoot) { Remove-Item -Recurse -Force $ExtractRoot }
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractRoot -Force

    New-Item -ItemType Directory -Force -Path (Split-Path $CmdlineRoot -Parent) | Out-Null
    if (Test-Path $CmdlineRoot) { Remove-Item -Recurse -Force $CmdlineRoot -ErrorAction SilentlyContinue }
    Move-Item -Path (Join-Path $ExtractRoot "cmdline-tools") -Destination $CmdlineRoot
}

$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot
$packages = @(
    "platform-tools",
    "platforms;android-34",
    "build-tools;34.0.0"
)

Write-Host "Accepting Android SDK licenses..." -ForegroundColor Cyan
$yes = 1..40 | ForEach-Object { "y" }
$yes | & $SdkManager --sdk_root=$SdkRoot --licenses | Out-Null

Write-Host "Installing SDK packages (may take several minutes)..." -ForegroundColor Cyan
foreach ($pkg in $packages) {
    Write-Host "  -> $pkg"
    $yes | & $SdkManager --sdk_root=$SdkRoot $pkg | Out-Null
}

if (-not (Test-Path $Marker)) { throw "adb missing after SDK install" }
Write-Host "Android SDK ready at $SdkRoot" -ForegroundColor Green
