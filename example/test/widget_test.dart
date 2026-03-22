import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rich_haptics_example/main.dart';

void main() {
  testWidgets('App renders demo page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Rich Haptics Demo'), findsOneWidget);
  });
}
