package com.wordpress.brunoloff.meditationtimer

import android.os.Build
import android.os.SystemClock
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.plugin.common.MethodChannel

object RemoteInputEventBridge {
    const val channelName = "bruno_meditation_timer/remote_keys"

    private var remoteKeysChannel: MethodChannel? = null

    fun attach(channel: MethodChannel) {
        remoteKeysChannel = channel
    }

    fun detach(channel: MethodChannel?) {
        if (remoteKeysChannel == channel) {
            remoteKeysChannel = null
        }
    }

    fun forwardKeyEvent(origin: String, event: KeyEvent) {
        remoteKeysChannel?.invokeMethod(
            "androidKeyEvent",
            mapOf(
                "origin" to origin,
                "action" to event.action,
                "keyCode" to event.keyCode,
                "keyLabel" to KeyEvent.keyCodeToString(event.keyCode),
                "scanCode" to event.scanCode,
                "repeatCount" to event.repeatCount,
                "deviceId" to event.deviceId,
                "source" to event.source,
                "eventTime" to event.eventTime,
                "downTime" to event.downTime,
            ),
        )
    }

    fun forwardSyntheticKeyEvent(origin: String, keyCode: Int) {
        val now = SystemClock.uptimeMillis()
        remoteKeysChannel?.invokeMethod(
            "androidKeyEvent",
            mapOf(
                "origin" to origin,
                "action" to KeyEvent.ACTION_DOWN,
                "keyCode" to keyCode,
                "keyLabel" to KeyEvent.keyCodeToString(keyCode),
                "scanCode" to 0,
                "repeatCount" to 0,
                "deviceId" to -1,
                "source" to 0,
                "eventTime" to now,
                "downTime" to now,
                "synthetic" to true,
            ),
        )
    }

    fun forwardMotionEvent(
        origin: String,
        event: MotionEvent,
        startX: Float? = null,
        startY: Float? = null,
    ) {
        remoteKeysChannel?.invokeMethod(
            "androidMotionEvent",
            buildMap<String, Any> {
                put("origin", origin)
                put("action", event.actionMasked)
                put("actionLabel", motionActionLabel(event.actionMasked))
                put("deviceId", event.deviceId)
                put("source", event.source)
                put("eventTime", event.eventTime)
                put("downTime", event.downTime)
                put("x", event.x.toDouble())
                put("y", event.y.toDouble())
                put("vscroll", event.getAxisValue(MotionEvent.AXIS_VSCROLL).toDouble())
                put("hscroll", event.getAxisValue(MotionEvent.AXIS_HSCROLL).toDouble())
                put("buttonState", event.buttonState)
                put(
                    "actionButton",
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        event.actionButton
                    } else {
                        0
                    },
                )
                put("pointerCount", event.pointerCount)
                if (startX != null && startY != null) {
                    put("startX", startX.toDouble())
                    put("startY", startY.toDouble())
                    put("deltaX", (event.x - startX).toDouble())
                    put("deltaY", (event.y - startY).toDouble())
                }
            },
        )
    }

    private fun motionActionLabel(action: Int): String {
        return when (action) {
            MotionEvent.ACTION_DOWN -> "down"
            MotionEvent.ACTION_UP -> "up"
            MotionEvent.ACTION_MOVE -> "move"
            MotionEvent.ACTION_CANCEL -> "cancel"
            MotionEvent.ACTION_OUTSIDE -> "outside"
            MotionEvent.ACTION_POINTER_DOWN -> "pointerDown"
            MotionEvent.ACTION_POINTER_UP -> "pointerUp"
            MotionEvent.ACTION_HOVER_MOVE -> "hoverMove"
            MotionEvent.ACTION_SCROLL -> "scroll"
            MotionEvent.ACTION_HOVER_ENTER -> "hoverEnter"
            MotionEvent.ACTION_HOVER_EXIT -> "hoverExit"
            MotionEvent.ACTION_BUTTON_PRESS -> "buttonPress"
            MotionEvent.ACTION_BUTTON_RELEASE -> "buttonRelease"
            else -> "action-$action"
        }
    }
}
