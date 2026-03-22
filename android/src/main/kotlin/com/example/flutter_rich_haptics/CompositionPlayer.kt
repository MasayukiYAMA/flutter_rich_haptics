package com.example.flutter_rich_haptics

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.annotation.RequiresApi

/**
 * Haptic player for API 30+ devices that support VibrationEffect.Composition.
 *
 * Uses the composition API to play rich haptic patterns built from primitives
 * such as CLICK, TICK, THUD, SPIN, SLOW_RISE, and QUICK_FALL. This provides
 * the highest-fidelity haptic experience available on Android.
 */
@RequiresApi(Build.VERSION_CODES.R)
class CompositionPlayer(private val vibrator: Vibrator) : HapticPlayer {

    private val translator = AhapTranslator()

    override fun play(ahapJson: String) {
        val events = translator.parseAhap(ahapJson)
        if (events.isEmpty()) return

        val primitives = translator.toCompositionPrimitives(events)
        if (primitives.isEmpty()) return

        val composition = VibrationEffect.startComposition()

        for (primitive in primitives) {
            val frameworkId = mapPrimitiveType(primitive.type)
            composition.addPrimitive(frameworkId, primitive.scale, primitive.delayMs)
        }

        val effect = composition.compose()
        vibrator.vibrate(effect)
    }

    override fun stop() {
        vibrator.cancel()
    }

    override fun isSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false

        @Suppress("DEPRECATION")
        if (!vibrator.hasVibrator()) return false

        return try {
            vibrator.areAllPrimitivesSupported(
                VibrationEffect.Composition.PRIMITIVE_CLICK,
                VibrationEffect.Composition.PRIMITIVE_TICK
            )
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Maps the translator's symbolic [AhapTranslator.PrimitiveType] to the
     * actual VibrationEffect.Composition.PRIMITIVE_* framework constant.
     */
    private fun mapPrimitiveType(type: AhapTranslator.PrimitiveType): Int {
        return when (type) {
            AhapTranslator.PrimitiveType.CLICK      -> VibrationEffect.Composition.PRIMITIVE_CLICK
            AhapTranslator.PrimitiveType.TICK        -> VibrationEffect.Composition.PRIMITIVE_TICK
            AhapTranslator.PrimitiveType.LOW_TICK    -> VibrationEffect.Composition.PRIMITIVE_LOW_TICK
            AhapTranslator.PrimitiveType.THUD        -> VibrationEffect.Composition.PRIMITIVE_THUD
            AhapTranslator.PrimitiveType.SPIN        -> VibrationEffect.Composition.PRIMITIVE_SPIN
            AhapTranslator.PrimitiveType.SLOW_RISE   -> VibrationEffect.Composition.PRIMITIVE_SLOW_RISE
            AhapTranslator.PrimitiveType.QUICK_FALL  -> VibrationEffect.Composition.PRIMITIVE_QUICK_FALL
        }
    }
}
