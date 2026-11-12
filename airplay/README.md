# AirPlay Receiver (iPhone / iPad / Mac → TV)

Ad-free background AirPlay receiver, like Chromecast built-in but for Apple devices.
It uses [jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server), which builds on the
[UxPlay](https://github.com/FDH2/UxPlay) protocol core. That code is **GPL-3** and stays an isolated separate app
(`io.github.jqssun.airplay`). This repo only holds the MIT build/install scripts and contains no GPL code.

---

## Quick Install

### Windows (PowerShell)
```powershell
.\airplay\install-airplay.ps1 -TvHost 192.168.29.16
```

Options:
- `-Name "Custom Name"`: Set custom AirPlay display name (defaults to TV's `device_name`, e.g. "BedroomBinge").
- `-Tag "v0.0.36"`: Specify version (default `v0.0.36`, or `v0.0.33`).
- `-RequirePin`: Require a PIN for Apple devices connecting for the first time.
- `-Force`: Redownload the APK even if cached locally.

### Linux / macOS (Bash)
```bash
TV_HOST=192.168.29.16 ./airplay/build-and-install.sh
```

---

## What the Installer Does

1. Downloads or builds the open-source AirPlay server APK.
2. Installs `io.github.jqssun.airplay` onto the TV.
3. Automatically names the receiver after the TV's system `device_name` (e.g. `BedroomBinge`).
4. Configures `boot_auto_start = true` so the receiver is immediately available upon TV startup.
5. Whitelists the app from Android Doze (`dumpsys deviceidle whitelist +io.github.jqssun.airplay`).
6. Grants background execution permissions (`cmd appops set io.github.jqssun.airplay RUN_IN_BACKGROUND allow`).
7. Initializes the background service and returns the screen to CleanYourTV home launcher.

---

## How It Works in Practice

- **Zero Interruption**: When idle, the receiver sits as a lightweight background service using ~40 MB of RAM.
- **Auto Launch**: When an iPhone, iPad, or Mac begins Screen Mirroring or AirPlay audio, the receiver automatically opens full screen.
- **Audio Routing**: Outputs PCM audio directly to the TV's active audio system (e.g., HDMI ARC soundbar / JBL Cinema SB510).
- **Supported Content**: Screen mirroring, photos, music/podcasts (AAC/ALAC), YouTube video streaming.
- **DRM Note**: Protected DRM video (Netflix, Apple TV+, Disney+) cannot be mirrored due to Apple FairPlay video DRM encryption.

---

## 1-Click Reversal / Uninstall

To completely and cleanly remove the AirPlay receiver from the TV:

```powershell
.\airplay\uninstall-airplay.ps1 -TvHost 192.168.29.16
```

This:
1. Force-stops the `io.github.jqssun.airplay` process.
2. Removes it from the battery optimization whitelist.
3. Resets application appops permissions.
4. Completely uninstalls the package from the TV.
5. Removes temporary files and returns the TV to the clean launcher state.

---

## Advanced ADB Settings

Settings can be inspected or adjusted anytime over ADB without opening the app UI:

```powershell
# Set server name
adb shell am broadcast -a io.github.jqssun.airplay.SET_SETTING -n io.github.jqssun.airplay/.SettingsReceiver --es key server_name --es value "My TV"

# Toggle PIN requirement
adb shell am broadcast -a io.github.jqssun.airplay.SET_SETTING -n io.github.jqssun.airplay/.SettingsReceiver --es key require_pin --es value true

# Toggle client volume sync
adb shell am broadcast -a io.github.jqssun.airplay.SET_SETTING -n io.github.jqssun.airplay/.SettingsReceiver --es key sync_client_volume --es value true

# List all available settings
adb shell am broadcast -a io.github.jqssun.airplay.LIST_SETTINGS -n io.github.jqssun.airplay/.SettingsReceiver
```
