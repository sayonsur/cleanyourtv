# Gemini & Antigravity Pickup Guide: MiTV-AXFR1 Clean TV Setup

This document explains everything set up on this device and provides a step-by-step guide for picking up or modifying this setup in future Gemini / Antigravity pair programming sessions.

---

## 1. System & Device Profile

- **Device**: Xiaomi Mi TV 4A / Horizon Edition
- **Model / Product**: `MiTV-AXFR1` (`rango`), Amlogic chipset
- **OS Version**: Android TV 11 (API Level 30)
- **Soundbar**: JBL Cinema SB510 connected via HDMI ARC on Port 1 (`mArcEstablished=true`, `mSystemAudioActivated=true`)
- **Default Launcher**: `com.gathin.tvhome` (Clean Apple TV style home screen)
- **Volume Overlay**: Integrated Accessibility Service (`com.gathin.tvhome/.HomeKeyService`) rendering a vertical frosted glass side-pill (`VOL +`, `VOL −`, `MUTE ✕`) on remote button presses without breaking HDMI CEC audio
- **Ad-Blocking DNS**: AdGuard Private DNS (`dns.adguard-dns.com`) configured at system level
- **Top Status Pills**: Inputs (`btnInputs`), Wi-Fi (`btnWifi`), Sports Recommendations (`btnSports`), Reorder Apps (`btnReorder`), and Settings Gear (`btnSettings`).
- **Sports Recommendation Feed**: Dedicated 22dp trophy button (`btnSports`) in the top bar opening an Apple TV-style frosted glass panel. Real-time live & upcoming fixtures fetched asynchronously from ESPN public REST endpoints (with local 2-hour caching & zero background battery drain). Features include:
  - **LIVE Pins**: Currently active matches pinned to the top in red (`LIVE`), without date/time.
  - **Chronological EPG Ordering**: All upcoming matches ordered chronologically by Date & Time with clean TV guide timings (`Today 17:45`, `Tomorrow 19:30`, `Sat, 31 Oct 19:30`).
  - **Parent Section D-pad Return**: Pressing UP from Row 1 always returns directly to the active parent filter chip (`filterAll` or `filterSoccer`), eliminating erratic jumps to F1. Pressing DOWN from any chip jumps directly to the list's first item.
  - **Local & International Priorities**: Mohun Bagan Super Giant, East Bengal FC, and Indian Super League (`ind.1`) prioritized as top favorites (`priority = 5`) with 1-click launch to JioCinema (`com.jio.media.ondemand`) / JioTV+ / YouTube, alongside international favorites (Barcelona, Messi, Real Madrid, Premier League, Champions League, ATP, F1, Indian Cricket).
- **Settings Picker Popup**: Clicking the top-right Settings Gear (`ic_settings`) opens a matching Apple TV frosted glass dropdown with two quick choices:
  - **Launcher**: Opens Launcher Settings in a compact 380dp floating frosted-glass right drawer (`Theme.LauncherSettings`) over the dimmed Home screen, styled with small 11sp–12sp tvOS fonts, slim 32dp rows, 26dp segmented chips, CLOSE button, and click-scrim-to-dismiss.
  - **TV**: Directly opens default Android TV Settings (`com.android.tv.settings`).
- **Media Player Architecture Specification**: Complete source code and design specification archived in [`docs/MEDIA_PLAYER_WIDGET_SPEC.md`](docs/MEDIA_PLAYER_WIDGET_SPEC.md) for future rebuilds. (Source removed from active build to keep launcher lightweight due to Android TV Cobalt audio background tearing).
- **1-Click Rollback Script v2**: `restore-all-v2.ps1` allows independently toggling the sports feature (`-SportsOnly` / `-EnableSports`), closing ADB (`-CloseAdb`), or performing a 100% full factory restore to bloated Android TV.

---

## 2. Workspace & Environment Locations

When starting a new session on this machine:
- **Repository Path**: `C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv`
- **JDK 17 Path**: `C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot`
- **Android SDK**: `C:\Android\Sdk`
- **Python Virtualenv**: `C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv\tools\venv`
- **Backup Folder**: `C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv\backup`
- **Screenshots**: `C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv\shots`

---

## 3. How to Pick Up from Here in a New Gemini Session

Whenever you open a new Gemini / Antigravity chat and want to continue working on your TV:

### Step 1: Turn On USB Debugging on the TV
1. On your TV remote, go to **Settings** &rarr; **Device Preferences** &rarr; **Developer options**.
2. Toggle **USB debugging** to **ON**.
3. Check your TV's current IP address under **Settings** &rarr; **Network & Internet** (e.g. `192.168.29.16`).

### Step 2: Copy & Paste this Prompt to Gemini
Copy and send the following prompt into your Gemini chat:

```text
I want to continue customizing my Android TV (MiTV-AXFR1). 
The codebase is located at C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv.
The TV is on my local Wi-Fi with IP 192.168.29.16 (or current IP).
Developer options and USB debugging are ON.
Please review GEMINI-PICKUP-GUIDE.md and TV-SETUP-README.md in the repo root before proceeding.
Environment:
- JAVA_HOME: C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot
- ANDROID_HOME: C:\Android\Sdk
- Python venv: cleanyourtv\tools\venv\Scripts\python.exe

I want to: [DESCRIBE WHAT YOU WANT TO CHANGE OR DO]
```

