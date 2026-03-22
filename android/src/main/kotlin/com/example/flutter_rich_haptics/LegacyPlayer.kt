package com.example.flutter_rich_haptics

import android.os.Vibrator

/**
 * Haptic player for devices below API 26 using the legacy Vibrator.vibrate(long[], int) API.
 *
 * This provides the most basic haptic experience: on/off pulse patterns without
 * amplitude control. Transient events become short 30ms pulses and continuous
 * events become sustained vibrations for the specified duration.
 */
class LegacyPlayer(private val vibrator: Vibrator) : HapticPlayer {

    private val translator = AhapTranslator()

    override fun play(ahapJson: String) {
        val events = translator.parseAhap(ahapJson)
        if (events.isEmpty()) return

        val legacy = translator.toLegacyPattern(events)
        if (legacy.pattern.isEmpty()) return

        // -1 means do not repeat
        @Suppress("DEPRECATION")
        vibrator.vibrate(legacy.pattern, -1)
    }

    override fun stop() {
        vibrator.cancel()
    }

    override fun isSupported(): Boolean {
        @Suppress("DEPRECATION")
        return vibrator.hasVibrator()
    }
}
