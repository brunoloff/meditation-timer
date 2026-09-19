package com.wordpress.brunoloff.meditationtimer

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class RemoteInputAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        val currentInfo = serviceInfo ?: AccessibilityServiceInfo()
        currentInfo.flags =
            currentInfo.flags or AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        serviceInfo = currentInfo
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        RemoteInputEventBridge.forwardKeyEvent("accessibility", event)
        return false
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // This service only requests hardware key filtering for the pranayama
        // remote. It deliberately does not inspect screen content.
    }

    override fun onInterrupt() {}
}
