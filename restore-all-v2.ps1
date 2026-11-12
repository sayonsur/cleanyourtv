param(
    [string]$TvHost = "192.168.29.16",
    [switch]$SportsOnly,
    [switch]$EnableSports,
    [switch]$Full,
    [switch]$CloseAdb,
    [switch]$Force,
    [switch]$Help
)

# CleanYourTV Single-Click Reversal Script v2
# Allows 1-click total reversal to factory bloated Android TV OR independent toggling of Sports Recommendations.
#
# Usage:
#   .\restore-all-v2.ps1                                     # 1-Click Full factory rollback (re-enables 16 bloatware packages & restores stock Google TV launcher)
#   .\restore-all-v2.ps1 -SportsOnly                         # Reverts ONLY the Sports recommendation feature (hides trophy icon, stops network feed)
#   .\restore-all-v2.ps1 -EnableSports                       # Re-enables the Sports recommendation feature
#   .\restore-all-v2.ps1 -CloseAdb                           # Disables ADB service on TV for security shutdown
#   .\restore-all-v2.ps1 -TvHost <IP>                        # Target a different TV IP (default: 192.168.29.16)

$ErrorActionPreference = 'Continue'
$env:TV_HOST = $TvHost
$py = Join-Path $PSScriptRoot "tools\venv\Scripts\python.exe"
$tvPy = Join-Path $PSScriptRoot "tools\tv.py"

function Run-Tv([string]$Cmd) {
    if (Test-Path $py) {
        & $py -I $tvPy $Cmd
    } else {
        adb -s "$TvHost:5555" shell "$Cmd"
    }
}

if ($Help) {
    Write-Host @"
====================================================================
           CleanYourTV Single-Click Reversal Script v2
====================================================================
USAGE:
  .\restore-all-v2.ps1 [-TvHost <IP>] [OPTIONS]

OPTIONS:
  (no flags)     1-Click Full Factory Rollback
                 Re-enables all 16 disabled Xiaomi/Google packages,
                 restores stock Google TV Launcher, resets accessibility,
                 and sets Private DNS back to opportunistic.
  
  -SportsOnly    Disable Sports Recommendations only
                 Hides trophy icon, zeroes out sports network polling,
                 and keeps the clean Apple TV launcher and volume overlay.
  
  -EnableSports  Re-enable Sports Recommendations
                 Restores live & upcoming sports feed on the top bar.

  -CloseAdb      Security Shutdown
                 Stops the adbd service on the TV to protect port 5555.

  -TvHost <IP>   Specify TV IP address (defaults to 192.168.29.16).
  -Force         Skip countdown and proceed immediately with rollback.
  -Help          Show this help message.
====================================================================
"@ -ForegroundColor Cyan
    exit 0
}

Write-Host "Connecting to TV at $TvHost..."

if ($CloseAdb) {
    Write-Host "=== Performing Security Shutdown (Closing ADB) ===" -ForegroundColor Cyan
    Run-Tv "settings put global adb_enabled 0"
    Run-Tv "setprop service.adb.tcp.port -1"
    Run-Tv "stop adbd 2>/dev/null"
    Write-Host "Done! ADB daemon stopped. Complete the shutdown on the TV:" -ForegroundColor Green
    Write-Host "  1. On TV: Settings -> Device Preferences -> Developer options" -ForegroundColor Yellow
    Write-Host "  2. Select 'Revoke USB debugging authorizations'" -ForegroundColor Yellow
    Write-Host "  3. Toggle 'USB debugging' to OFF" -ForegroundColor Yellow
    Write-Host "  4. Reboot the TV" -ForegroundColor Yellow
    exit 0
}

