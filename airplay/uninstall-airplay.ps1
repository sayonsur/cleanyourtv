param(
    [string]$TvHost = $(if ($env:TV_HOST) { $env:TV_HOST } else { "192.168.29.16" }),
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
$PKG = "io.github.jqssun.airplay"
$adbTarget = "${TvHost}:5555"

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "=== AirPlay Receiver Uninstaller / 1-Click Reversal             ===" -ForegroundColor Cyan
Write-Host "=== Target: $adbTarget | Package: $PKG                         ===" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

if (-not $Force) {
    Write-Host "Reversing AirPlay installation in 3 seconds (Ctrl+C to abort)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

# 1. Connect ADB
Write-Host "[1/5] Connecting to TV over ADB ($adbTarget)..." -ForegroundColor Yellow
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
    exit 1
}
Write-Host " Connected successfully." -ForegroundColor Green

# 2. Force-stop application
Write-Host "[2/5] Stopping AirPlay service and process..." -ForegroundColor Yellow
adb -s $adbTarget shell am force-stop $PKG 2>$null

# 3. Remove battery optimization whitelist and reset appops
Write-Host "[3/5] Cleaning up system permissions and Doze whitelist..." -ForegroundColor Yellow
adb -s $adbTarget shell dumpsys deviceidle whitelist -$PKG 2>$null
adb -s $adbTarget shell cmd appops reset $PKG 2>$null

# 4. Uninstall application package
Write-Host "[4/5] Uninstalling $PKG..." -ForegroundColor Yellow
$uninstallOut = (adb -s $adbTarget uninstall $PKG 2>&1)
Write-Host "       Result: $uninstallOut" -ForegroundColor DarkGray

# 5. Clean any temp files and return to Home
Write-Host "[5/5] Cleaning temporary artifacts and returning to Home..." -ForegroundColor Yellow
adb -s $adbTarget shell rm -f /data/local/tmp/airplay*.apk 2>$null
adb -s $adbTarget shell input keyevent KEYCODE_HOME 2>$null

# Verification
$check = (adb -s $adbTarget shell pm list packages $PKG 2>$null)
if ($check -match [regex]::Escape($PKG)) {
    Write-Host "[WARNING] Package $PKG is still detected on TV." -ForegroundColor Yellow
} else {
    Write-Host "====================================================================" -ForegroundColor Green
    Write-Host "REVERSAL COMPLETE: AirPlay Receiver has been cleanly removed." -ForegroundColor Green
    Write-Host "TV returned to original clean state with zero lingering services." -ForegroundColor Green
    Write-Host "====================================================================" -ForegroundColor Green
}
