package com.example.flutter_rich_haptics

import org.json.JSONObject
import org.json.JSONArray
import kotlin.math.roundToInt
import kotlin.math.max

/**
 * Translates AHAP (Apple Haptic and Audio Pattern) JSON into Android-native
 * vibration representations for three tiers: composition, waveform, and legacy.
 *
 * AHAP is Apple's format for describing complex haptic patterns. This translator
 * parses that format and maps it to the best available Android vibration APIs.
 */
class AhapTranslator {

    // -----------------------------------------------------------------------
    //  Data classes representing parsed AHAP events
    // -----------------------------------------------------------------------

    /**
     * Represents a single haptic event parsed from the AHAP JSON.
     */
    data class HapticEvent(
        val time: Double,          // seconds
        val type: EventType,
        val duration: Double,      // seconds (only meaningful for continuous)
        val intensity: Float,      // 0.0 .. 1.0
        val sharpness: Float       // 0.0 .. 1.0
    )

    enum class EventType {
        TRANSIENT,
        CONTINUOUS
    }

    // -----------------------------------------------------------------------
    //  Composition tier output (API 30+)
    // -----------------------------------------------------------------------

    /**
     * Symbolic names for VibrationEffect.Composition primitives.
     *
     * Using an enum instead of raw int constants avoids duplicating framework
     * constant values in the translator. The mapping to actual framework
     * constants is done in [CompositionPlayer].
     */
    enum class PrimitiveType {
        CLICK,
        TICK,
        LOW_TICK,
        THUD,
        SPIN,
        SLOW_RISE,
        QUICK_FALL
    }

    /**
     * A single primitive to be added to a VibrationEffect.Composition.
     */
    data class CompositionPrimitive(
        val type: PrimitiveType,
        val scale: Float,       // 0.0 .. 1.0
        val delayMs: Int        // delay before this primitive
    )

    // -----------------------------------------------------------------------
    //  Waveform tier output (API 26-29)
    // -----------------------------------------------------------------------

