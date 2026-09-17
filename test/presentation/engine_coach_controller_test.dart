import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/data/repositories/engine_coach_repository.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/engine_analysis.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/presentation/providers/engine_coach_providers.dart';
import 'package:vuaco/presentation/providers/game_providers.dart';

EngineAnalysisResult _cpResult(int scoreValue, {String bestMove = 'e3e4'}) {
  return EngineAnalysisResult(
    bestMove: bestMove,
    ponder: null,
    depthReached: 10,
    lines: [
      EngineAnalysisLine(
        multiPv: 1,
        depth: 10,
        scoreType: EngineScoreType.centipawns,
        scoreValue: scoreValue,
        pvMoves: [bestMove],
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
  group('EngineCoachController', () {
    test('toggling on analyzes the current position', () async {
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) => _cpResult(50)),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(engineCoachControllerProvider.notifier).toggle();
      await Future<void>.delayed(Duration.zero); // let the analyze future resolve

      final state = container.read(engineCoachControllerProvider);
      expect(state.enabled, isTrue);
      expect(state.analyzedSide, Side.red);
      expect(state.analysis?.lines.single.scoreValue, 50);
      expect(state.blunderEvent, isNull);
    });

    test('flags a blunder when eval swings hard against the side that just moved', () async {
      var callIndex = 0;
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) {
            callIndex = i;
            // First call: Red to move, position looks fine for Red (+50).
            // Second call (after Red's move): Black to move, now great for
            // Black (+400) - i.e. disastrous for Red.
            return _cpResult(callIndex == 0 ? 50 : 400);
          }),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(engineCoachControllerProvider.notifier).toggle();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(engineCoachControllerProvider).blunderEvent, isNull);

      // Red pushes the central soldier - a legal but (per the fake) awful move.
      container.read(gameControllerProvider.notifier).tapPoint(const BoardPoint(3, 4));
      container.read(gameControllerProvider.notifier).tapPoint(const BoardPoint(4, 4));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(engineCoachControllerProvider);
      final blunder = state.blunderEvent;
      expect(blunder, isNotNull);
      expect(blunder!.side, Side.red);
      expect(blunder.dropCentipawns, 450); // 50 - (-400)
    });

    test('does not flag a blunder for a small eval swing', () async {
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) => _cpResult(i == 0 ? 50 : -40)),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(engineCoachControllerProvider.notifier).toggle();
      await Future<void>.delayed(Duration.zero);

      container.read(gameControllerProvider.notifier).tapPoint(const BoardPoint(3, 4));
      container.read(gameControllerProvider.notifier).tapPoint(const BoardPoint(4, 4));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(engineCoachControllerProvider).blunderEvent, isNull);
    });

    test('does not analyze while disabled, and clears state when turned off', () async {
      var calls = 0;
      final container = ProviderContainer(overrides: [
        engineCoachRepositoryProvider.overrideWithValue(
          FakeEngineCoachRepository((fen, i) {
            calls++;
            return _cpResult(50);
          }),
        ),
      ]);
      addTearDown(container.dispose);

      container.read(gameControllerProvider.notifier).tapPoint(const BoardPoint(3, 4));
      container.read(gameControllerProvider.notifier).tapPoint(const BoardPoint(4, 4));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);

      container.read(engineCoachControllerProvider.notifier).toggle(); // on
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      container.read(engineCoachControllerProvider.notifier).toggle(); // off
      final state = container.read(engineCoachControllerProvider);
      expect(state.enabled, isFalse);
      expect(state.analysis, isNull);
    });
  });
}
