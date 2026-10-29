param(
    [string]$TvHost = "192.168.29.16"
)

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

Write-Host "Re-enabling packages on TV ($TvHost)..."
foreach ($pkg in $packages) {
    Write-Host "Enabling $pkg..."
    adb -s "$TvHost:5555" shell "pm enable $pkg"
}

Write-Host "Restoring stock Google TV Launcher as default..."
adb -s "$TvHost:5555" shell "cmd package set-home-activity --user 0 com.google.android.tvlauncher/.MainActivity"

Write-Host "Resetting volume overlay accessibility services..."
adb -s "$TvHost:5555" shell "settings put secure enabled_accessibility_services ''"
adb -s "$TvHost:5555" shell "settings put secure accessibility_enabled 0"

Write-Host "Restoring default DNS..."
adb -s "$TvHost:5555" shell "settings put global private_dns_mode opportunistic"

Write-Host "Done! TV has been completely restored to stock."