    /**
     * Arrays suitable for VibrationEffect.createWaveform(timings, amplitudes, -1).
     */
    data class WaveformData(
        val timings: LongArray,
        val amplitudes: IntArray
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (other !is WaveformData) return false
            return timings.contentEquals(other.timings) && amplitudes.contentEquals(other.amplitudes)
        }
        override fun hashCode(): Int {
            return 31 * timings.contentHashCode() + amplitudes.contentHashCode()
        }
    }

    // -----------------------------------------------------------------------
    //  Legacy tier output (pre-API 26)
    // -----------------------------------------------------------------------

    /**
     * An on/off pattern for Vibrator.vibrate(long[], -1).
     * The pattern alternates: off, on, off, on, ...
     * The first element is always the initial wait (off) period.
     */
    data class LegacyPattern(
        val pattern: LongArray
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (other !is LegacyPattern) return false
            return pattern.contentEquals(other.pattern)
        }
        override fun hashCode(): Int = pattern.contentHashCode()
    }

    // -----------------------------------------------------------------------
    //  Parsing
    // -----------------------------------------------------------------------

    /**
     * Parses an AHAP JSON string into a sorted list of [HapticEvent]s.
     *
     * @throws IllegalArgumentException on malformed JSON or missing required fields.
     */
    fun parseAhap(ahapJson: String): List<HapticEvent> {
        val root: JSONObject
        try {
            root = JSONObject(ahapJson)
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid AHAP JSON: ${e.message}", e)
        }

        val patternArray: JSONArray = root.optJSONArray("Pattern")
            ?: throw IllegalArgumentException("AHAP JSON missing 'Pattern' array")

        val events = mutableListOf<HapticEvent>()

        for (i in 0 until patternArray.length()) {
            val element = patternArray.getJSONObject(i)

            // We handle "Event" elements; "ParameterCurve" elements are noted
            // but not translated to separate events — their influence is baked
            // into the surrounding events on iOS and we skip them on Android
            // since Android composition primitives don't support real-time
            // parameter modulation.
            if (element.has("Event")) {
                val event = element.getJSONObject("Event")
                val parsed = parseEvent(event)
                if (parsed != null) {
                    events.add(parsed)
                }
            }
            // ParameterCurve elements are intentionally ignored for now.
        }

        return events.sortedBy { it.time }
    }

    private fun parseEvent(event: JSONObject): HapticEvent? {
        val time = event.optDouble("Time", 0.0)
        val eventTypeStr = event.optString("EventType", "")

        val type = when (eventTypeStr) {
            "HapticTransient" -> EventType.TRANSIENT
            "HapticContinuous" -> EventType.CONTINUOUS
            else -> return null // skip unknown event types (e.g. audio events)
        }

        val duration = event.optDouble("EventDuration", 0.0)

        var intensity = 0.5f
        var sharpness = 0.5f

        val params = event.optJSONArray("EventParameters")
        if (params != null) {
            for (j in 0 until params.length()) {
                val param = params.getJSONObject(j)
                when (param.optString("ParameterID")) {
                    "HapticIntensity" -> intensity = param.optDouble("ParameterValue", 0.5).toFloat()
                    "HapticSharpness" -> sharpness = param.optDouble("ParameterValue", 0.5).toFloat()
                }
            }
        }

        return HapticEvent(
            time = time,
            type = type,
            duration = if (type == EventType.CONTINUOUS) max(duration, 0.01) else 0.0,
            intensity = intensity.coerceIn(0f, 1f),
            sharpness = sharpness.coerceIn(0f, 1f)
        )
    }

    // -----------------------------------------------------------------------
    //  Composition translation (API 30+)
    // -----------------------------------------------------------------------

    /**
     * Translates parsed AHAP events into a list of [CompositionPrimitive]s.
     *
     * Primitive selection rules:
     * - Transient, intensity >= 0.7 && sharpness >= 0.5 -> CLICK
     * - Transient, intensity >= 0.7 && sharpness <  0.5 -> THUD
     * - Transient, intensity <  0.7 && sharpness >= 0.5 -> TICK
     * - Transient, intensity <  0.7 && sharpness <  0.5 -> LOW_TICK
     *
     * - Continuous, sharpness >= 0.5 -> SLOW_RISE + QUICK_FALL
     * - Continuous, sharpness <  0.5 -> SPIN (repeated for duration)
     */
    fun toCompositionPrimitives(events: List<HapticEvent>): List<CompositionPrimitive> {
        if (events.isEmpty()) return emptyList()

        val primitives = mutableListOf<CompositionPrimitive>()
        var currentTimeMs = 0L

        for (event in events) {
            val eventTimeMs = (event.time * 1000).toLong()
            val delayMs = max(0L, eventTimeMs - currentTimeMs).toInt()
            val scale = event.intensity.coerceIn(0f, 1f)

            when (event.type) {
                EventType.TRANSIENT -> {
                    val primitiveType = selectTransientPrimitive(event.intensity, event.sharpness)
                    primitives.add(CompositionPrimitive(primitiveType, scale, delayMs))
                    // A transient is essentially instantaneous; advance a small amount
                    currentTimeMs = eventTimeMs + TRANSIENT_DURATION_MS
                }
                EventType.CONTINUOUS -> {
                    if (event.sharpness >= 0.5f) {
                        // Rise and fall
                        primitives.add(CompositionPrimitive(PrimitiveType.SLOW_RISE, scale, delayMs))
                        primitives.add(CompositionPrimitive(PrimitiveType.QUICK_FALL, scale, 0))
                        currentTimeMs = eventTimeMs + (event.duration * 1000).toLong()
                    } else {
                        // Repeated spin for the duration
                        val durationMs = (event.duration * 1000).toLong()
                        val spinCount = max(1, (durationMs / SPIN_DURATION_MS).toInt())
                        for (s in 0 until spinCount) {
                            val d = if (s == 0) delayMs else SPIN_DURATION_MS.toInt()
                            primitives.add(CompositionPrimitive(PrimitiveType.SPIN, scale, d))
                        }
                        currentTimeMs = eventTimeMs + durationMs
                    }
                }
            }
        }

        return primitives
    }

    private fun selectTransientPrimitive(intensity: Float, sharpness: Float): PrimitiveType {
        return when {
            intensity >= 0.7f && sharpness >= 0.5f -> PrimitiveType.CLICK
            intensity >= 0.7f && sharpness < 0.5f  -> PrimitiveType.THUD
            intensity < 0.7f  && sharpness >= 0.5f -> PrimitiveType.TICK
            else                                    -> PrimitiveType.LOW_TICK
        }
    }

    // -----------------------------------------------------------------------
    //  Waveform translation (API 26-29)
    // -----------------------------------------------------------------------

    /**
     * Translates parsed AHAP events into [WaveformData] for
     * VibrationEffect.createWaveform().
     *
     * - Transient events -> 20ms pulse at amplitude = intensity * 255
     * - Continuous events -> durationMs at amplitude = intensity * 255
     * - Gaps between events are filled with 0-amplitude segments.
     */
    fun toWaveform(events: List<HapticEvent>): WaveformData {
        if (events.isEmpty()) return WaveformData(longArrayOf(0L), intArrayOf(0))

        val timings = mutableListOf<Long>()
        val amplitudes = mutableListOf<Int>()
        var currentTimeMs = 0L

        for (event in events) {
            val eventTimeMs = (event.time * 1000).toLong()
            val amplitude = (event.intensity * 255).roundToInt().coerceIn(0, 255)

            // Insert a gap (0 amplitude) if there is time between the current
            // position and this event's start time.
            val gap = eventTimeMs - currentTimeMs
            if (gap > 0) {
                timings.add(gap)
                amplitudes.add(0)
                currentTimeMs = eventTimeMs
            }

            when (event.type) {
                EventType.TRANSIENT -> {
                    val pulseMs = WAVEFORM_TRANSIENT_MS
                    timings.add(pulseMs)
                    amplitudes.add(amplitude)
                    currentTimeMs += pulseMs
                }
                EventType.CONTINUOUS -> {
                    val durationMs = max(1L, (event.duration * 1000).toLong())
                    timings.add(durationMs)
                    amplitudes.add(amplitude)
                    currentTimeMs += durationMs
                }
            }
        }

        return WaveformData(timings.toLongArray(), amplitudes.toIntArray())
    }

    // -----------------------------------------------------------------------
    //  Legacy translation (pre-API 26)
    // -----------------------------------------------------------------------

    /**
     * Translates parsed AHAP events into a [LegacyPattern] suitable for
     * Vibrator.vibrate(long[], -1).
     *
     * The returned array alternates: off, on, off, on, ...
     * The first element is always the initial off period (0 if the first
     * event starts immediately).
     *
     * - Transient events -> 30ms on
     * - Continuous events -> duration in ms on
     */
    fun toLegacyPattern(events: List<HapticEvent>): LegacyPattern {
        if (events.isEmpty()) return LegacyPattern(longArrayOf(0L))

        val pattern = mutableListOf<Long>()
        var currentTimeMs = 0L

        for (event in events) {
            val eventTimeMs = (event.time * 1000).toLong()

            // Off period (gap before this event)
            val gap = max(0L, eventTimeMs - currentTimeMs)
            pattern.add(gap)

            // On period
            val onMs = when (event.type) {
                EventType.TRANSIENT -> LEGACY_TRANSIENT_MS
                EventType.CONTINUOUS -> max(1L, (event.duration * 1000).toLong())
            }
            pattern.add(onMs)

            currentTimeMs = eventTimeMs + onMs
        }

        return LegacyPattern(pattern.toLongArray())
    }

    // -----------------------------------------------------------------------
    //  Constants
    // -----------------------------------------------------------------------

    companion object {
        // Duration assumptions for composition primitives (approximate, in ms)
        private const val TRANSIENT_DURATION_MS = 10L
        private const val SPIN_DURATION_MS = 100L

        // Waveform transient pulse width
        private const val WAVEFORM_TRANSIENT_MS = 20L

        // Legacy transient on-time
        private const val LEGACY_TRANSIENT_MS = 30L
    }
}
