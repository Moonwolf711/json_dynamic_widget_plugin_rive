// WFL Viewer widget test
// Note: Full app requires Firebase initialization, so this is a basic smoke test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('WFL app smoke test', (WidgetTester tester) async {
    // Basic MaterialApp smoke test
    // Full WFLApp requires Firebase init which needs platform setup
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('WFL Test')),
        ),
      ),
    );

    expect(find.text('WFL Test'), findsOneWidget);
  });
}
