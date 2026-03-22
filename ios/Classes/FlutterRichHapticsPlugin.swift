import Flutter
import UIKit
#if canImport(CoreHaptics)
import CoreHaptics
#endif

/// Flutter plugin that exposes rich haptic feedback capabilities on iOS.
///
/// On iOS 13+ devices with Core Haptics support, AHAP patterns are played
/// through `CHHapticEngine` via `AhapPlayer`. On older devices or those
/// without a Taptic Engine, `FeedbackGeneratorFallback` provides a
/// best-effort mapping to UIKit feedback generators.
public class FlutterRichHapticsPlugin: NSObject, FlutterPlugin {

    // MARK: - Properties

    /// Engine manager – only allocated on iOS 13+.
    private var engineManager: Any? // HapticEngineManager (iOS 13+)

    /// AHAP player – only allocated on iOS 13+.
    private var ahapPlayer: Any? // AhapPlayer (iOS 13+)

    /// Fallback generator for legacy devices.
    private lazy var fallback = FeedbackGeneratorFallback()

    /// Whether `initialize` has been called successfully.
    private var isInitialized = false

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_rich_haptics",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterRichHapticsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Method channel handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "initialize":
            handleInitialize(result: result)

        case "playPattern":
            handlePlayPattern(call: call, result: result)

        case "stopAll":
            handleStopAll(result: result)

        case "getCapabilities":
            handleGetCapabilities(result: result)

        case "supportsHaptics":
            handleSupportsHaptics(result: result)

        case "dispose":
            handleDispose(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Method implementations

    private func handleInitialize(result: @escaping FlutterResult) {
        if #available(iOS 13.0, *) {
            let capabilities = CapabilityDetector.detect()
            let tier = capabilities["tier"] as? String ?? "none"

            if tier == "composition" {
                let manager = HapticEngineManager()
                let started = manager.start()
                engineManager = manager
                ahapPlayer = AhapPlayer(engineManager: manager)
                isInitialized = started
                result(started)
                return
            }
        }

        // Legacy or no-haptics path. We can still initialise successfully;
        // playback will go through the fallback.
        let hasAnySupport = CapabilityDetector.supportsHaptics
        isInitialized = hasAnySupport
        result(hasAnySupport)
    }

    private func handlePlayPattern(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let ahapJson = args["ahap"] as? String
        else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "playPattern requires a 'ahap' string argument.",
                details: nil
            ))
            return
        }

        guard isInitialized else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Call initialize() before playPattern().",
                details: nil
            ))
            return
        }

        // Try Core Haptics path first (iOS 13+).
        if #available(iOS 13.0, *), let player = ahapPlayer as? AhapPlayer {
            // Parse the JSON string into a dictionary for AhapPlayer.
            guard let data = ahapJson.data(using: .utf8),
                  let ahapDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                result(FlutterError(
                    code: "INVALID_AHAP",
                    message: "Failed to parse AHAP JSON string.",
                    details: nil
                ))
                return
            }

            do {
                try player.play(ahapDict: ahapDict)
                result(nil)
            } catch {
                // If Core Haptics fails at runtime (e.g. simulator),
                // fall through to the legacy path.
                NSLog("[FlutterRichHaptics] Core Haptics playback failed, using fallback: \(error)")
                fallback.play(ahapJson: ahapJson)
                result(nil)
            }
            return
        }

        // Legacy fallback.
        fallback.play(ahapJson: ahapJson)
        result(nil)
    }

    private func handleStopAll(result: @escaping FlutterResult) {
        if #available(iOS 13.0, *), let player = ahapPlayer as? AhapPlayer {
            player.stopAll()
        }
        fallback.stopAll()
        result(nil)
    }

    private func handleGetCapabilities(result: @escaping FlutterResult) {
        result(CapabilityDetector.detect())
    }

    private func handleSupportsHaptics(result: @escaping FlutterResult) {
        result(CapabilityDetector.supportsHaptics)
    }

    private func handleDispose(result: @escaping FlutterResult) {
        if #available(iOS 13.0, *), let player = ahapPlayer as? AhapPlayer {
            player.stopAll()
        }
        fallback.stopAll()

        if #available(iOS 13.0, *), let manager = engineManager as? HapticEngineManager {
            manager.dispose()
        }

        engineManager = nil
        ahapPlayer = nil
        isInitialized = false

        result(nil)
    }
}
