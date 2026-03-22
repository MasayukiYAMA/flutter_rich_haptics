import 'package:flutter/services.dart';

import 'haptic_capability.dart';
import 'haptic_platform_interface.dart';

/// MethodChannel implementation of [HapticPlatformInterface].
class MethodChannelHaptics extends HapticPlatformInterface {
  /// The method channel used to interact with the native platform.
  final MethodChannel _channel =
      const MethodChannel('flutter_rich_haptics');

  @override
  Future<bool> initialize() async {
    final result = await _channel.invokeMethod<bool>('initialize');
    return result ?? false;
  }

  @override
  Future<void> playPattern(String ahapJson) async {
    await _channel.invokeMethod<void>('playPattern', {'ahap': ahapJson});
  }

  @override
  Future<void> stopAll() async {
    await _channel.invokeMethod<void>('stopAll');
  }

  @override
  Future<HapticCapability> getCapabilities() async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('getCapabilities');
    if (result == null) return HapticCapability.none;
    return HapticCapability.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Future<bool> supportsHaptics() async {
    final result = await _channel.invokeMethod<bool>('supportsHaptics');
    return result ?? false;
  }

  @override
  Future<void> dispose() async {
    await _channel.invokeMethod<void>('dispose');
  }
}
