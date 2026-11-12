# CleanYourTV: YouTube Music Media Player Widget & Live Lyrics Specification

This document archives the complete design, code, architecture, and deployment steps for the **Top Bar Media Player Widget & Live Synchronized Lyrics Drawer**, in case it needs to be rebuilt or adapted in future sessions.

---

## 1. Feature Overview & Architecture

### A. The Components
1. **Media Capsule (`activity_main.xml`)**:
   - A frosted-glass pill (`height="38dp"`, `radius="19dp"`, background `#2E1C1C26` with `1dp` white border `#33FFFFFF`).
   - Sits in the center of the top bar between the clock/date block and the top status pills.
   - Contains:
     - 26dp Album Artwork thumbnail (`mediaArt`)
     - Scrolling marquee track title (`mediaTitle`, 11sp white) & artist (`mediaArtist`, 9.5sp `#99FFFFFF`)
     - Skip Previous button (`btnMediaPrev`, `ic_media_prev`)
     - Play / Pause toggle button (`btnMediaPlayPause`, `ic_media_play` / `ic_media_pause`)
     - Skip Next button (`btnMediaNext`, `ic_media_next`)
     - Lyrics drawer expand button (`btnMediaLyrics`, `ic_lyrics`)

2. **Synchronized Lyrics Drawer (`LyricsPopup.java`, `popup_lyrics.xml`)**:
   - Floating Apple TV frosted-glass dropdown (`480dp × 340dp`) anchored directly beneath the media capsule.
   - Includes real-time track progress bar with elapsed & total duration (`01:24 / 03:45`).
   - Millisecond-precise synchronized lyrics parser ([LRCLIB API](https://lrclib.net)) that highlights the active lyric line in luminous bold white (`1.06x` scale) and dims inactive lines (45% opacity).
   - Auto-scrolls smoothly so the current singing line remains centered in the viewport.
   - Remote D-pad allows manual browsing through the full lyric text; dismissible with remote `BACK`.

3. **Background Media Session Bridge (`MediaNotificationListenerService.java`)**:
   - Extends Android `NotificationListenerService` with permission `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE`.
   - Authorized permanently on Android TV 11 via ADB:
     ```bash
     cmd notification allow_listener com.gathin.tvhome/.MediaNotificationListenerService
     ```
   - Connects to Android's `MediaSessionManager` to hook into active `MediaController`s, reading live `MediaMetadata` and dispatching transport controls (`play()`, `pause()`, `skipToNext()`, `skipToPrevious()`).

---

## 2. Platform Limitation: Why Official Android TV YouTube Music Cannot Play in Background

During live deployment and testing on the Mi TV 4A (`MiTV-AXFR1`, Android 11), we verified the exact technical reason why YouTube Music cannot play headlessly from a TV widget:

1. **Mobile vs. Android TV Architecture**:
   - **On Mobile Phones**: YouTube Music runs an independent Android background service (`MediaBrowserService`). It continues streaming audio headlessly when the screen changes or when controlled from home screen widgets.
   - **On Android TV**: Google developed `com.google.android.youtube.tvmusic` as a full-screen Leanback / Cobalt web video player. It has **no background audio service**.
2. **Activity Lifecycle Clamping**:
   - Because it is an Activity without a background audio daemon, the moment you press the TV remote's **HOME** button to return to CleanYourTV, Android TV halts the app (`Activity.onStop()`). Cobalt immediately tears down the audio pipeline and destroys the `MediaSession`.
   - Even with YouTube Premium, Google has **never enabled background audio playback in the Android TV YouTube/YouTube Music app**.
3. **What Apps DO Work With This Widget**:
   - Apps that maintain a true background audio daemon on Android TV (e.g. **Spotify**, **Apple Music**, **Tidal**) work with this widget architecture while you remain on the CleanYourTV home screen.
   - For YouTube Music specifically, headless background streaming would require an in-launcher audio player (e.g. using ExoPlayer with open stream extraction like Piped or Invidious) rather than the official closed Google client.

---

## 3. Full Implementation Source Code Archive

### A. Manifest Declaration (`AndroidManifest.xml`)
```xml
<service
    android:name=".MediaNotificationListenerService"
    android:exported="true"
    android:label="@string/media_widget_label"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

### B. Media Service (`MediaNotificationListenerService.java`)
```java
package com.gathin.tvhome;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.media.MediaMetadata;
import android.media.session.MediaController;
import android.media.session.MediaSessionManager;
import android.media.session.PlaybackState;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.service.notification.NotificationListenerService;
import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.List;

public class MediaNotificationListenerService extends NotificationListenerService {
    public static final String YTM_PACKAGE = "com.google.android.youtube.tvmusic";
    private static volatile MediaNotificationListenerService sInstance;
    private static final List<WeakReference<MediaListener>> sListeners = new ArrayList<>();

    public interface MediaListener {
        void onSessionStateChanged(boolean hasActiveSession, String packageName);
        void onMetadataChanged(String title, String artist, String album, Bitmap art, String artUri, long duration);
        void onPlaybackStateChanged(boolean isPlaying, long positionMs, float speed);
    }

    private MediaSessionManager mSessionManager;
    private MediaController mActiveController;
    private final Handler mMainHandler = new Handler(Looper.getMainLooper());

    private final MediaSessionManager.OnActiveSessionsChangedListener mSessionsListener =
            controllers -> mMainHandler.post(() -> resolveActiveController(controllers));

    private final MediaController.Callback mControllerCallback = new MediaController.Callback() {
        @Override public void onPlaybackStateChanged(PlaybackState state) { mMainHandler.post(() -> dispatchPlaybackState(state)); }
        @Override public void onMetadataChanged(MediaMetadata metadata) { mMainHandler.post(() -> dispatchMetadata(metadata)); }
        @Override public void onSessionDestroyed() { mMainHandler.post(() -> { mActiveController = null; refreshSessions(); }); }
    };

    public static MediaNotificationListenerService getInstance() { return sInstance; }
    public static void addListener(MediaListener l) { synchronized (sListeners) { sListeners.add(new WeakReference<>(l)); } }
    public static void removeListener(MediaListener l) { synchronized (sListeners) { sListeners.removeIf(ref -> ref.get() == null || ref.get() == l); } }

    @Override public void onCreate() { super.onCreate(); sInstance = this; }
    @Override public void onListenerConnected() {
        sInstance = this;
        mSessionManager = (MediaSessionManager) getSystemService(Context.MEDIA_SESSION_SERVICE);
        if (mSessionManager != null) {
            ComponentName comp = new ComponentName(this, MediaNotificationListenerService.class);
            mSessionManager.addOnActiveSessionsChangedListener(mSessionsListener, comp);
            refreshSessions();
        }
    }
    @Override public void onListenerDisconnected() { cleanupController(); }
    @Override public void onDestroy() { super.onDestroy(); cleanupController(); sInstance = null; }

    public void refreshSessions() {
        if (mSessionManager == null) return;
        try {
            ComponentName comp = new ComponentName(this, MediaNotificationListenerService.class);
            resolveActiveController(mSessionManager.getActiveSessions(comp));
        } catch (SecurityException ignored) {}
    }

    private void resolveActiveController(List<MediaController> controllers) {
        MediaController candidate = null;
        if (controllers != null && !controllers.isEmpty()) {
            for (MediaController c : controllers) {
                PlaybackState st = c.getPlaybackState();
                if (st != null && st.getState() == PlaybackState.STATE_PLAYING) { candidate = c; break; }
            }
            if (candidate == null) candidate = controllers.get(0);
        }
        if (candidate != mActiveController) {
            cleanupController();
            mActiveController = candidate;
            if (mActiveController != null) {
                mActiveController.registerCallback(mControllerCallback, mMainHandler);
                dispatchSessionState(true, mActiveController.getPackageName());
                dispatchMetadata(mActiveController.getMetadata());
                dispatchPlaybackState(mActiveController.getPlaybackState());
            } else {
                dispatchSessionState(false, null);
            }
        }
    }

    private void cleanupController() {
        if (mActiveController != null) {
            try { mActiveController.unregisterCallback(mControllerCallback); } catch (Exception ignored) {}
            mActiveController = null;
        }
    }

    public static void play() { if (sInstance != null && sInstance.mActiveController != null) sInstance.mActiveController.getTransportControls().play(); }
    public static void pause() { if (sInstance != null && sInstance.mActiveController != null) sInstance.mActiveController.getTransportControls().pause(); }
    public static void togglePlayPause() {
        if (sInstance != null && sInstance.mActiveController != null) {
            PlaybackState st = sInstance.mActiveController.getPlaybackState();
            if (st != null && st.getState() == PlaybackState.STATE_PLAYING) pause(); else play();
        }
    }
    public static void skipToNext() { if (sInstance != null && sInstance.mActiveController != null) sInstance.mActiveController.getTransportControls().skipToNext(); }
    public static void skipToPrevious() { if (sInstance != null && sInstance.mActiveController != null) sInstance.mActiveController.getTransportControls().skipToPrevious(); }
    public static boolean hasActiveSession() { return sInstance != null && sInstance.mActiveController != null; }
    public static boolean isPlaying() {
        if (sInstance != null && sInstance.mActiveController != null) {
            PlaybackState st = sInstance.mActiveController.getPlaybackState();
            return st != null && st.getState() == PlaybackState.STATE_PLAYING;
        }
        return false;
    }
    public static long getCurrentPosition() {
        if (sInstance != null && sInstance.mActiveController != null) {
            PlaybackState st = sInstance.mActiveController.getPlaybackState();
            if (st != null) {
                long pos = st.getPosition();
                if (st.getState() == PlaybackState.STATE_PLAYING) {
                    pos += (long) ((SystemClock.elapsedRealtime() - st.getLastPositionUpdateTime()) * st.getPlaybackSpeed());
                }
                return Math.max(0, pos);
            }
        }
        return 0;
    }
    public static long getDuration() {
        if (sInstance != null && sInstance.mActiveController != null) {
            MediaMetadata md = sInstance.mActiveController.getMetadata();
            if (md != null) return md.getLong(MediaMetadata.METADATA_KEY_DURATION);
        }
        return 0;
    }
    public static String getCurrentTitle() {
        if (sInstance != null && sInstance.mActiveController != null) {
            MediaMetadata md = sInstance.mActiveController.getMetadata();
            if (md != null) return md.getString(MediaMetadata.METADATA_KEY_TITLE);
        }
        return null;
    }
    public static String getCurrentArtist() {
        if (sInstance != null && sInstance.mActiveController != null) {
            MediaMetadata md = sInstance.mActiveController.getMetadata();
            if (md != null) return md.getString(MediaMetadata.METADATA_KEY_ARTIST);
        }
        return null;
    }
    public static Bitmap getCurrentArt() {
        if (sInstance != null && sInstance.mActiveController != null) {
            MediaMetadata md = sInstance.mActiveController.getMetadata();
            if (md != null) {
                Bitmap art = md.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART);
                if (art == null) art = md.getBitmap(MediaMetadata.METADATA_KEY_ART);
                return art;
            }
        }
        return null;
    }
    public static void launchMusicApp(Context context) {
        if (context == null) return;
        Intent intent = context.getPackageManager().getLeanbackLaunchIntentForPackage(YTM_PACKAGE);
        if (intent == null) intent = context.getPackageManager().getLaunchIntentForPackage(YTM_PACKAGE);
        if (intent != null) { intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); context.startActivity(intent); }
    }
    private void dispatchSessionState(boolean hasSession, String pkg) {
        synchronized (sListeners) { for (WeakReference<MediaListener> ref : sListeners) { MediaListener l = ref.get(); if (l != null) l.onSessionStateChanged(hasSession, pkg); } }
    }
    private void dispatchMetadata(MediaMetadata md) {
        synchronized (sListeners) {
            for (WeakReference<MediaListener> ref : sListeners) {
                MediaListener l = ref.get();
                if (l != null) {
                    if (md == null) l.onMetadataChanged(null, null, null, null, null, 0);
                    else l.onMetadataChanged(md.getString(MediaMetadata.METADATA_KEY_TITLE), md.getString(MediaMetadata.METADATA_KEY_ARTIST), md.getString(MediaMetadata.METADATA_KEY_ALBUM), md.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART), md.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI), md.getLong(MediaMetadata.METADATA_KEY_DURATION));
                }
            }
        }
    }
    private void dispatchPlaybackState(PlaybackState st) {
        synchronized (sListeners) {
            for (WeakReference<MediaListener> ref : sListeners) {
                MediaListener l = ref.get();
                if (l != null) {
                    if (st == null) l.onPlaybackStateChanged(false, 0, 1.0f);
                    else l.onPlaybackStateChanged(st.getState() == PlaybackState.STATE_PLAYING, st.getPosition(), st.getPlaybackSpeed());
                }
            }
        }
    }
}
```

### C. Lyrics Engine (`LyricsService.java`)
- REST Query: `https://lrclib.net/api/get?track_name=...&artist_name=...&duration=...`
- Regex Parser for LRC timestamps: `^\\[(\\d{2}):(\\d{2})(?:\\.(\\d{2,3}))?\\](.*)$`
- Binary Search active line resolver: `findActiveIndex(long positionMs)`.

### D. Lyrics Popup Drawer (`LyricsPopup.java`)
- Smooth vertical `ScrollView` centered on anchor.
- 250ms tick loop querying `MediaNotificationListenerService.getCurrentPosition()`.
- Updates `lyricsProgressBar` (`00:00` / `03:45`) and highlights active lyric with `1.06x` scale and luminous white opacity.

---

## 4. Re-enabling in the Future

If you ever wish to re-enable this feature (for instance, with Spotify or another background media player):
1. Restore the Java files from this spec into `com.gathin.tvhome`.
2. Add `<bool name="media_widget">true</bool>` in `config.xml`.
3. Add the `mediaWidget` container into `activity_main.xml`.
4. Re-grant listener access over ADB:
   ```powershell
   tools\venv\Scripts\python.exe tools\tv.py 'cmd notification allow_listener com.gathin.tvhome/.MediaNotificationListenerService'
   ```
