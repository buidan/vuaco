import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/main.dart';
import 'package:vuaco/presentation/widgets/xiangqi_board_view.dart';

/// End-to-end-ish widget test that drives the actual board via simulated
/// taps (mapped through the same `BoardLayout` the widget itself uses),
/// standing in for manual interaction since this sandbox has no simulator,
/// device, or browser available to click through by hand.
void main() {
  testWidgets('tapping a piece then a destination executes a move and records it in history',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VuacoApp()));
    await tester.pumpAndSettle();

    final boardFinder = find.byType(XiangqiBoardView);
    expect(boardFinder, findsOneWidget);
    final boardBox = tester.renderObject(boardFinder) as RenderBox;
    final layout = BoardLayout.fromSize(boardBox.size);
    final topLeft = boardBox.localToGlobal(Offset.zero);

    Offset globalFor(BoardPoint p) => topLeft + layout.pointToOffset(p);

    // Central Red soldier at (3,4) advances to (4,4).
    await tester.tapAt(globalFor(const BoardPoint(3, 4)));
    await tester.pump();
    await tester.tapAt(globalFor(const BoardPoint(4, 4)));
    await tester.pumpAndSettle();

    expect(find.text("Red's turn"), findsNothing);
    expect(find.text("Black's turn"), findsOneWidget);
    expect(find.textContaining('e3-e4'), findsOneWidget);
  });

  testWidgets('undo reverts a move and restores the turn indicator', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VuacoApp()));
    await tester.pumpAndSettle();

    final boardFinder = find.byType(XiangqiBoardView);
    final boardBox = tester.renderObject(boardFinder) as RenderBox;
    final layout = BoardLayout.fromSize(boardBox.size);
    final topLeft = boardBox.localToGlobal(Offset.zero);
    Offset globalFor(BoardPoint p) => topLeft + layout.pointToOffset(p);

    await tester.tapAt(globalFor(const BoardPoint(3, 4)));
    await tester.pump();
    await tester.tapAt(globalFor(const BoardPoint(4, 4)));
    await tester.pumpAndSettle();
    expect(find.text("Black's turn"), findsOneWidget);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();

    expect(find.text("Red's turn"), findsOneWidget);
    expect(find.textContaining('e3-e4'), findsNothing);
  });
}
