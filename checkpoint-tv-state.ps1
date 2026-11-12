param(
    [string]$TvHost = "192.168.29.16",
    [string]$CheckpointDir = "backup\checkpoint-mitv-axfr1"
)

$ErrorActionPreference = 'Continue'
$env:TV_HOST = $TvHost
$outPath = Join-Path $PSScriptRoot $CheckpointDir

if (-not (Test-Path $outPath)) {
    New-Item -ItemType Directory -Path $outPath -Force | Out-Null
}

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "=== Creating Checkpoint of Current TV State ($TvHost) ===" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

$adbTarget = "${TvHost}:5555"
Write-Host "Connecting to $adbTarget..."
adb connect $adbTarget | Out-Null

$devList = (adb devices) -join "`n"
if ($devList -notmatch "${TvHost}:5555\s+device") {
    Write-Host "[ERROR] Could not connect to TV at $adbTarget. Status: $devList" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Connected to TV. Capturing system state..." -ForegroundColor Green

# 1. Capture disabled packages
Write-Host "  -> Backing up disabled packages list..."
adb -s $adbTarget shell pm list packages -d > (Join-Path $outPath "disabled-packages.txt")

# 2. Capture accessibility services
Write-Host "  -> Backing up accessibility services..."
adb -s $adbTarget shell settings get secure enabled_accessibility_services > (Join-Path $outPath "accessibility-services.txt")

# 3. Capture home activity
Write-Host "  -> Backing up default home activity..."
adb -s $adbTarget shell cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.HOME > (Join-Path $outPath "home-activity.txt")

# 4. Capture private DNS
Write-Host "  -> Backing up Private DNS settings..."
$dnsMode = (adb -s $adbTarget shell settings get global private_dns_mode).Trim()
$dnsHost = (adb -s $adbTarget shell settings get global private_dns_specifier).Trim()
"$dnsMode`n$dnsHost" | Set-Content (Join-Path $outPath "private-dns.txt")

# 5. Capture theme config from content provider
Write-Host "  -> Backing up active launcher theme config..."
adb -s $adbTarget shell content read --uri content://com.gathin.tvhome.theme/config.json 2>$null > (Join-Path $outPath "theme-config.json")

# 6. Pull installed APK from TV
Write-Host "  -> Pulling installed launcher APK from TV..."
$remoteApkRaw = (adb -s $adbTarget shell pm path com.gathin.tvhome 2>$null) -join ""
if ($remoteApkRaw -match "package:(.+)") {
    $remoteApk = $matches[1].Trim()
    adb -s $adbTarget pull $remoteApk (Join-Path $outPath "installed-tvhome.apk") | Out-Null
    Write-Host "     APK saved: installed-tvhome.apk" -ForegroundColor Green
}

# 7. Record checkpoint info & git commit
$gitBranch = (git -C $PSScriptRoot branch --show-current).Trim()
$gitSha = (git -C $PSScriptRoot rev-parse HEAD).Trim()
$info = @"
Checkpoint Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
TV Host: $TvHost
Git Branch: $gitBranch
Git Commit: $gitSha
Default Launcher: com.gathin.tvhome
Accessibility Service: com.gathin.tvhome/.HomeKeyService
Private DNS: $dnsHost ($dnsMode)
"@
$info | Set-Content (Join-Path $outPath "checkpoint-info.txt")

Write-Host "====================================================================" -ForegroundColor Green
Write-Host "CHECKPOINT SAVED SUCCESSFULLY in $outPath" -ForegroundColor Green
Write-Host "To revert any future changes back to this checkpoint, run:" -ForegroundColor Yellow
Write-Host "  powershell -File .\restore-checkpoint.ps1" -ForegroundColor Yellow
Write-Host "====================================================================" -ForegroundColor Green