if ($EnableSports) {
    Write-Host "=== Enabling Sports Recommendation Feature ===" -ForegroundColor Cyan
    $tmp = "/data/local/tmp/cyt-sports-config.json"
    $uri = "content://com.gathin.tvhome.theme/config.json"
    Run-Tv "echo '{\`"sports_recommendation\`": true}' > $tmp; content write --uri $uri < $tmp 2>/dev/null; rm -f $tmp"
    Run-Tv "am force-stop com.gathin.tvhome"
    Run-Tv "am start -a android.intent.action.MAIN -c android.intent.category.HOME -n com.gathin.tvhome/.MainActivity"
    # Recover HomeKeyService accessibility binding after force-stop
    Run-Tv "settings put secure enabled_accessibility_services ''; settings put secure accessibility_enabled 0; sleep 1; settings put secure enabled_accessibility_services com.gathin.tvhome/.HomeKeyService; settings put secure accessibility_enabled 1"
    Write-Host "Done! Sports feature is now re-enabled and active on the home screen." -ForegroundColor Green
    exit 0
}

if ($SportsOnly) {
    Write-Host "=== Reverting ONLY Sports Recommendation Feature ===" -ForegroundColor Cyan
    Write-Host "Disabling Sports Recommendations on CleanYourTV..."
    
    $tmp = "/data/local/tmp/cyt-sports-config.json"
    $uri = "content://com.gathin.tvhome.theme/config.json"
    
    Run-Tv "echo '{\`"sports_recommendation\`": false}' > $tmp; content write --uri $uri < $tmp 2>/dev/null; rm -f $tmp"

    Write-Host "Restarting CleanYourTV Home..."
    Run-Tv "am force-stop com.gathin.tvhome"
    Run-Tv "am start -a android.intent.action.MAIN -c android.intent.category.HOME -n com.gathin.tvhome/.MainActivity"
    # Recover HomeKeyService accessibility binding after force-stop
    Run-Tv "settings put secure enabled_accessibility_services ''; settings put secure accessibility_enabled 0; sleep 1; settings put secure enabled_accessibility_services com.gathin.tvhome/.HomeKeyService; settings put secure accessibility_enabled 1"

    Write-Host "Done! Sports feature is now completely deactivated (top icon hidden, 0 network activity)." -ForegroundColor Green
    exit 0
}

# Full Factory Reversal
Write-Host "====================================================================" -ForegroundColor Yellow
Write-Host "=== Full Factory Reversal (Restoring Stock Bloated Android TV) ===" -ForegroundColor Yellow
Write-Host "====================================================================" -ForegroundColor Yellow

if (-not $Force) {
    Write-Host "Starting rollback in 3 seconds (Press Ctrl+C to abort)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

$packages = @(
    "com.miui.tv.analytics",
    "com.xiaomi.statistic",
    "com.google.android.feedback",
    "com.mitv.tvhome.atv",
    "com.xm.webcontent",
    "com.google.android.tvrecommendations",
    "android.autoinstalls.config.xioami.dangal",
    "com.mitv.tvhome.mitvplus",
    "com.xiaomi.mitv.tvmanager",
    "com.xiaomi.mitv.handbook",
    "com.xiaomo.tv.milegal",
    "com.xiaomi.mimusic2",
    "com.google.android.play.games",
    "com.google.android.videos",
    "com.mitv.dream",
    "com.google.android.tvlauncher"
)

Write-Host "Re-enabling all 16 disabled bloatware packages..."
foreach ($pkg in $packages) {
    Write-Host "  -> Enabling $pkg..."
    Run-Tv "pm enable $pkg"
}

Write-Host "Restoring stock Google TV Launcher as default..."
Run-Tv "cmd package set-home-activity --user 0 com.google.android.tvlauncher/.MainActivity"

Write-Host "Resetting notification and accessibility services..."
Run-Tv "cmd notification disallow_listener com.gathin.tvhome/.MediaNotificationListenerService 2>/dev/null"
Run-Tv "settings put secure enabled_accessibility_services ''"
Run-Tv "settings put secure accessibility_enabled 0"

Write-Host "Restoring default DNS mode..."
Run-Tv "settings put global private_dns_mode opportunistic"

Write-Host "Launching stock Google TV home screen..."
Run-Tv "am start -a android.intent.action.MAIN -c android.intent.category.HOME -n com.google.android.tvlauncher/.MainActivity"

Write-Host "COMPLETE! TV has been fully restored to factory stock bloated Android TV." -ForegroundColor Green
