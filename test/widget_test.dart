// Basic widget tests for PlaySpace shared widgets that don't require Firebase.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:playspace/app/theme.dart';
import 'package:playspace/shared/widgets/app_button.dart';
import 'package:playspace/shared/widgets/error_state_widget.dart';

void main() {
  testWidgets('AppButton shows its label', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: AppButton(label: 'Play', onPressed: () => tapped = true),
      ),
    ));

    expect(find.text('Play'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(tapped, isTrue);
  });

  testWidgets('ErrorStateWidget shows message and retry', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErrorStateWidget(message: 'Oops', onRetry: () {}),
      ),
    ));

    expect(find.text('Oops'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
