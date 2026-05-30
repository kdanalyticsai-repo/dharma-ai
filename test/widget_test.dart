import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/main.dart';
import 'package:dharma_ai/screens/welcome_screen.dart';

void main() {
  testWidgets('DharmaAI Welcome Screen Mount Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: DharmaApp(),
      ),
    );

    // Verify that the title "DharmaAI" is displayed
    expect(find.text('DharmaAI'), findsOneWidget);
    
    // Verify that the start button "BEGIN YOUR PATH" is displayed
    expect(find.text('BEGIN YOUR PATH'), findsOneWidget);

    // Tap the start button and trigger a frame transition
    await tester.tap(find.text('BEGIN YOUR PATH'));
    await tester.pumpAndSettle();

    // Verify navigation works: we should see "Personalize Your Path"
    expect(find.text('Personalize Your Path'), findsOneWidget);
  });
}
