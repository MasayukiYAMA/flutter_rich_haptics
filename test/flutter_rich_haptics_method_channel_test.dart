import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rich_haptics/flutter_rich_haptics.dart';
import 'package:flutter_rich_haptics/src/method_channel_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelHaptics();
  const channel = MethodChannel('flutter_rich_haptics');

  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'initialize':
          return true;
        case 'playPattern':
          return null;
        case 'stopAll':
          return null;
        case 'getCapabilities':
          return {
            'supportsHaptics': true,
            'tier': 'composition',
            'deviceInfo': {'model': 'test'},
          };
        case 'supportsHaptics':
          return true;
        case 'dispose':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize calls method channel', () async {
    final result = await platform.initialize();
    expect(result, true);
    expect(log.last.method, 'initialize');
  });

  test('playPattern sends AHAP JSON', () async {
    final pattern = HapticPreset.success;
    final ahapJson = AhapParser.serialize(pattern);
    await platform.playPattern(ahapJson);
    expect(log.last.method, 'playPattern');
    expect(log.last.arguments['ahap'], ahapJson);
  });

  test('stopAll calls method channel', () async {
    await platform.stopAll();
    expect(log.last.method, 'stopAll');
  });

  test('getCapabilities returns HapticCapability', () async {
    final cap = await platform.getCapabilities();
    expect(cap.supportsHaptics, true);
    expect(cap.tier, HapticTier.composition);
  });

  test('supportsHaptics returns bool', () async {
    final result = await platform.supportsHaptics();
    expect(result, true);
  });

  test('dispose calls method channel', () async {
    await platform.dispose();
    expect(log.last.method, 'dispose');
  });
}
