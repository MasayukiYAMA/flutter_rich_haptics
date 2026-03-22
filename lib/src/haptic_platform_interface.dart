import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'haptic_capability.dart';
import 'method_channel_haptics.dart';

/// Platform interface for flutter_rich_haptics.
abstract class HapticPlatformInterface extends PlatformInterface {
  HapticPlatformInterface() : super(token: _token);

  static final Object _token = Object();

  static HapticPlatformInterface _instance = MethodChannelHaptics();

  /// The default instance of [HapticPlatformInterface] to use.
  static HapticPlatformInterface get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HapticPlatformInterface].
  static set instance(HapticPlatformInterface instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initializes the haptic engine.
  Future<bool> initialize();

  /// Plays a haptic pattern from an AHAP JSON string.
  Future<void> playPattern(String ahapJson);

  /// Stops all currently playing haptic patterns.
  Future<void> stopAll();

  /// Returns the device's haptic capabilities.
  Future<HapticCapability> getCapabilities();

  /// Returns whether the device supports haptic feedback.
  Future<bool> supportsHaptics();

  /// Disposes the haptic engine and releases resources.
  Future<void> dispose();
}
