package com.wordpress.brunoloff.meditationtimer

import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.provider.Settings
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var remoteKeysChannel: MethodChannel? = null
    private var remoteMediaSession: MediaSession? = null
    private var remoteAudioFocusRequest: AudioFocusRequest? = null
    private var remoteInputListeningEnabled = false
    private val externalTouchStarts = mutableMapOf<Int, Pair<Float, Float>>()
    private val remoteAudioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        remoteKeysChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RemoteInputEventBridge.channelName,
        ).also { channel ->
            RemoteInputEventBridge.attach(channel)
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setRemoteKeyListeningEnabled" -> {
                        setRemoteMediaSessionActive(
                            call.argument<Boolean>("enabled") == true,
                        )
                        result.success(null)
                    }
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        ensureRemoteMediaSession()
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        RemoteInputEventBridge.forwardKeyEvent("activity", event)
        return super.dispatchKeyEvent(event)
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        RemoteInputEventBridge.forwardMotionEvent("genericMotion", event)
        return super.dispatchGenericMotionEvent(event)
    }

    override fun dispatchTrackballEvent(event: MotionEvent): Boolean {
        RemoteInputEventBridge.forwardMotionEvent("trackball", event)
        return super.dispatchTrackballEvent(event)
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (isExternalTouchEvent(event) && remoteInputListeningEnabled) {
            forwardExternalTouchEvent(event)
            return true
        }

        if (!event.isFromSource(InputDevice.SOURCE_TOUCHSCREEN)) {
            RemoteInputEventBridge.forwardMotionEvent("touch", event)
        }
        return super.dispatchTouchEvent(event)
    }

    override fun onDestroy() {
        abandonRemoteAudioFocus()
        remoteMediaSession?.release()
        remoteMediaSession = null
        RemoteInputEventBridge.detach(remoteKeysChannel)
        remoteKeysChannel = null
        super.onDestroy()
    }

    private fun setRemoteMediaSessionActive(enabled: Boolean) {
        ensureRemoteMediaSession()
        remoteInputListeningEnabled = enabled
        if (!enabled) {
            externalTouchStarts.clear()
        }
        if (enabled) {
            requestRemoteAudioFocus()
        } else {
            abandonRemoteAudioFocus()
        }
        updateRemotePlaybackState(enabled)
        remoteMediaSession?.isActive = enabled
    }

    private fun ensureRemoteMediaSession() {
        if (remoteMediaSession != null) {
            return
        }

        remoteMediaSession = MediaSession(this, "PranayamaRemote").apply {
            @Suppress("DEPRECATION")
            setFlags(
                MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS,
            )
            setMetadata(
                MediaMetadata.Builder()
                    .putString(MediaMetadata.METADATA_KEY_TITLE, "Pranayama remote")
                    .putString(MediaMetadata.METADATA_KEY_ARTIST, "Meditation Timer")
                    .build(),
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                setPlaybackToLocal(remoteAudioAttributes())
            }
            setCallback(object : MediaSession.Callback() {
                override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                    keyEventFromIntent(mediaButtonIntent)?.let { event ->
                        RemoteInputEventBridge.forwardKeyEvent("mediaSession", event)
                    }
                    return true
                }

                override fun onPlay() {
                    RemoteInputEventBridge.forwardSyntheticKeyEvent(
                        "mediaSessionCallback",
                        KeyEvent.KEYCODE_MEDIA_PLAY,
                    )
                }

                override fun onPause() {
                    RemoteInputEventBridge.forwardSyntheticKeyEvent(
                        "mediaSessionCallback",
                        KeyEvent.KEYCODE_MEDIA_PAUSE,
                    )
                }

                override fun onSkipToNext() {
                    RemoteInputEventBridge.forwardSyntheticKeyEvent(
                        "mediaSessionCallback",
                        KeyEvent.KEYCODE_MEDIA_NEXT,
                    )
                }

                override fun onSkipToPrevious() {
                    RemoteInputEventBridge.forwardSyntheticKeyEvent(
                        "mediaSessionCallback",
                        KeyEvent.KEYCODE_MEDIA_PREVIOUS,
                    )
                }

                override fun onFastForward() {
                    RemoteInputEventBridge.forwardSyntheticKeyEvent(
                        "mediaSessionCallback",
                        KeyEvent.KEYCODE_MEDIA_FAST_FORWARD,
                    )
                }

                override fun onRewind() {
                    RemoteInputEventBridge.forwardSyntheticKeyEvent(
                        "mediaSessionCallback",
                        KeyEvent.KEYCODE_MEDIA_REWIND,
                    )
                }

                override fun onStop() {
                    RemoteInputEventBridge.forwardSyntheticKeyEvent(
                        "mediaSessionCallback",
                        KeyEvent.KEYCODE_MEDIA_STOP,
                    )
                }
            })
            updateRemotePlaybackState(false)
        }
    }

    private fun keyEventFromIntent(intent: Intent): KeyEvent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT) as? KeyEvent
        }
    }

    private fun openAccessibilitySettings() {
        startActivity(
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    private fun updateRemotePlaybackState(active: Boolean) {
        remoteMediaSession?.setPlaybackState(
            PlaybackState.Builder()
                .setActions(remotePlaybackActions())
                .setState(
                    if (active) PlaybackState.STATE_PLAYING else PlaybackState.STATE_STOPPED,
                    0L,
                    if (active) 1.0f else 0.0f,
                )
                .build(),
        )
    }

    private fun remotePlaybackActions(): Long {
        return PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_SKIP_TO_NEXT or
            PlaybackState.ACTION_SKIP_TO_PREVIOUS or
            PlaybackState.ACTION_STOP or
            PlaybackState.ACTION_REWIND or
            PlaybackState.ACTION_FAST_FORWARD
    }

    private fun remoteAudioAttributes(): AudioAttributes {
        return AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
    }

    private fun requestRemoteAudioFocus() {
        val audioManager = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = remoteAudioFocusRequest ?: AudioFocusRequest.Builder(
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
            )
                .setAudioAttributes(remoteAudioAttributes())
                .setWillPauseWhenDucked(false)
                .setOnAudioFocusChangeListener(remoteAudioFocusChangeListener)
                .build()
                .also { remoteAudioFocusRequest = it }
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                remoteAudioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
            )
        }
    }

    private fun abandonRemoteAudioFocus() {
        val audioManager = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            remoteAudioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(remoteAudioFocusChangeListener)
        }
    }

    private fun isExternalTouchEvent(event: MotionEvent): Boolean {
        return event.isFromSource(InputDevice.SOURCE_TOUCHSCREEN) &&
            event.device?.isExternal == true
    }

    private fun forwardExternalTouchEvent(event: MotionEvent) {
        val deviceId = event.deviceId
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            externalTouchStarts[deviceId] = Pair(event.x, event.y)
        }

        val start = externalTouchStarts[deviceId]
        RemoteInputEventBridge.forwardMotionEvent(
            "externalTouch",
            event,
            start?.first,
            start?.second,
        )

        if (
            event.actionMasked == MotionEvent.ACTION_UP ||
            event.actionMasked == MotionEvent.ACTION_CANCEL
        ) {
            externalTouchStarts.remove(deviceId)
        }
    }
}
