import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/main.dart';
import 'package:vuaco/presentation/widgets/board_editor_view.dart';
import 'package:vuaco/presentation/widgets/xiangqi_board_view.dart';

Future<void> _openBoardSetup(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: VuacoApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(OutlinedButton, 'Set Up Position'));
  await tester.pumpAndSettle();
}

/// The piece palette also renders one of every glyph, so board-content
/// assertions on the setup screen must scope to the board itself.
Finder _onBoard(String glyph) => find.descendant(of: find.byType(BoardEditorView), matching: find.text(glyph));

void main() {
  testWidgets('pasting a FEN and starting the game loads that position into Pass & Play', (tester) async {
    await _openBoardSetup(tester);

    // A sparse custom position: just the two generals (off-column from each
    // other, so this isn't also a flying-general check), Black to move.
    await tester.enterText(find.byType(TextField).first, '3k5/9/9/9/9/9/9/9/9/4K4 b - - 0 1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Load'));
    await tester.pumpAndSettle();

    expect(_onBoard('帥'), findsOneWidget); // the loaded Red general
    expect(_onBoard('將'), findsOneWidget); // the loaded Black general
    expect(_onBoard('俥'), findsNothing); // standard-position pieces are gone

    await tester.tap(find.widgetWithText(ElevatedButton, 'Play from this position'));
    await tester.pumpAndSettle();

    expect(find.text('Cờ Tướng - Pass & Play'), findsOneWidget);
    expect(find.text("Black's turn"), findsOneWidget);
    expect(find.text('帥'), findsOneWidget); // no palette on this screen, so unscoped is fine
    expect(find.text('將'), findsOneWidget);
  });

  testWidgets('a malformed FEN shows an error and does not change the board', (tester) async {
    await _openBoardSetup(tester);

    await tester.enterText(find.byType(TextField).first, 'not a fen');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Load'));
    await tester.pumpAndSettle();

    expect(_onBoard('帥'), findsOneWidget); // still the standard starting position
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('FEN'), findsWidgets); // the inline error mentions the FEN
  });

  testWidgets('the play button is blocked with an error when a general is missing', (tester) async {
    await _openBoardSetup(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear board'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Play from this position'));
    await tester.pump(); // let the SnackBar animate in
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('general'), findsWidgets);
    // Still on the setup screen, not navigated to Pass & Play.
    expect(find.text('Set Up Position'), findsOneWidget);
  });

  testWidgets('placing a piece from the palette and erasing another both update the board', (tester) async {
    await _openBoardSetup(tester);

    // Palette entries are the only Chariot glyphs off-board; tap the black
    // one, then place it in the middle of an otherwise-empty square.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear board'));
    await tester.pumpAndSettle();
    expect(_onBoard('車'), findsNothing);

    await tester.tap(find.text('車')); // palette selection (board is empty, so this is unambiguous)
    await tester.pumpAndSettle();

    final boardFinder = find.byType(BoardEditorView);
    final boardBox = tester.renderObject(boardFinder) as RenderBox;
    final layout = BoardLayout.fromSize(boardBox.size);
    final topLeft = boardBox.localToGlobal(Offset.zero);
    await tester.tapAt(topLeft + layout.pointToOffset(const BoardPoint(4, 4)));
    await tester.pumpAndSettle();

    expect(_onBoard('車'), findsOneWidget);
  });
}
