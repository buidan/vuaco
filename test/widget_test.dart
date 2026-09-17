import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vuaco/main.dart';

void main() {
  testWidgets('Pass & Play screen loads with the starting position', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VuacoApp()));
    await tester.pumpAndSettle();

    expect(find.text('Cờ Tướng - Pass & Play'), findsOneWidget);
    expect(find.text("Red's turn"), findsOneWidget);
    // Both back-rank generals should be on the board at kickoff.
    expect(find.text('帥'), findsOneWidget);
    expect(find.text('將'), findsOneWidget);
  });
}
