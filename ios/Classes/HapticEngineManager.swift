import Foundation
#if canImport(CoreHaptics)
import CoreHaptics
#endif

/// Manages the lifecycle of a `CHHapticEngine` instance (iOS 13+).
///
/// Handles engine creation, starting, stopping, and automatic recovery via
/// `resetHandler` and `stoppedHandler`.
@available(iOS 13.0, *)
final class HapticEngineManager {

    // MARK: - Properties

    #if canImport(CoreHaptics)
    /// The underlying Core Haptics engine, created lazily on first access.
    private var engine: CHHapticEngine?
    #endif

    /// Whether the engine has been started and is ready for playback.
    private(set) var isRunning = false

    /// A serial queue used to synchronise engine state changes.
    private let queue = DispatchQueue(label: "com.flutterRichHaptics.engineManager")

    // MARK: - Initialisation

    init() {}

    // MARK: - Public API

    /// Creates (if necessary) and starts the haptic engine.
    /// - Returns: `true` if the engine is running after this call.
    @discardableResult
    func start() -> Bool {
        #if canImport(CoreHaptics)
        return queue.sync {
            do {
                if engine == nil {
                    engine = try createEngine()
                }
                try engine?.start()
                isRunning = true
                return true
            } catch {
                NSLog("[FlutterRichHaptics] Failed to start haptic engine: \(error)")
                isRunning = false
                return false
            }
        }
        #else
        return false
        #endif
    }

    /// Stops the haptic engine, releasing audio/haptic resources.
    func stop() {
        #if canImport(CoreHaptics)
        queue.sync {
            engine?.stop(completionHandler: { [weak self] error in
                if let error = error {
                    NSLog("[FlutterRichHaptics] Error stopping engine: \(error)")
                }
                self?.isRunning = false
            })
        }
        #endif
    }

    /// Tears down the current engine and creates a fresh one.
    @discardableResult
    func reset() -> Bool {
        #if canImport(CoreHaptics)
        queue.sync {
            engine?.stop()
            engine = nil
            isRunning = false
        }
        return start()
        #else
        return false
        #endif
    }

    /// Disposes of the engine entirely. Call when the plugin is being torn down.
    func dispose() {
        #if canImport(CoreHaptics)
        queue.sync {
            engine?.stop()
            engine = nil
            isRunning = false
        }
        #endif
    }

    #if canImport(CoreHaptics)
    /// Returns the engine instance, starting it if it is not yet running.
    /// - Throws: If the engine cannot be started.
    func getEngine() throws -> CHHapticEngine {
        return try queue.sync {
            if let engine = engine {
                if !isRunning {
                    try engine.start()
                    isRunning = true
                }
                return engine
            }
            let newEngine = try createEngine()
            try newEngine.start()
            engine = newEngine
            isRunning = true
            return newEngine
        }
    }
    #endif

    // MARK: - Private

    #if canImport(CoreHaptics)
    private func createEngine() throws -> CHHapticEngine {
        let engine = try CHHapticEngine()

        // When the engine encounters a server error or is pre-empted by a
        // higher-priority client, it calls the reset handler. We use this
        // to automatically restart.
        engine.resetHandler = { [weak self] in
            NSLog("[FlutterRichHaptics] Engine reset – restarting")
            guard let self = self else { return }
            do {
                try engine.start()
                self.isRunning = true
            } catch {
                NSLog("[FlutterRichHaptics] Failed to restart engine after reset: \(error)")
                self.isRunning = false
            }
        }

        // Called when the engine is stopped by the system (e.g. app
        // backgrounded, audio session interrupted).
        engine.stoppedHandler = { [weak self] reason in
            NSLog("[FlutterRichHaptics] Engine stopped – reason: \(reason.rawValue)")
            self?.isRunning = false
        }

        // Allow the engine to auto-shutdown when idle and restart on demand
        // to conserve power.
        engine.isAutoShutdownEnabled = true

        // playsHapticsOnly keeps the audio session from being activated,
        // avoiding any interference with background music.
        engine.playsHapticsOnly = true

        return engine
    }
    #endif
}
