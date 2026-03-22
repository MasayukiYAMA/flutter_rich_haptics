package com.example.flutter_rich_haptics

import android.content.Context
import android.os.Build
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Detects the haptic capabilities of the current Android device.
 *
 * Determines the best vibration tier available based on the API level and
 * hardware support, and provides detailed device information.
 */
class CapabilityDetector(private val context: Context) {

    companion object {
        const val TIER_NONE = "none"
        const val TIER_LEGACY = "legacy"
        const val TIER_WAVEFORM = "waveform"
        const val TIER_COMPOSITION = "composition"
    }

    private val vibrator: Vibrator by lazy { obtainVibrator() }

    /**
     * Returns the vibration tier for the current device.
     *
     * - "composition" — API 30+ with primitive composition support
     * - "waveform"    — API 26-29, supports VibrationEffect waveforms
     * - "legacy"      — below API 26, uses Vibrator.vibrate(long[], int)
     * - "none"        — no vibrator hardware present
     */
    fun detectTier(): String {
        if (!hasVibrator()) {
            return TIER_NONE
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (hasPrimitivesSupport()) {
                return TIER_COMPOSITION
            }
            // API 30+ but no primitive support falls through to waveform
            return TIER_WAVEFORM
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return TIER_WAVEFORM
        }

        return TIER_LEGACY
    }

    /**
     * Returns whether the device has any haptic feedback capability.
     */
    fun supportsHaptics(): Boolean {
        return hasVibrator()
    }

    /**
     * Returns a map of capability information suitable for returning to Dart.
     */
    fun getCapabilities(): Map<String, Any> {
        val tier = detectTier()
        return mapOf(
            "supportsHaptics" to supportsHaptics(),
            "tier" to tier,
            "deviceInfo" to getDeviceInfo()
        )
    }

    /**
     * Returns detailed device information relevant to haptic capability.
     */
    fun getDeviceInfo(): Map<String, Any> {
        return mapOf(
            "apiLevel" to Build.VERSION.SDK_INT,
            "hasVibrator" to hasVibrator(),
            "hasPrimitivesSupport" to hasPrimitivesSupport()
        )
    }

    private fun hasVibrator(): Boolean {
        @Suppress("DEPRECATION")
        return vibrator.hasVibrator()
    }

    private fun hasPrimitivesSupport(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return false
        }
        return try {
            // Check for the two core primitives used by AhapTranslator.
            // These constants are accessed only when API >= R, so this is safe.
            vibrator.areAllPrimitivesSupported(
                android.os.VibrationEffect.Composition.PRIMITIVE_CLICK,
                android.os.VibrationEffect.Composition.PRIMITIVE_TICK
            )
        } catch (e: Exception) {
            false
        }
    }

    private fun obtainVibrator(): Vibrator {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
                ?: @Suppress("DEPRECATION") (context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator)
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    /**
     * Provides access to the system vibrator for use by players.
     */
    fun getVibrator(): Vibrator = vibrator
}
