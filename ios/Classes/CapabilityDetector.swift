import Foundation
import UIKit
#if canImport(CoreHaptics)
import CoreHaptics
#endif

/// Detects the haptic capabilities of the current device.
final class CapabilityDetector {

    /// The tier of haptic support available on this device.
    enum HapticTier: String {
        case none
        case legacy
        case composition
    }

    /// Cached result of capability detection.
    private static var cachedCapability: [String: Any]?

    /// Returns a dictionary describing the device's haptic capabilities.
    ///
    /// Keys:
    /// - `supportsHaptics` (Bool): whether any haptic feedback is available.
    /// - `tier` (String): `"composition"`, `"legacy"`, or `"none"`.
    /// - `deviceInfo` (Dictionary): device model, system version, etc.
    static func detect() -> [String: Any] {
        if let cached = cachedCapability {
            return cached
        }
        let result = performDetection()
        cachedCapability = result
        return result
    }

    /// Whether the device supports Core Haptics composition-level haptics.
    static var supportsHaptics: Bool {
        let cap = detect()
        return cap["supportsHaptics"] as? Bool ?? false
    }

    /// Clears the cached capability result so the next call to `detect()`
    /// re-evaluates. Useful mainly for testing.
    static func clearCache() {
        cachedCapability = nil
    }

    // MARK: - Private

    private static func performDetection() -> [String: Any] {
        let device = UIDevice.current
        let deviceInfo: [String: Any] = [
            "model": device.model,
            "systemVersion": device.systemVersion,
            "name": device.name,
            "machine": machineName(),
        ]

        // Check for Core Haptics (iOS 13+)
        if #available(iOS 13.0, *) {
            #if canImport(CoreHaptics)
            let hapticCapability = CHHapticEngine.capabilitiesForHardware()
            if hapticCapability.supportsHaptics {
                return [
                    "supportsHaptics": true,
                    "tier": HapticTier.composition.rawValue,
                    "deviceInfo": deviceInfo,
                ]
            }
            #endif
        }

        // Fallback: UIFeedbackGenerator is available on iPhones with a
        // Taptic Engine (iPhone 7+). We check that we are running on an
        // iPhone (not iPad/iPod simulators) as a heuristic.
        if device.userInterfaceIdiom == .phone {
            return [
                "supportsHaptics": true,
                "tier": HapticTier.legacy.rawValue,
                "deviceInfo": deviceInfo,
            ]
        }

        return [
            "supportsHaptics": false,
            "tier": HapticTier.none.rawValue,
            "deviceInfo": deviceInfo,
        ]
    }

    /// Returns the hardware machine identifier (e.g. "iPhone14,5").
    private static func machineName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { result, element in
            guard let value = element.value as? Int8, value != 0 else {
                return result
            }
            return result + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
