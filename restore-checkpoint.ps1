param(
    [string]$TvHost = "192.168.29.16",
    [string]$CheckpointDir = "backup\checkpoint-mitv-axfr1",
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
$env:TV_HOST = $TvHost
$checkpointPath = Join-Path $PSScriptRoot $CheckpointDir
$adbTarget = "${TvHost}:5555"

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "=== Restoring TV to Checkpoint State ($TvHost) ===" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

if (-not (Test-Path $checkpointPath)) {
    Write-Host "[ERROR] Checkpoint directory not found at: $checkpointPath" -ForegroundColor Red
    exit 1
}

if (-not $Force) {
    Write-Host "Restoring checkpoint from $checkpointPath in 3 seconds (Ctrl+C to abort)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

adb connect $adbTarget | Out-Null
$devList = (adb devices) -join "`n"
if ($devList -notmatch "${TvHost}:5555\s+device") {
    Write-Host "[ERROR] Could not connect to TV at $adbTarget." -ForegroundColor Red
    exit 1
}

# 1. Re-install checkpointed APK if present
$savedApk = Join-Path $checkpointPath "installed-tvhome.apk"
if (Test-Path $savedApk) {
    Write-Host "1. Restoring checkpointed launcher APK..." -ForegroundColor Cyan
    adb -s $adbTarget install -r -d $savedApk
}

# 2. Re-apply debloat packages
$debloatFile = Join-Path $checkpointPath "disabled-packages.txt"
if (Test-Path $debloatFile) {
    Write-Host "2. Re-applying debloat package states..." -ForegroundColor Cyan
    Get-Content $debloatFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -match "package:(.+)") {
            $pkg = $matches[1].Trim()
            adb -s $adbTarget shell pm disable-user --user 0 $pkg 2>$null
        }
    }
} else {
    Write-Host "2. Disabling standard 16 bloatware packages..." -ForegroundColor Cyan
    $packages = @(
        "com.miui.tv.analytics", "com.xiaomi.statistic", "com.google.android.feedback",
        "com.mitv.tvhome.atv", "com.xm.webcontent", "com.google.android.tvrecommendations",
        "android.autoinstalls.config.xioami.dangal", "com.mitv.tvhome.mitvplus",
        "com.xiaomi.mitv.tvmanager", "com.xiaomi.mitv.handbook", "com.xiaomo.tv.milegal",
        "com.xiaomi.mimusic2", "com.google.android.play.games", "com.google.android.videos",
        "com.mitv.dream", "com.google.android.tvlauncher"
    )
    foreach ($pkg in $packages) {
        adb -s $adbTarget shell pm disable-user --user 0 $pkg 2>$null
    }
}

# 3. Set default home to com.gathin.tvhome
Write-Host "3. Setting CleanYourTV as default launcher..." -ForegroundColor Cyan
adb -s $adbTarget shell cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity

# 4. Enable accessibility service for ARC volume overlay
Write-Host "4. Enabling HomeKeyService accessibility service..." -ForegroundColor Cyan
adb -s $adbTarget shell settings put secure enabled_accessibility_services com.gathin.tvhome/.HomeKeyService
adb -s $adbTarget shell settings put secure accessibility_enabled 1

# 5. Restore private DNS
Write-Host "5. Restoring AdGuard Private DNS..." -ForegroundColor Cyan
adb -s $adbTarget shell settings put global private_dns_mode hostname
adb -s $adbTarget shell settings put global private_dns_specifier dns.adguard-dns.com

# 6. Restore theme config if present
$themeConfig = Join-Path $checkpointPath "theme-config.json"
if (Test-Path $themeConfig) {
    Write-Host "6. Restoring theme config..." -ForegroundColor Cyan
    adb -s $adbTarget push $themeConfig /data/local/tmp/cyt-theme.json
    adb -s $adbTarget shell "content write --uri content://com.gathin.tvhome.theme/config.json < /data/local/tmp/cyt-theme.json 2>/dev/null; rm -f /data/local/tmp/cyt-theme.json"
}

# 7. Restart home
Write-Host "7. Restarting CleanYourTV Home..." -ForegroundColor Cyan
adb -s $adbTarget shell am force-stop com.gathin.tvhome
adb -s $adbTarget shell am start -a android.intent.action.MAIN -c android.intent.category.HOME -n com.gathin.tvhome/.MainActivity

Write-Host "====================================================================" -ForegroundColor Green
Write-Host "RESTORE COMPLETE! TV state restored to checkpoint." -ForegroundColor Green
Write-Host "====================================================================" -ForegroundColor Green
