param(
    [string]$TvHost = $(if ($env:TV_HOST) { $env:TV_HOST } else { "192.168.29.16" }),
    [string]$Name = "",
    [string]$Tag = "v0.0.36",
    [string]$ApkPath = "",
    [switch]$RequirePin,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$PKG = "io.github.jqssun.airplay"
$adbTarget = "${TvHost}:5555"

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "=== AirPlay Receiver Installer (CleanYourTV)                     ===" -ForegroundColor Cyan
Write-Host "=== Target: $adbTarget | Package: $PKG                         ===" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

# 1. Connect ADB
Write-Host "[1/6] Connecting to TV over ADB ($adbTarget)..." -ForegroundColor Yellow
$connected = $false
for ($i = 1; $i -le 3; $i++) {
    adb connect $adbTarget | Out-Null
    Start-Sleep -Seconds 1
    $devices = (adb devices) -join "`n"
    if ($devices -match [regex]::Escape($adbTarget) + "\s+device") {
        $connected = $true
        break
    }
}
if (-not $connected) {
    Write-Host "[ERROR] Could not connect to TV at $adbTarget." -ForegroundColor Red
    Write-Host "Check that the TV is powered on and Network Debugging is enabled." -ForegroundColor Red
    exit 1
}
Write-Host " Connected successfully." -ForegroundColor Green

# 2. Determine Receiver Name
if ([string]::IsNullOrWhiteSpace($Name)) {
    $devName = (adb -s $adbTarget shell settings get global device_name 2>$null)
    if ($devName) {
        $Name = $devName.Trim()
    }
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = "CleanYourTV AirPlay"
    }
}
Write-Host "[2/6] Receiver display name: '$Name'" -ForegroundColor Yellow

# 3. Obtain APK
$cacheDir = Join-Path $PSScriptRoot "cache"
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}

$resolvedApk = $ApkPath
if ([string]::IsNullOrWhiteSpace($resolvedApk)) {
    $resolvedApk = Join-Path $cacheDir "airplay-$Tag.apk"
    if ((-not (Test-Path $resolvedApk)) -or $Force) {
        $downloadUrl = "https://github.com/jqssun/android-airplay-server/releases/download/$Tag/app-release.apk"
        Write-Host "[3/6] Downloading AirPlay Server ($Tag) from GitHub..." -ForegroundColor Yellow
        Write-Host "       URL: $downloadUrl" -ForegroundColor DarkGray
        
        # Use curl.exe with follow-redirects
        & curl.exe -L --fail --show-error -o $resolvedApk $downloadUrl
        if ($LASTEXITCODE -ne 0 -or (-not (Test-Path $resolvedApk))) {
            Write-Host "[ERROR] Failed to download APK from $downloadUrl" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[3/6] Using cached APK: $resolvedApk" -ForegroundColor Green
    }
} else {
    if (-not (Test-Path $resolvedApk)) {
        Write-Host "[ERROR] Specified APK not found: $resolvedApk" -ForegroundColor Red
        exit 1
    }
    Write-Host "[3/6] Using custom APK: $resolvedApk" -ForegroundColor Green
}

$apkSizeMb = [math]::Round(((Get-Item $resolvedApk).Length / 1MB), 2)
Write-Host "       APK size: $apkSizeMb MB" -ForegroundColor DarkGray

# 4. Install APK
Write-Host "[4/6] Installing APK onto TV..." -ForegroundColor Yellow
$installOutput = (adb -s $adbTarget install -r $resolvedApk 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or ($installOutput -notmatch "Success")) {
    Write-Host "[ERROR] Installation failed:`n$installOutput" -ForegroundColor Red
    exit 1
}
Write-Host " Package $PKG installed successfully." -ForegroundColor Green

# 5. Configure settings and system permissions
Write-Host "[5/6] Applying AirPlay configuration & background permissions..." -ForegroundColor Yellow

# Configure receiver name
adb -s $adbTarget shell am broadcast -a io.github.jqssun.airplay.SET_SETTING -n io.github.jqssun.airplay/.SettingsReceiver --es key server_name --es value "`"$Name`"" | Out-Null

# Enable auto-start at boot
adb -s $adbTarget shell am broadcast -a io.github.jqssun.airplay.SET_SETTING -n io.github.jqssun.airplay/.SettingsReceiver --es key boot_auto_start --es value true | Out-Null

if ($RequirePin) {
    adb -s $adbTarget shell am broadcast -a io.github.jqssun.airplay.SET_SETTING -n io.github.jqssun.airplay/.SettingsReceiver --es key require_pin --es value true | Out-Null
    Write-Host "       PIN requirement enabled." -ForegroundColor DarkGray
}

# Exempt from battery optimization (Doze)
adb -s $adbTarget shell dumpsys deviceidle whitelist +$PKG | Out-Null

# Allow running in background
adb -s $adbTarget shell cmd appops set $PKG RUN_IN_BACKGROUND allow | Out-Null

# 6. Start service & return to Home
Write-Host "[6/6] Initializing background service and returning to Home..." -ForegroundColor Yellow
adb -s $adbTarget shell am start -n io.github.jqssun.airplay/.MainActivity | Out-Null
Start-Sleep -Seconds 1
adb -s $adbTarget shell input keyevent KEYCODE_HOME | Out-Null

Write-Host "====================================================================" -ForegroundColor Green
Write-Host "AirPlay Receiver Installed Successfully!" -ForegroundColor Green
Write-Host "Receiver Name: '$Name'" -ForegroundColor Green
Write-Host "On your iPhone, iPad, or Mac, open Control Center -> Screen Mirroring" -ForegroundColor Cyan
Write-Host "and select '$Name'." -ForegroundColor Cyan
Write-Host ""
Write-Host "To safely revert/uninstall anytime, run:" -ForegroundColor Yellow
Write-Host "  .\airplay\uninstall-airplay.ps1 -TvHost $TvHost" -ForegroundColor Yellow
Write-Host "====================================================================" -ForegroundColor Green
