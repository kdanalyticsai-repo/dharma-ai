import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dharma_ai/main.dart';

void main() {
  testWidgets('DharmaAI app launches without crashing', (WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        child: DharmaApp(navigatorKey: navigatorKey),
      ),
    );
    // App mounted without throwing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