### Step 3: Accept the On-Screen ADB Prompt
When Gemini runs its first `adb connect` command, look at your TV screen and select **"Always allow from this computer"** &rarr; **OK**.

---

## 4. Key Workflows & Scripts

### A. Rebuilding & Installing the Launcher
If you change launcher code or `config.xml`:
```powershell
Set-Location "C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv\launcher"
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot"
$env:ANDROID_HOME = "C:\Android\Sdk"
$env:TV_HOST = "192.168.29.16"

powershell -ExecutionPolicy Bypass -File .\build-and-install.ps1 -TvHost 192.168.29.16 -StockLauncher none -HomeKeyService
```

### B. Customizing Dock Apps or Layout
1. Edit `launcher/app/src/main/res/values/config.xml`:
   - `<string-array name="dock_apps">`: Change pinned apps in the dock row.
   - `<bool name="reorder_button">`: `true` to keep the arrow reorder button in the top bar.
   - `<bool name="icon_only_buttons">`: `true` for circular icon-only top pills.
2. Re-run the build script above.

### C. Applying Themes / Wallpapers
```powershell
Set-Location "C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv"
# Apply the built-in Aurora theme:
powershell -ExecutionPolicy Bypass -File .\tools\theme.ps1 -TvHost 192.168.29.16 themes\aurora

# Apply Glass theme:
powershell -ExecutionPolicy Bypass -File .\tools\theme.ps1 -TvHost 192.168.29.16 themes\glass

# Reset to pitch black Apple TV default:
powershell -ExecutionPolicy Bypass -File .\tools\theme.ps1 -TvHost 192.168.29.16 --reset
```

### D. Rollback & Management Script v2 (`restore-all-v2.ps1`)
Use `restore-all-v2.ps1` for selective reversal or a total factory rollback:

```powershell
Set-Location "C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv"

# Option 1: Revert ONLY the Sports feature (hides trophy icon, 0 network activity):
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -TvHost 192.168.29.16 -SportsOnly

# Option 2: Re-enable the Sports feature:
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -TvHost 192.168.29.16 -EnableSports

# Option 3: Full Factory Rollback (re-enables 16 bloatware apps, restores stock Google TV launcher):
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -TvHost 192.168.29.16

# Option 4: Full Factory Rollback (immediate, skip 3s countdown):
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -TvHost 192.168.29.16 -Force

# Option 5: Quick security shutdown (stops ADB daemon on TV):
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -TvHost 192.168.29.16 -CloseAdb

# Option 6: View all options and help:
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -Help
```
This script will:
- Re-enable all 16 disabled Xiaomi and Google bloatware packages.
- Reset the default home activity back to `com.google.android.tvlauncher`.
- Disable the accessibility volume overlay service.
- Reset Private DNS mode to `opportunistic` (default).

---

## 5. GitHub Branches & Pull Requests Guide

### Overview of Branches in `sayonsur/cleanyourtv`:

| Branch | Purpose | Upstream Target | Status | Compare / PR Link |
| :--- | :--- | :--- | :--- | :--- |
| `feature/mitv-axfr1-arc-volume` | **Your Personal TV Fork Branch** (active on TV, contains ARC volume overlay, sports feed, reversal script v2, debloat, custom guides) | None (stays in your fork) | Clean & Pushed | [Commit bc433cc1](https://github.com/sayonsur/cleanyourtv/commit/bc433cc1) |
| `showcase-hdmi-arc-volume` | **PR 1**: Adds row under Forks in `SHOWCASE.md` & brand index in `README.md` | `Gathin23/cleanyourtv:main` | Clean & Pushed | [Open PR 1](https://github.com/Gathin23/cleanyourtv/compare/main...sayonsur:cleanyourtv:showcase-hdmi-arc-volume?expand=1) |
| `docs-mitv-axfr1-device-note` | **PR 2**: Device note `docs/devices/xiaomi-mitv-axfr1.md` and `examples/xiaomi-mitv-axfr1/tv.json` | `Gathin23/cleanyourtv:main` | Clean & Pushed | [Open PR 2](https://github.com/Gathin23/cleanyourtv/compare/main...sayonsur:cleanyourtv:docs-mitv-axfr1-device-note?expand=1) |
| `feature/sports-recommendations` | Sports recommendation feed + compact settings drawer cleanly based on `upstream/main` | `Gathin23/cleanyourtv:main` | Clean & Pushed | [Open PR (Optional)](https://github.com/sayonsur/cleanyourtv/pull/new/feature/sports-recommendations) |

> [!NOTE]
> Upstream maintainer Gathin keeps the core launcher strictly under **576 KB** and **100% offline** (no `INTERNET` permission in manifest). Heavy features like live internet feeds and volume overlays belong in forks or external add-ons (like `addons/game-day`). Keep `feature/mitv-axfr1-arc-volume` as your daily-driver branch!

---

## 6. Security Shutdown Checklist (Current Step)

Whenever you finish modifying the TV:
1. Open TV **Settings** &rarr; **Device Preferences** &rarr; **Developer options**.
2. Select **Revoke USB debugging authorizations**.
3. Toggle **USB debugging** to **OFF**.
4. Reboot the TV.
5. In PowerShell, verify that port 5555 is closed and refusing connections:
   ```powershell
   cleanyourtv\tools\venv\Scripts\python.exe cleanyourtv\tools\adb-closed.py 192.168.29.16
   ```
