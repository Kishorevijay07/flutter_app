// Basic Flutter widget test for HealthAI Monitor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_ai_monitor/main.dart';

void main() {
  testWidgets('HealthAIApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HealthAIApp());

    // Allow any animations/futures to settle.
    await tester.pumpAndSettle();

    // Verify that a MaterialApp is present in the widget tree.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
