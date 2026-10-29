# MiTV-AXFR1 Debloat, Apple TV Launcher & ARC Volume Setup

## Summary of Changes
- **Debloated Xiaomi Bloatware**: Safely disabled PatchWall (`com.mitv.tvhome.atv`), Xiaomi/MIUI analytics & telemetry (`com.miui.tv.analytics`, `com.xiaomi.statistic`), sponsored recommendations, auto-installers, TV Manager cleaner, and preloaded apps (16 packages total).
- **Apple TV 4K Style Launcher**: Built and installed native Android TV launcher (`com.gathin.tvhome`):
  - Pitch black OLED background.
  - Translucent rounded glass dock band at the bottom with 4 curated slots:
    1. Apple TV (`com.apple.atve.androidtv.appletv`)
    2. Netflix (`com.netflix.ninja`)
    3. YouTube (`com.google.android.youtube.tv`)
    4. Prime Video (`com.amazon.amazonvideo.livingroom`)
  - App grid below that smoothly scrolls up with D-pad Down.
  - Translucent glass spring highlight with ambient glow sampled from app banners.
  - Large thin clock, date, and greeting top left.
- **Icon-Only Minimal Top Pills**:
  - Inputs (`ic_input`), Wi-Fi (`ic_wifi`), Sports Recommendations (`ic_sports`), Reorder (`ic_swap_vert`), and Settings (`ic_settings`) are minimal 42dp frosted circular buttons without text clutter.
