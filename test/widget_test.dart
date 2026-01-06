import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:generate_photo/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AppRoot());

    // Verify that loading screen appears
    expect(find.text('Preparing your creative studio...'), findsOneWidget);
  });
}
