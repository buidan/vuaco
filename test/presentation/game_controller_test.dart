import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/presentation/providers/game_providers.dart';

void main() {
  group('GameController.applyMove', () {
    test('applies a legal move directly, with no selection step', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final applied = container.read(gameControllerProvider.notifier).applyMove(
            const BoardPoint(3, 4),
            const BoardPoint(4, 4),
          );

      final state = container.read(gameControllerProvider);
      expect(applied, isTrue);
      expect(state.history, hasLength(1));
      expect(state.board.pieceAt(const BoardPoint(4, 4)), isNotNull);
      expect(state.board.pieceAt(const BoardPoint(3, 4)), isNull);
      expect(state.sideToMove, Side.black);
      expect(state.selected, isNull);
    });

    test('rejects an illegal move and leaves state unchanged', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final applied = container.read(gameControllerProvider.notifier).applyMove(
            const BoardPoint(0, 0),
            const BoardPoint(1, 1),
          );

      final state = container.read(gameControllerProvider);
      expect(applied, isFalse);
      expect(state.history, isEmpty);
      expect(state.sideToMove, Side.red);
    });
  });

  group('GameController.canUndo', () {
    test('is false for a fresh game and true after a move is applied', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameControllerProvider.notifier);

      expect(notifier.canUndo, isFalse);

      notifier.applyMove(const BoardPoint(3, 4), const BoardPoint(4, 4));
      expect(notifier.canUndo, isTrue);

      notifier.undo();
      expect(notifier.canUndo, isFalse);
    });
  });
}
