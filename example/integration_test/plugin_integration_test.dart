import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_rich_haptics/flutter_rich_haptics.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initialize and check capabilities', (WidgetTester tester) async {
    final engine = HapticEngine.instance;
    final result = await engine.initialize();
    expect(result, isTrue);

    final cap = await engine.getCapabilities();
    expect(cap.supportsHaptics, isA<bool>());

    await engine.dispose();
  });

  testWidgets('play preset pattern', (WidgetTester tester) async {
    final engine = HapticEngine.instance;
    await engine.initialize();

    // Should not throw
    await engine.play(HapticPreset.buttonTap);

    await engine.dispose();
  });
}
