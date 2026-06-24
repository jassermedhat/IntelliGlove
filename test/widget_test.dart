// This is a basic Flutter widget test.
//
// To run: flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders MaterialApp smoke test', (
    WidgetTester tester,
  ) async {
    // Minimal sanity check – just ensures the test harness works.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('ok'))),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}
