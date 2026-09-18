import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/data/repositories/engine_coach_repository.dart';
import 'package:vuaco/domain/models/ai_difficulty.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/engine_analysis.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/presentation/providers/ai_opponent_providers.dart';
import 'package:vuaco/presentation/providers/engine_coach_providers.dart';

EngineAnalysisResult _bestMove(String uci) {
  return EngineAnalysisResult(
    bestMove: uci,
    ponder: null,
    depthReached: 10,
    lines: [
      EngineAnalysisLine(
        multiPv: 1,
        depth: 10,
        scoreType: EngineScoreType.centipawns,
        scoreValue: 0,
        pvMoves: [uci],
      ),
    ],
  );
}

class FakeEngineCoachRepository implements EngineCoachRepository {
  final EngineAnalysisResult Function(String fen, int callIndex) responder;
  int callCount = 0;

  FakeEngineCoachRepository(this.responder);

  @override
  Future<EngineAnalysisResult> analyze(String fen, {int multiPv = 3, int? depth}) async {
    return responder(fen, callCount++);
  }

  @override
  void close() {}
}

void main() {
  group('AiMatchController', () {
    test('starting as Black triggers an immediate AI move (AI plays Red)', () async {
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) => _bestMove('e3e4')),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(aiMatchControllerProvider.notifier).startGame(
            humanSide: Side.black,
            difficulty: AiDifficulty.easy,
          );
      await Future<void>.delayed(Duration.zero);

      final gameState = container.read(aiMatchGameControllerProvider);
      expect(gameState.history, hasLength(1));
      expect(gameState.board.pieceAt(const BoardPoint(4, 4)), isNotNull);
      expect(gameState.sideToMove, Side.black);
      expect(container.read(aiMatchControllerProvider).aiThinking, isFalse);
    });

    test('starting as Red does not trigger an immediate AI move', () async {
      var calls = 0;
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) {
            calls++;
            return _bestMove('e6e5');
          }),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(aiMatchControllerProvider.notifier).startGame(
            humanSide: Side.red,
            difficulty: AiDifficulty.medium,
          );
      await Future<void>.delayed(Duration.zero);

      expect(calls, 0);
      expect(container.read(aiMatchGameControllerProvider).history, isEmpty);
    });

    test('AI replies with a parsed, applied move after the human moves', () async {
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) => _bestMove('e6e5')),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(aiMatchControllerProvider.notifier).startGame(
            humanSide: Side.red,
            difficulty: AiDifficulty.medium,
          );

      container.read(aiMatchGameControllerProvider.notifier).applyMove(
            const BoardPoint(3, 4),
            const BoardPoint(4, 4),
          );
      await Future<void>.delayed(Duration.zero);

      final gameState = container.read(aiMatchGameControllerProvider);
      expect(gameState.history, hasLength(2));
      expect(gameState.board.pieceAt(const BoardPoint(5, 4)), isNotNull);
      expect(gameState.sideToMove, Side.red);
      expect(container.read(aiMatchControllerProvider).aiThinking, isFalse);
    });

    test('aiThinking toggles on while the analyze request is in flight', () {
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) => _bestMove('e3e4')),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(aiMatchControllerProvider.notifier).startGame(
            humanSide: Side.black,
            difficulty: AiDifficulty.easy,
          );

      // Dart async functions run synchronously up to their first `await`,
      // so aiThinking should already be true immediately after startGame()
      // returns, before the fake repository's future resolves.
      expect(container.read(aiMatchControllerProvider).aiThinking, isTrue);
    });

    test('surfaces repository errors instead of leaving the UI stuck thinking', () async {
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) => throw Exception('engine unreachable')),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(aiMatchControllerProvider.notifier).startGame(
            humanSide: Side.black,
            difficulty: AiDifficulty.easy,
          );
      await Future<void>.delayed(Duration.zero);

      final aiState = container.read(aiMatchControllerProvider);
      expect(aiState.aiThinking, isFalse);
      expect(aiState.aiError, contains('engine unreachable'));
      expect(container.read(aiMatchGameControllerProvider).history, isEmpty);
    });

    test('undoHumanMove undoes both the human move and the AI reply', () async {
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) => _bestMove('e6e5')),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(aiMatchControllerProvider.notifier).startGame(
            humanSide: Side.red,
            difficulty: AiDifficulty.medium,
          );
      container.read(aiMatchGameControllerProvider.notifier).applyMove(
            const BoardPoint(3, 4),
            const BoardPoint(4, 4),
          );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(aiMatchGameControllerProvider).history, hasLength(2));

      container.read(aiMatchControllerProvider.notifier).undoHumanMove();

      final gameState = container.read(aiMatchGameControllerProvider);
      expect(gameState.history, isEmpty);
      expect(gameState.sideToMove, Side.red);
    });

    test('undoHumanMove with only the AI\'s opening move in history is a safe no-op '
        '(undoing it just puts the AI right back on the move)', () async {
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) => _bestMove('e3e4')),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(aiMatchControllerProvider.notifier).startGame(
            humanSide: Side.black,
            difficulty: AiDifficulty.easy,
          );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(aiMatchGameControllerProvider).history, hasLength(1));

      // Only one ply exists (the AI's own opening move), so the "undo the
      // human move and the AI's reply to it" pairing has no human move to
      // find. The single undo() pops the AI's move, which immediately hands
      // the turn back to the AI (still not the human's turn), so it replays
      // - net effect is a no-op from the human's point of view.
      container.read(aiMatchControllerProvider.notifier).undoHumanMove();
      await Future<void>.delayed(Duration.zero);

      final gameState = container.read(aiMatchGameControllerProvider);
      expect(gameState.history, hasLength(1));
      expect(gameState.sideToMove, Side.black);
    });
  });
}
