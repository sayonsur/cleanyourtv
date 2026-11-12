# Continue Watching (Watch Next) R&D Specification & Compatibility Guide

This document preserves the feasibility research, Android TV system mechanics, and implementation blueprint for an optional **Continue Watching** (Watch Next) tray in CleanYourTV, referencing the [`gwiersma/cleanyourtv:FORK.md`](https://github.com/gwiersma/cleanyourtv/blob/main/FORK.md) implementation.

---

## 1. Executive Summary & Status

- **Status**: **R&D Complete / Deferred by User** (Preserved for future implementation).
- **Core Concept**: A horizontal frosted-glass tray displaying up to 15 cards of unfinished movies and TV episodes between the header and the dock, with progress bars and 1-click resume deep-linking.
- **Primary Finding**: Fully feasible for apps supporting Android TV's `WatchNextProgram` API (Prime Video, Apple TV, Jellyfin, Plex, Kodi, SmartTube). However, **Netflix, Hoichoi, Zee5, and Sony LIV do not publish data to Android TV's system table**, so content from those apps cannot appear without custom cloud scraping.

---

## 2. App Compatibility Matrix (Xiaomi Mi TV / Android TV 11)

| App | Package Name | Publishes to `watch_next_program`? | Technical Behavior & Limitations |
| :--- | :--- | :---: | :--- |
| **Netflix** | `com.netflix.ninja` | ❌ **No** | **Blocked by Netflix policy**. Netflix does not implement Android TV's Leanback `WatchNextProgram` provider API. Playback progress is kept inside Netflix's private sandbox and cloud servers. |
| **Amazon Prime Video** | `com.amazon.amazonvideo.livingroom` | ✅ **Yes** | **Fully Supported**. Prime Video writes unfinished titles, episode titles, landscape artwork, progress duration, and deep-link intent URIs. |
| **Apple TV** | `com.apple.atve.androidtv.appletv` | ✅ **Yes** | **Fully Supported**. Publishes "Up Next" queue directly to the system provider. |
| **JioHotstar / Hotstar** | `in.startv.hotstar` | ⚠️ **Partial** | Historically supported on certain Android TV 11 versions; newer unified Jio/Hotstar builds frequently prioritize in-app carousels over system sync. |
| **YouTube** | `com.google.android.youtube.tv` | ⚠️ **Partial** | Publishes recommendation channels; occasionally feeds `watch_next_program` for logged-in accounts with watch history enabled. |
| **Sony LIV** | `com.sonyliv` | ❌ **No** | In-app carousel only; does not reliably export watch progress to the system table. |
| **Zee5** | `com.graymatrix.did` | ❌ **No** | Proprietary cloud sync; does not publish to `watch_next_program`. |
| **Hoichoi** | `com.viewlift.hoichoi` | ❌ **No** | ViewLift OTT platform lacks Android TV `WatchNextProgram` publisher integration. |
| **Plex / Jellyfin / Kodi / VLC / SmartTube** | *(Local / Open Media)* | ✅ **Yes** | **Fully Supported**. All major open media players actively publish full Continue Watching metadata. |

---

## 3. System Architecture & Android API Mechanics

### A. System ContentProvider
Android TV centralizes continue watching items inside the system `TvProvider`:
- **Content URI**: `content://android.media.tv/watch_next_program`
- **Class Reference**: `android.media.tv.TvContract.WatchNextPrograms` / `androidx.tvprovider.media.tv.WatchNextProgram`

### B. Required Permission
In `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.READ_TV_LISTINGS" />
```
Granted over ADB during setup:
```powershell
adb shell pm grant com.gathin.tvhome android.permission.READ_TV_LISTINGS
```

### C. Database Schema & Query Projection
```java
String[] PROJECTION = {
    TvContract.WatchNextPrograms._ID,                             // long primary key
    TvContract.WatchNextPrograms.COLUMN_PACKAGE_NAME,            // owning app package
    TvContract.WatchNextPrograms.COLUMN_TITLE,                   // title of show or movie
    TvContract.WatchNextPrograms.COLUMN_EPISODE_TITLE,           // episode name
    TvContract.WatchNextPrograms.COLUMN_POSTER_ART_URI,          // poster URI
    TvContract.WatchNextPrograms.COLUMN_THUMBNAIL_URI,           // 16:9 thumbnail URI
    TvContract.WatchNextPrograms.COLUMN_LAST_PLAYBACK_POSITION_MILLIS, // watched ms
    TvContract.WatchNextPrograms.COLUMN_DURATION_MILLIS,         // total ms
    TvContract.WatchNextPrograms.COLUMN_INTENT_URI,              // deep-link Intent URI
    TvContract.WatchNextPrograms.COLUMN_LAST_ENGAGEMENT_TIME_UTC_MILLIS // sort order
};

// Querying the latest 15 items:
Cursor cursor = getContentResolver().query(
    TvContract.WatchNextPrograms.CONTENT_URI,
    PROJECTION,
    null,
    null,
    TvContract.WatchNextPrograms.COLUMN_LAST_ENGAGEMENT_TIME_UTC_MILLIS + " DESC LIMIT 15"
);
```

### D. Playback Resume Action
Clicking a card extracts the `COLUMN_INTENT_URI` and launches playback directly in the owning app:
```java
String intentUri = cursor.getString(cursor.getColumnIndex(TvContract.WatchNextPrograms.COLUMN_INTENT_URI));
if (intentUri != null) {
    try {
        Intent intent = Intent.parseUri(intentUri, Intent.URI_INTENT_SCHEME);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(intent);
    } catch (Exception e) {
        // Fallback to app launch if deep-link fails
        Intent fallback = getPackageManager().getLeanbackLaunchIntentForPackage(packageName);
        if (fallback != null) startActivity(fallback);
    }
}
```

---

## 4. UI/UX Design & Aesthetic Blueprint

To preserve CleanYourTV's Apple TV minimalist aesthetic:

1. **Tray Placement**:
   - Placed between the Clock/Date header and the App Dock.
   - If no items exist or the switch is OFF, the container is set to `View.GONE` with **zero height and no layout shift**.
2. **Card Dimensions & Styling**:
   - Width: `200dp`, Height: `112dp` (16:9 widescreen thumbnail) with `14dp` rounded corners.
   - Frosted glass background with `R.drawable.glass_panel` or semi-transparent scrim.
   - **App Badge**: Small `16dp` app icon in top-left or top-right corner (Prime Video, Apple TV, etc.) indicating source.
   - **Progress Bar**: Thin `3dp` progress bar along the bottom edge showing `last_playback_position / duration`.
   - **Titles**: One line bold title (`13sp`), one line episode/season subtitle (`10sp`, 60% white).
3. **Focus & Motion**:
   - Focus scale: `1.04x` with subtle white glass stroke.
   - D-pad mapping:
     - Header/pills **DOWN** &rarr; Continue Watching Tray.
     - Tray **DOWN** &rarr; App Dock.
     - App Dock **UP** &rarr; Continue Watching Tray.
     - Tray **UP** &rarr; Header/pills.

---

## 5. Configuration & Off-by-Default Policy

1. **`config.xml`**:
   ```xml
   <!-- Show Continue Watching tray for apps that publish to Android TV's Watch Next table -->
   <bool name="continue_watching">false</bool>
   ```
2. **`Config.java`**:
   - Parses `continue_watching` from `config.xml` and theme JSON.
   - Reads user preference override from `SharedPreferences` (`"continue_watching"`).
3. **`LauncherSettingsActivity.java`**:
   - Dedicated toggle row: `Continue Watching: ON / OFF`.
   - When `false`, zero database queries are made, zero views are inflated, and background overhead remains 0.