- **Media Player Architecture & Future Rebuild Specification**:
  - Complete architecture, source code, and design specifications for the YouTube Music media player widget, synchronized live lyrics, and `MediaSessionManager` integration are safely preserved in [`docs/MEDIA_PLAYER_WIDGET_SPEC.md`](file:///C:/Users/sayon/OneDrive/Documents/gemini/cleanyourtv/docs/MEDIA_PLAYER_WIDGET_SPEC.md) for future rebuilds. (Source code removed from active launcher build as requested to maintain zero-latency launcher responsiveness).
- **Sports Recommendation Feed**:
  - Top-bar trophy icon opens an Apple TV-style frosted glass feed with category filter tabs (`ALL`, `SOCCER`, `TENNIS`, `F1`, `CRICKET`).
  - **LIVE Pins**: Active matches pinned to the top with red `LIVE` badge (no date/time clutter).
  - **Chronological EPG Ordering**: All upcoming matches ordered chronologically by kickoff timestamp (`Today HH:mm`, `Tomorrow HH:mm`, `EEE, d MMM HH:mm`).
  - **Deterministic D-pad Traversal**: Pressing UP from Row 1 always jumps directly back to the active parent filter tab (`ALL` or `SOCCER`), eliminating erratic jumps to F1. Pressing DOWN from any filter tab smoothly enters Row 1.
  - **Top Indian & Global Priorities**: Mohun Bagan Super Giant, East Bengal FC, and the Indian Super League (`ind.1`) prioritized as top favorites (`priority = 5`) with 1-click launch to JioCinema (`com.jio.media.ondemand`) / JioTV+ / YouTube, alongside international favorites.
  - Fetches upcoming & live fixtures from public ESPN endpoints with local 2-hour caching and zero background battery drain.
- **Frosted Glass Floating Settings Drawer**:
  - Top Settings button opens a 2-option picker ("Launcher" and "TV").
  - "Launcher" opens a compact 380dp floating frosted-glass right-side drawer (`Theme.LauncherSettings`) over the dimmed Home screen with 11sp–12sp tvOS typography, slim 32dp rows, and 26dp segmented chips. Fits on-screen with zero/minimal scrolling.
  - Independent toggle for **Sports Recommendations** directly inside the drawer.
- **Interactive App Reordering**:
  - **Method 1**: Navigate to any app tile and **Hold OK** on your remote &rarr; choose **"Move"** &rarr; use arrow keys to shift position &rarr; press **OK** to place.
  - **Method 2**: Click the two-arrow **Reorder button** in the top bar.
- **HDMI ARC On-Screen Volume Indicator**:
  - Vertically centered frosted-glass capsule on the right side of the screen (`Gravity.CENTER_VERTICAL | Gravity.END`).
  - Displays directional feedback (`VOL +`, `VOL −`, `MUTE ✕`) immediately upon remote button presses without breaking HDMI CEC audio or getting clamped by Android stream volume.
- **Ad-blocking Private DNS**: Configured AdGuard Private DNS (`dns.adguard-dns.com`) for network-level ad and telemetry blocking.
- **Hardware Integrity**: Preserved all HDMI CEC, HDMI ARC, TV Input Framework (`com.droidlogic.tvinput`), and remote control Bluetooth services.

---

## TV Remote & Daily Navigation Reference

### 1. Home Screen Navigation
| Action | Remote Key / Gesture | What Happens |
| :--- | :--- | :--- |
| **Move Focus Up** | `D-pad UP` | Navigates from App Grid &rarr; Dock band &rarr; Top Status Pills (`Inputs`, `Wi-Fi`, `Sports`, `Reorder`, `Settings`). |
| **Move Focus Down** | `D-pad DOWN` | Navigates from Top Pills &rarr; Dock band &rarr; smoothly scrolls down into full App Grid. |
| **Launch App** | `OK` (short press) | Launches focused application. |
| **Reorder / Manage App** | `OK` (long press / hold) | Opens contextual popup with **"Move"** (use arrows to position tile, `OK` to drop) and **"App info"**. |
| **Return to Home** | `HOME` | Instantly returns to Home screen (handled with zero delay via `HomeKeyService`). |

### 2. Sports Recommendation Feed (Trophy Icon)
| Action | Remote Key / Gesture | What Happens |
| :--- | :--- | :--- |
| **Open Sports Drawer** | `OK` on Trophy pill | Slides open frosted glass Sports drawer with real-time live & upcoming fixtures. |
| **Switch Category Filter** | `D-pad LEFT / RIGHT` | Toggles between `ALL`, `SOCCER`, `TENNIS`, `F1`, and `CRICKET`. |
| **Enter Fixture List** | `D-pad DOWN` from any filter tab | Smoothly jumps focus to the first fixture in the active category. |
| **Return to Filter Tabs** | `D-pad UP` from Row 1 | Returns focus directly to the active parent filter tab (`ALL` or `SOCCER`). |
| **Watch Match** | `OK` on any fixture | Automatically opens official TV streaming app (JioCinema for ISL / Mohun Bagan / East Bengal, JioHotstar for Cricket / Premier League, Sony LIV for Champions League, Apple TV, YouTube TV). |
| **Close Sports Drawer** | `BACK` | Dismisses sports drawer and returns focus to top bar. |

### 3. HDMI ARC Volume Remote Overlay
| Action | Remote Key | What Happens |
| :--- | :--- | :--- |
| **Volume Up / Down** | `VOL +` / `VOL −` | JBL Cinema SB510 soundbar adjusts hardware volume over HDMI ARC; TV displays vertical right-aligned glass pill (`VOL +` / `VOL −`) with clean directional feedback. |
| **Mute / Unmute** | `MUTE` | Mutes audio stream; TV displays `MUTE ✕` overlay. |

### 4. Settings Picker & Compact Drawer
| Action | Remote Key / Gesture | What Happens |
| :--- | :--- | :--- |
| **Open Settings Picker** | `OK` on Gear pill | Drops down frosted choice popup: **"Launcher"** or **"TV"**. |
| **Launcher Settings** | `OK` on "Launcher" | Opens compact 380dp floating right drawer over dimmed Home. Toggle Sports Recommendations, grid columns, dock rows, and animations. |
| **System TV Settings** | `OK` on "TV" | Directly opens default Android TV Settings (`com.android.tv.settings`). |
| **Dismiss Drawer** | `BACK` or click outside | Closes drawer and un-dims the Home screen. |

---

## CLI & Automation Usage Reference

All commands below can be executed from a PowerShell prompt on your computer.

### 1. Single-Click Rollback & Toggles (`restore-all-v2.ps1`)
[`restore-all-v2.ps1`](file:///C:/Users/sayon/OneDrive/Documents/gemini/cleanyourtv/restore-all-v2.ps1) provides 1-click selective or total reversals:

```powershell
# Option 1: 1-Click Full Factory Rollback
# Re-enables all 16 disabled Xiaomi/Google bloatware packages, restores stock Google TV launcher,
# resets accessibility services, and restores default DNS (includes a 3-second abort window).
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -TvHost 192.168.29.16

# Option 2: 1-Click Full Factory Rollback (immediate, skip 3-second countdown)
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -TvHost 192.168.29.16 -Force

# Option 3: Disable ONLY Sports Recommendations
# Hides the top trophy icon and stops all background networking while keeping the clean launcher & volume overlay.
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -TvHost 192.168.29.16 -SportsOnly

# Option 4: Re-enable Sports Recommendations
# Restores the sports feed and automatically re-binds HomeKeyService accessibility.
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -TvHost 192.168.29.16 -EnableSports

# Option 5: Security Shutdown
# Stops the ADB daemon on the TV to protect port 5555.
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -TvHost 192.168.29.16 -CloseAdb

# View all options and help
powershell -ExecutionPolicy Bypass -File .\restore-all-v2.ps1 -Help
```

### 2. Building & Deploying the Launcher
If you modify launcher code or [`config.xml`](file:///C:/Users/sayon/OneDrive/Documents/gemini/cleanyourtv/launcher/app/src/main/res/values/config.xml):

```powershell
Set-Location "C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv\launcher"
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot"
$env:ANDROID_HOME = "C:\Android\Sdk"
$env:TV_HOST = "192.168.29.16"

powershell -ExecutionPolicy Bypass -File .\build-and-install.ps1 -TvHost 192.168.29.16 -StockLauncher none -HomeKeyService
```

### 3. Customizing Dock Apps & Wallpapers
#### Editing Dock Apps:
1. Open [`config.xml`](file:///C:/Users/sayon/OneDrive/Documents/gemini/cleanyourtv/launcher/app/src/main/res/values/config.xml).
2. Edit `<string-array name="dock_apps">` with your desired package names in order.
3. Re-run `build-and-install.ps1` as shown above.

#### Changing Themes & Wallpapers:
```powershell
Set-Location "C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv"

# Apply Aurora theme
powershell -ExecutionPolicy Bypass -File .\tools\theme.ps1 -TvHost 192.168.29.16 themes\aurora

# Apply Glass theme
powershell -ExecutionPolicy Bypass -File .\tools\theme.ps1 -TvHost 192.168.29.16 themes\glass

# Reset to pitch black Apple TV default
powershell -ExecutionPolicy Bypass -File .\tools\theme.ps1 -TvHost 192.168.29.16 --reset
```

### 4. Remote TV Diagnostics & Screenshots
Capture real-time screenshots and run diagnostics without installing external tools:

```powershell
Set-Location "C:\Users\sayon\OneDrive\Documents\gemini\cleanyourtv"
$py = ".\tools\venv\Scripts\python.exe"

# Capture a screenshot to shots/current.png
& $py tools\tv.py --screenshot shots\current.png

# Send a remote key event (e.g. HOME, DPAD_DOWN, BACK)
& $py tools\tv.py "input keyevent KEYCODE_HOME"

# Check connected audio devices and HDMI ARC status
& $py tools\tv.py "dumpsys audio | grep -E 'mArcEstablished|mSystemAudioActivated'"
```

---

## Future Gemini Sessions
Refer to [`GEMINI-PICKUP-GUIDE.md`](file:///C:/Users/sayon/OneDrive/Documents/gemini/cleanyourtv/GEMINI-PICKUP-GUIDE.md) for complete pickup instructions, environment paths, and ready-to-paste prompt templates.

---

## Closing ADB & Securing Your TV
Once you have finished customizing your TV:
1. On your TV, navigate to **Settings** &rarr; **Device Preferences** &rarr; **Developer options**.
2. Select **Revoke USB debugging authorizations**.
3. Toggle **USB debugging** to **OFF**.
4. Reboot the TV.
5. In PowerShell, confirm port 5555 is closed and refusing connections:
   ```powershell
   cleanyourtv\tools\venv\Scripts\python.exe cleanyourtv\tools\adb-closed.py 192.168.29.16
   ```
