package com.example.flutter_rich_haptics

import android.content.Context
import android.os.Build
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin for rich haptic feedback on Android.
 *
 * Translates AHAP (Apple Haptic and Audio Pattern) JSON descriptions into
 * the best available Android vibration API:
 *
 * - API 30+ with primitive support → VibrationEffect.Composition
 * - API 26-29                      → VibrationEffect.createWaveform
 * - Below API 26                   → Vibrator.vibrate(long[], int)
 *
 * MethodChannel: "flutter_rich_haptics"
 */
class FlutterRichHapticsPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null

    private var capabilityDetector: CapabilityDetector? = null
    private var player: HapticPlayer? = null
    private var initialized = false

    // ------------------------------------------------------------------
    //  FlutterPlugin lifecycle
    // ------------------------------------------------------------------

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_rich_haptics")
        channel.setMethodCallHandler(this)
        applicationContext = flutterPluginBinding.applicationContext
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        disposeResources()
        applicationContext = null
    }

    // ------------------------------------------------------------------
    //  MethodChannel dispatch
    // ------------------------------------------------------------------

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize"      -> handleInitialize(result)
            "playPattern"     -> handlePlayPattern(call, result)
            "stopAll"         -> handleStopAll(result)
            "getCapabilities" -> handleGetCapabilities(result)
            "supportsHaptics" -> handleSupportsHaptics(result)
            "dispose"         -> handleDispose(result)
            else              -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------------
    //  Method handlers
    // ------------------------------------------------------------------

    private fun handleInitialize(result: Result) {
        try {
            val context = applicationContext
            if (context == null) {
                result.error("NO_CONTEXT", "Application context is not available", null)
                return
            }

            val detector = CapabilityDetector(context)
            capabilityDetector = detector

            val vibrator = detector.getVibrator()
            val tier = detector.detectTier()

            player = when (tier) {
                CapabilityDetector.TIER_COMPOSITION -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        CompositionPlayer(vibrator)
                    } else {
                        // Should not happen given tier detection, but be safe
                        createFallbackPlayer(vibrator)
                    }
                }
                CapabilityDetector.TIER_WAVEFORM -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        WaveformPlayer(vibrator)
                    } else {
                        LegacyPlayer(vibrator)
                    }
                }
                CapabilityDetector.TIER_LEGACY -> LegacyPlayer(vibrator)
                else -> null // TIER_NONE — no vibrator
            }

            initialized = true
            result.success(true)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize haptics: ${e.message}", null)
        }
    }

    private fun handlePlayPattern(call: MethodCall, result: Result) {
        if (!initialized) {
            result.error("NOT_INITIALIZED", "Call initialize() before playPattern()", null)
            return
        }

        val ahapJson = call.argument<String>("ahap")
        if (ahapJson == null) {
            result.error("INVALID_ARGS", "Missing 'ahap' argument", null)
            return
        }

        val currentPlayer = player
        if (currentPlayer == null) {
            // No vibrator on this device — silently succeed
            result.success(null)
            return
        }

        try {
            currentPlayer.play(ahapJson)
            result.success(null)
        } catch (e: IllegalArgumentException) {
            result.error("INVALID_AHAP", "Failed to parse AHAP: ${e.message}", null)
        } catch (e: Exception) {
            result.error("PLAY_ERROR", "Failed to play pattern: ${e.message}", null)
        }
    }

    private fun handleStopAll(result: Result) {
        try {
            player?.stop()
            result.success(null)
        } catch (e: Exception) {
            result.error("STOP_ERROR", "Failed to stop haptics: ${e.message}", null)
        }
    }

    private fun handleGetCapabilities(result: Result) {
        try {
            val context = applicationContext
            if (context == null) {
                result.error("NO_CONTEXT", "Application context is not available", null)
                return
            }

            val detector = capabilityDetector ?: CapabilityDetector(context)
            result.success(detector.getCapabilities())
        } catch (e: Exception) {
            result.error("CAPABILITY_ERROR", "Failed to detect capabilities: ${e.message}", null)
        }
    }

    private fun handleSupportsHaptics(result: Result) {
        try {
            val context = applicationContext
            if (context == null) {
                result.error("NO_CONTEXT", "Application context is not available", null)
                return
            }

            val detector = capabilityDetector ?: CapabilityDetector(context)
            result.success(detector.supportsHaptics())
        } catch (e: Exception) {
            result.error("CAPABILITY_ERROR", "Failed to check haptic support: ${e.message}", null)
        }
    }

    private fun handleDispose(result: Result) {
        try {
            disposeResources()
            result.success(null)
        } catch (e: Exception) {
            result.error("DISPOSE_ERROR", "Failed to dispose: ${e.message}", null)
        }
    }

    // ------------------------------------------------------------------
    //  Internal helpers
    // ------------------------------------------------------------------

    private fun disposeResources() {
        try {
            player?.stop()
        } catch (_: Exception) {
            // Best-effort stop on dispose
        }
        player = null
        capabilityDetector = null
        initialized = false
    }

    /**
     * Creates a fallback player when the detected tier does not match the
     * actual API level (should not normally happen).
     */
    private fun createFallbackPlayer(vibrator: android.os.Vibrator): HapticPlayer {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WaveformPlayer(vibrator)
        } else {
            LegacyPlayer(vibrator)
        }
    }
}
