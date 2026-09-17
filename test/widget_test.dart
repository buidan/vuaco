import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vuaco/main.dart';

void main() {
  testWidgets('Home screen offers Pass & Play and Play Online', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VuacoApp()));
    await tester.pumpAndSettle();

    expect(find.text('Cờ Tướng Master'), findsOneWidget);
    expect(find.text('Pass & Play'), findsOneWidget);
    expect(find.text('Play Online'), findsOneWidget);
  });

  testWidgets('Pass & Play screen loads with the starting position', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VuacoApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Pass & Play'));
    await tester.pumpAndSettle();

    expect(find.text('Cờ Tướng - Pass & Play'), findsOneWidget);
    expect(find.text("Red's turn"), findsOneWidget);
    // Both back-rank generals should be on the board at kickoff.
    expect(find.text('帥'), findsOneWidget);
    expect(find.text('將'), findsOneWidget);
  });
}
