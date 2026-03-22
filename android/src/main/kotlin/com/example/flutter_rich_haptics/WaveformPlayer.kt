package com.example.flutter_rich_haptics

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.annotation.RequiresApi

/**
 * Haptic player for API 26-29 devices using VibrationEffect.createWaveform().
 *
 * Translates AHAP patterns into timed amplitude waveforms. While less
 * expressive than the composition API, waveforms still allow control over
 * amplitude and timing for each segment of the pattern.
 */
@RequiresApi(Build.VERSION_CODES.O)
class WaveformPlayer(private val vibrator: Vibrator) : HapticPlayer {

    private val translator = AhapTranslator()

    override fun play(ahapJson: String) {
        val events = translator.parseAhap(ahapJson)
        if (events.isEmpty()) return

        val waveform = translator.toWaveform(events)
        if (waveform.timings.isEmpty()) return

        // -1 means do not repeat
        val effect = VibrationEffect.createWaveform(
            waveform.timings,
            waveform.amplitudes,
            -1
        )
        vibrator.vibrate(effect)
    }

    override fun stop() {
        vibrator.cancel()
    }

    override fun isSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false

        @Suppress("DEPRECATION")
        return vibrator.hasVibrator()
    }
}
