import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/presentation/providers/board_editor_providers.dart';

void main() {
  group('BoardEditorController', () {
    test('starts from the standard position', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(boardEditorControllerProvider);
      expect(state.board.pieceAt(const BoardPoint(0, 4)), const Piece(PieceType.general, Side.red));
      expect(state.sideToMove, Side.red);
      expect(container.read(boardEditorControllerProvider.notifier).checkPlayability(), isNull);
    });

    test('clearBoard empties every square', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(boardEditorControllerProvider.notifier).clearBoard();
      final state = container.read(boardEditorControllerProvider);
      expect(state.board.occupiedSquares, isEmpty);
    });

    test('selecting a palette piece then tapping a point stamps it down', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      controller.clearBoard();
      controller.selectPaletteItem(const Piece(PieceType.chariot, Side.black));
      controller.tapBoardPoint(const BoardPoint(5, 5));

      final state = container.read(boardEditorControllerProvider);
      expect(state.board.pieceAt(const BoardPoint(5, 5)), const Piece(PieceType.chariot, Side.black));
    });

    test('the eraser clears whatever is on a square', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      controller.selectEraser();
      controller.tapBoardPoint(const BoardPoint(0, 4)); // the red general on the standard board

      final state = container.read(boardEditorControllerProvider);
      expect(state.board.pieceAt(const BoardPoint(0, 4)), isNull);
      expect(controller.checkPlayability(), contains('Red needs'));
    });

    test('selecting a piece deselects the eraser and vice versa', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      controller.selectEraser();
      expect(container.read(boardEditorControllerProvider).eraserSelected, isTrue);

      controller.selectPaletteItem(const Piece(PieceType.horse, Side.red));
      final state = container.read(boardEditorControllerProvider);
      expect(state.eraserSelected, isFalse);
      expect(state.selectedPaletteItem, const Piece(PieceType.horse, Side.red));
    });

    test('loadFen replaces the board and side to move on success', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      controller.loadFen('4k4/9/9/9/9/9/9/9/9/4K4 b - - 0 1');

      final state = container.read(boardEditorControllerProvider);
      expect(state.sideToMove, Side.black);
      expect(state.board.pieceAt(const BoardPoint(9, 4)), const Piece(PieceType.general, Side.black));
      expect(state.board.pieceAt(const BoardPoint(0, 1)), isNull); // standard-position piece is gone
      expect(state.fenError, isNull);
    });

    test('loadFen reports an error and leaves the board untouched on malformed input', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      final before = container.read(boardEditorControllerProvider).board;

      controller.loadFen('not a fen');

      final state = container.read(boardEditorControllerProvider);
      expect(state.fenError, isNotNull);
      expect(state.board, same(before));
    });

    test('setSideToMove updates the side without touching the board', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      final before = container.read(boardEditorControllerProvider).board;
      controller.setSideToMove(Side.black);

      final state = container.read(boardEditorControllerProvider);
      expect(state.sideToMove, Side.black);
      expect(state.board, same(before));
    });
  });
}
