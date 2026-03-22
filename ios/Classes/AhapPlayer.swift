import Foundation
#if canImport(CoreHaptics)
import CoreHaptics
#endif

/// Plays AHAP (Apple Haptic Audio Pattern) data using Core Haptics (iOS 13+).
///
/// Takes an AHAP dictionary (already parsed from JSON on the Dart side),
/// constructs a `CHHapticPattern`, and plays it through the shared
/// `HapticEngineManager`.
@available(iOS 13.0, *)
final class AhapPlayer {

    // MARK: - Errors

    enum AhapPlayerError: Error, LocalizedError {
        case engineUnavailable
        case invalidAhapData(String)
        case playbackFailed(Error)

        var errorDescription: String? {
            switch self {
            case .engineUnavailable:
                return "The haptic engine is not available."
            case .invalidAhapData(let detail):
                return "Invalid AHAP data: \(detail)"
            case .playbackFailed(let underlying):
                return "Haptic playback failed: \(underlying.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private let engineManager: HapticEngineManager

    #if canImport(CoreHaptics)
    /// Keeps a strong reference to currently-active pattern players so
    /// they are not deallocated before finishing playback.
    private var activePlayers: [CHHapticPatternPlayer] = []
    private let playersLock = NSLock()
    #endif

    // MARK: - Initialisation

    init(engineManager: HapticEngineManager) {
        self.engineManager = engineManager
    }

    // MARK: - Public API

    /// Plays an AHAP pattern.
    ///
    /// - Parameter ahapDict: A dictionary representing the AHAP JSON. Must
    ///   contain at least `"Version"` and `"Pattern"` keys.
    /// - Throws: `AhapPlayerError` on failure.
    func play(ahapDict: [String: Any]) throws {
        #if canImport(CoreHaptics)
        let engine = try engineManager.getEngine()

        // Attempt to play using the engine's built-in AHAP support first.
        // CHHapticEngine can play AHAP data directly when provided as
        // serialised Data.
        if let jsonData = try? JSONSerialization.data(withJSONObject: ahapDict, options: []) {
            do {
                try engine.playPattern(from: jsonData)
                return
            } catch {
                // Fall through to manual pattern construction if the engine
                // rejects the data (e.g. unsupported keys). This provides a
                // more resilient path.
                NSLog("[FlutterRichHaptics] engine.playPattern(from:) failed, falling back to manual construction: \(error)")
            }
        }

        // Manual construction from the dictionary.
        let pattern = try buildPattern(from: ahapDict)
        let player = try engine.makePlayer(with: pattern)

        trackPlayer(player)

        try player.start(atTime: CHHapticTimeImmediate)
        #else
        throw AhapPlayerError.engineUnavailable
        #endif
    }

    /// Stops all currently active pattern players.
    func stopAll() {
        #if canImport(CoreHaptics)
        playersLock.lock()
        let players = activePlayers
        activePlayers.removeAll()
        playersLock.unlock()

        for player in players {
            do {
                try player.stop(atTime: CHHapticTimeImmediate)
            } catch {
                // Player may have already finished; that is fine.
            }
        }
        #endif
    }

    // MARK: - Private helpers

    #if canImport(CoreHaptics)
    /// Builds a `CHHapticPattern` from an AHAP dictionary.
    private func buildPattern(from ahap: [String: Any]) throws -> CHHapticPattern {
        guard let patternArray = ahap["Pattern"] as? [[String: Any]] else {
            throw AhapPlayerError.invalidAhapData("Missing or invalid 'Pattern' array.")
        }

        var events: [CHHapticEvent] = []
        var parameterCurves: [CHHapticParameterCurve] = []

        for element in patternArray {
            if let eventDict = element["Event"] as? [String: Any] {
                events.append(try buildEvent(from: eventDict))
            }
            if let curveDict = element["ParameterCurve"] as? [String: Any] {
                if let curve = try? buildParameterCurve(from: curveDict) {
                    parameterCurves.append(curve)
                }
            }
        }

        return try CHHapticPattern(events: events, parameterCurves: parameterCurves)
    }

    /// Converts a single AHAP event dictionary to a `CHHapticEvent`.
    private func buildEvent(from dict: [String: Any]) throws -> CHHapticEvent {
        guard let typeString = dict["EventType"] as? String else {
            throw AhapPlayerError.invalidAhapData("Event missing 'EventType'.")
        }

        let eventType: CHHapticEvent.EventType
        switch typeString {
        case "HapticTransient":
            eventType = .hapticTransient
        case "HapticContinuous":
            eventType = .hapticContinuous
        default:
            throw AhapPlayerError.invalidAhapData("Unknown EventType '\(typeString)'.")
        }

        let time = (dict["Time"] as? NSNumber)?.doubleValue ?? 0.0
        let duration = (dict["EventDuration"] as? NSNumber)?.doubleValue ?? 0.0

        var parameters: [CHHapticEventParameter] = []

        if let paramArray = dict["EventParameters"] as? [[String: Any]] {
            for paramDict in paramArray {
                guard
                    let paramID = paramDict["ParameterID"] as? String,
                    let paramValue = (paramDict["ParameterValue"] as? NSNumber)?.floatValue
                else { continue }

                let dynamicParameterID = hapticEventParameterID(from: paramID)
                if let id = dynamicParameterID {
                    parameters.append(CHHapticEventParameter(parameterID: id, value: paramValue))
                }
            }
        }

        return CHHapticEvent(
            eventType: eventType,
            parameters: parameters,
            relativeTime: time,
            duration: duration
        )
    }

    /// Converts an AHAP ParameterCurve dictionary to a `CHHapticParameterCurve`.
    private func buildParameterCurve(from dict: [String: Any]) throws -> CHHapticParameterCurve {
        guard
            let paramIDString = dict["ParameterID"] as? String,
            let time = (dict["Time"] as? NSNumber)?.doubleValue,
            let controlPoints = dict["ParameterCurveControlPoints"] as? [[String: Any]]
        else {
            throw AhapPlayerError.invalidAhapData("Invalid ParameterCurve structure.")
        }

        let dynamicParamID = hapticDynamicParameterID(from: paramIDString)
        guard let paramID = dynamicParamID else {
            throw AhapPlayerError.invalidAhapData("Unknown ParameterCurve ParameterID '\(paramIDString)'.")
        }

        var curveControlPoints: [CHHapticParameterCurve.ControlPoint] = []
        for cp in controlPoints {
            guard
                let cpTime = (cp["Time"] as? NSNumber)?.doubleValue,
                let cpValue = (cp["ParameterValue"] as? NSNumber)?.floatValue
            else { continue }
            curveControlPoints.append(
                CHHapticParameterCurve.ControlPoint(relativeTime: cpTime, value: cpValue)
            )
        }

        return CHHapticParameterCurve(
            parameterID: paramID,
            controlPoints: curveControlPoints,
            relativeTime: time
        )
    }

    /// Maps an AHAP ParameterID string to a `CHHapticEvent.ParameterID`.
    private func hapticEventParameterID(from string: String) -> CHHapticEvent.ParameterID? {
        switch string {
        case "HapticIntensity":
            return .hapticIntensity
        case "HapticSharpness":
            return .hapticSharpness
        case "AttackTime":
            return .attackTime
        case "DecayTime":
            return .decayTime
        case "ReleaseTime":
            return .releaseTime
        case "Sustained":
            return .sustained
        default:
            return nil
        }
    }

    /// Maps an AHAP ParameterID string to a `CHHapticDynamicParameter.ID`.
    private func hapticDynamicParameterID(from string: String) -> CHHapticDynamicParameter.ID? {
        switch string {
        case "HapticIntensityControl":
            return .hapticIntensityControl
        case "HapticSharpnessControl":
            return .hapticSharpnessControl
        case "HapticAttackTimeControl":
            return .hapticAttackTimeControl
        case "HapticDecayTimeControl":
            return .hapticDecayTimeControl
        case "HapticReleaseTimeControl":
            return .hapticReleaseTimeControl
        default:
            return nil
        }
    }

    /// Tracks a player so it is kept alive during playback.
    private func trackPlayer(_ player: CHHapticPatternPlayer) {
        playersLock.lock()
        activePlayers.append(player)
        playersLock.unlock()

        // Clean up the reference after a generous timeout. Individual AHAP
        // patterns rarely exceed 30 seconds; 60 s gives ample headroom.
        DispatchQueue.global().asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self = self else { return }
            self.playersLock.lock()
            self.activePlayers.removeAll { $0 === player }
            self.playersLock.unlock()
        }
    }
    #endif
}
