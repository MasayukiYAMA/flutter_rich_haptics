import 'haptic_capability.dart';
import 'haptic_pattern.dart';
import 'haptic_platform_interface.dart';
import 'ahap_parser.dart';

/// The main entry point for playing haptic patterns.
///
/// This is a singleton that wraps the platform interface and provides
/// convenient methods for playing haptic feedback.
///
/// ```dart
/// final engine = HapticEngine.instance;
/// await engine.initialize();
/// await engine.playPreset(HapticPreset.success);
/// ```
class HapticEngine {
  HapticEngine._();

  static final HapticEngine _instance = HapticEngine._();

  /// The singleton instance.
  static HapticEngine get instance => _instance;

  bool _initialized = false;
  HapticCapability? _cachedCapability;

  /// Whether the engine has been initialized.
  bool get isInitialized => _initialized;

  /// The platform interface to delegate to.
  HapticPlatformInterface get _platform => HapticPlatformInterface.instance;

  /// Initializes the haptic engine. Must be called before playing patterns.
  ///
  /// Returns `true` if initialization succeeded.
  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _platform.initialize();
    return _initialized;
  }

  /// Plays a [HapticPattern].
  ///
  /// Automatically initializes the engine if not already done.
  Future<void> play(HapticPattern pattern) async {
    if (!_initialized) await initialize();
    final ahapJson = AhapParser.serialize(pattern);
    await _platform.playPattern(ahapJson);
  }

  /// Plays a haptic pattern from a raw AHAP JSON string.
  ///
  /// Automatically initializes the engine if not already done.
  Future<void> playAhap(String ahapJson) async {
    if (!_initialized) await initialize();
    await _platform.playPattern(ahapJson);
  }

  /// Stops all currently playing haptic patterns.
  Future<void> stopAll() async {
    await _platform.stopAll();
  }

  /// Returns the device's haptic capabilities.
  Future<HapticCapability> getCapabilities() async {
    _cachedCapability ??= await _platform.getCapabilities();
    return _cachedCapability!;
  }

  /// Returns whether the device supports haptics.
  Future<bool> supportsHaptics() async {
    return _platform.supportsHaptics();
  }

  /// Disposes the haptic engine and releases resources.
  Future<void> dispose() async {
    await _platform.dispose();
    _initialized = false;
    _cachedCapability = null;
  }
}
