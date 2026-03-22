import Foundation
import UIKit

/// Fallback haptic player that uses `UIFeedbackGenerator` for devices that
/// do not support Core Haptics (pre-iOS 13, or simulators/iPads without a
/// Taptic Engine).
///
/// It parses the AHAP JSON and performs a best-effort mapping of events to
/// UIKit feedback generators.
final class FeedbackGeneratorFallback {

    // MARK: - Generators (lazily allocated, reused across calls)

    private lazy var lightImpact = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()
    private lazy var selectionGenerator = UISelectionFeedbackGenerator()

    /// Whether a stop has been requested. When `true`, scheduled events are
    /// skipped.
    private var cancelled = false
    private let lock = NSLock()

    // MARK: - Public API

    /// Plays haptic feedback derived from an AHAP JSON string.
    ///
    /// The method parses the JSON, inspects each event, and dispatches
    /// corresponding UIKit feedback calls on a best-effort basis. Events
    /// are scheduled on the main thread with their relative timing
    /// preserved.
    ///
    /// - Parameter ahapJson: A JSON string in AHAP format.
    func play(ahapJson: String) {
        lock.lock()
        cancelled = false
        lock.unlock()

        guard let data = ahapJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let patternArray = json["Pattern"] as? [[String: Any]]
        else {
            // If we cannot parse at all, fire a single medium impact as a
            // best-effort "something happened" signal.
            DispatchQueue.main.async { [weak self] in
                self?.mediumImpact.impactOccurred()
            }
            return
        }

        // First, check if the overall pattern matches a known notification
        // gesture and use UINotificationFeedbackGenerator for it.
        if let notificationType = detectNotificationPattern(patternArray) {
            DispatchQueue.main.async { [weak self] in
                self?.notificationGenerator.notificationOccurred(notificationType)
            }
            return
        }

        // Prepare generators on the main thread before we need them.
        DispatchQueue.main.async { [weak self] in
            self?.lightImpact.prepare()
            self?.mediumImpact.prepare()
            self?.heavyImpact.prepare()
        }

        // Schedule individual events.
        for element in patternArray {
            guard let event = element["Event"] as? [String: Any] else { continue }

            let time = (event["Time"] as? NSNumber)?.doubleValue ?? 0.0
            let eventType = event["EventType"] as? String ?? ""
            let intensity = extractIntensity(from: event)

            let delay = max(0, time)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }

                self.lock.lock()
                let isCancelled = self.cancelled
                self.lock.unlock()
                if isCancelled { return }

                switch eventType {
                case "HapticTransient":
                    self.playTransient(intensity: intensity)
                case "HapticContinuous":
                    // Continuous events are hard to replicate with UIKit
                    // generators. We fire a single impact at the start and
                    // optionally a second one at the end if the duration is
                    // long enough to be perceptible.
                    self.playTransient(intensity: intensity)
                    let duration = (event["EventDuration"] as? NSNumber)?.doubleValue ?? 0.0
                    if duration > 0.15 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                            guard let self = self else { return }
                            self.lock.lock()
                            let cancelled = self.cancelled
                            self.lock.unlock()
                            if !cancelled {
                                self.playTransient(intensity: max(0.1, intensity * 0.6))
                            }
                        }
                    }
                default:
                    // Unknown event type – skip.
                    break
                }
            }
        }
    }

    /// Cancels any scheduled feedback events.
    func stopAll() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    // MARK: - Private helpers

    /// Fires a single transient impact at the given intensity level.
    private func playTransient(intensity: Double) {
        if intensity >= 0.7 {
            heavyImpact.impactOccurred()
        } else if intensity >= 0.35 {
            mediumImpact.impactOccurred()
        } else {
            lightImpact.impactOccurred()
        }
    }

    /// Extracts the `HapticIntensity` parameter value from an event
    /// dictionary. Defaults to 1.0 if absent.
    private func extractIntensity(from event: [String: Any]) -> Double {
        guard let params = event["EventParameters"] as? [[String: Any]] else {
            return 1.0
        }
        for param in params {
            if let id = param["ParameterID"] as? String,
               id == "HapticIntensity",
               let value = (param["ParameterValue"] as? NSNumber)?.doubleValue {
                return value
            }
        }
        return 1.0
    }

    /// Attempts to classify the overall pattern as a notification-style
    /// haptic (success/error/warning).
    ///
    /// Heuristic rules:
    /// - **Success**: Two or three transient events close together with
    ///   increasing intensity.
    /// - **Error**: Three transient events with the middle one strongest
    ///   (a common "buzz-buzz-buzz" failure pattern).
    /// - **Warning**: Two transient events with decreasing intensity.
    ///
    /// If no pattern matches, returns `nil`.
    private func detectNotificationPattern(
        _ patternArray: [[String: Any]]
    ) -> UINotificationFeedbackGenerator.FeedbackType? {
        let events = patternArray.compactMap { $0["Event"] as? [String: Any] }
        let transients = events.filter { ($0["EventType"] as? String) == "HapticTransient" }

        guard transients.count >= 2, transients.count <= 4 else {
            return nil
        }

        // Ensure all events are within a short time window (< 0.8 s),
        // consistent with a notification gesture.
        let times = transients.compactMap { ($0["Time"] as? NSNumber)?.doubleValue }
        guard let minTime = times.min(), let maxTime = times.max(),
              (maxTime - minTime) < 0.8
        else {
            return nil
        }

        let intensities = transients.map { extractIntensity(from: $0) }

        // Success: intensities are non-decreasing and last is high.
        if isNonDecreasing(intensities) && (intensities.last ?? 0) >= 0.7 {
            return .success
        }

        // Error: middle event is the strongest and there are 3 events.
        if intensities.count == 3 {
            let mid = intensities[1]
            if mid >= intensities[0] && mid >= intensities[2] {
                return .error
            }
        }

        // Warning: intensities are non-increasing and first is high.
        if isNonIncreasing(intensities) && (intensities.first ?? 0) >= 0.7 {
            return .warning
        }

        return nil
    }

    private func isNonDecreasing(_ values: [Double]) -> Bool {
        for i in 1..<values.count {
            if values[i] < values[i - 1] - 0.01 { return false }
        }
        return true
    }

    private func isNonIncreasing(_ values: [Double]) -> Bool {
        for i in 1..<values.count {
            if values[i] > values[i - 1] + 0.01 { return false }
        }
        return true
    }
}
