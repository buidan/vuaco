import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/engine_coach_repository.dart';
import '../../domain/models/engine_analysis.dart';
import '../../domain/models/side.dart';
import 'backend_config_providers.dart';
import 'game_providers.dart';

/// Centipawn-equivalent eval drop (see [EngineAnalysisLine.comparableScore])
/// at or above which a just-played move is flagged as a blunder.
const int kBlunderThresholdCentipawns = 200;

final engineCoachRepositoryProvider = Provider<EngineCoachRepository>((ref) {
  final repository = HttpEngineCoachRepository(baseUrl: ref.watch(backendRestBaseUrlProvider));
  ref.onDispose(repository.close);
  return repository;
});

/// A single flagged blunder. Compared by identity (no `==` override) so the
/// UI can tell "a fresh blunder just happened" apart from "the same
/// analysis state rebuilt" via `ref.listen`.
class BlunderEvent {
  final Side side;
  final int dropCentipawns;
  const BlunderEvent({required this.side, required this.dropCentipawns});
}

class EngineCoachState {
  final bool enabled;
  final bool loading;
  final String? error;
  final EngineAnalysisResult? analysis;

  /// Whose move [analysis] is evaluating (the side to move in the analyzed
  /// position) - lets the UI avoid drawing stale arrows for the wrong side
  /// during the brief gap while a new analysis is in flight.
  final Side? analyzedSide;
  final BlunderEvent? blunderEvent;

  const EngineCoachState({
    this.enabled = false,
    this.loading = false,
    this.error,
    this.analysis,
    this.analyzedSide,
    this.blunderEvent,
  });

  EngineCoachState copyWith({
    bool? enabled,
    bool? loading,
    String? error,
    EngineAnalysisResult? analysis,
    Side? analyzedSide,
    BlunderEvent? blunderEvent,
    bool clearError = false,
  }) {
    return EngineCoachState(
      enabled: enabled ?? this.enabled,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      analysis: analysis ?? this.analysis,
      analyzedSide: analyzedSide ?? this.analyzedSide,
      blunderEvent: blunderEvent,
    );
  }
}

/// Drives Phase 3's Engine Coach: while [EngineCoachState.enabled], watches
/// [gameControllerProvider] and calls the backend's `/engine/analyze` after
/// every position change, exposing candidate moves for the board overlay
/// and flagging blunders by comparing each analysis against the one just
/// before it (no extra API calls needed - the "before" and "after" evals
/// are just consecutive analyses in the same continuous loop).
class EngineCoachController extends Notifier<EngineCoachState> {
  EngineAnalysisResult? _previousAnalysis;
  Side? _previousAnalysisSide;
  int _previousAnalysisHistoryLength = -1;
  int _requestId = 0;

  @override
  EngineCoachState build() {
    ref.listen<GameControllerState>(gameControllerProvider, (previous, next) {
      if (!state.enabled) return;
      if (previous == null || !identical(previous.board, next.board)) {
        _analyze(next);
      }
    });
    return const EngineCoachState();
  }

  void toggle() {
    if (state.enabled) {
      _requestId++; // invalidate any in-flight request
      _previousAnalysis = null;
      _previousAnalysisSide = null;
      _previousAnalysisHistoryLength = -1;
      state = const EngineCoachState(enabled: false);
    } else {
      _previousAnalysis = null; // don't compare against a move made before the coach was on
      _previousAnalysisSide = null;
      _previousAnalysisHistoryLength = -1;
      state = state.copyWith(enabled: true, clearError: true);
      _analyze(ref.read(gameControllerProvider));
    }
  }

  Future<void> _analyze(GameControllerState gameState) async {
    if (!gameState.result.isOngoing) {
      state = state.copyWith(loading: false, clearError: true, blunderEvent: null);
      return;
    }

    final requestId = ++_requestId;
    final side = gameState.sideToMove;
    final historyLength = gameState.history.length;
    state = state.copyWith(loading: true, clearError: true);

    try {
      final result = await ref.read(engineCoachRepositoryProvider).analyze(gameState.fen, multiPv: 3);
      if (requestId != _requestId) return; // superseded by a newer position

      final blunder = _detectBlunder(
        newHistoryLength: historyLength,
        afterMoveResult: result,
      );

      _previousAnalysis = result;
      _previousAnalysisSide = side;
      _previousAnalysisHistoryLength = historyLength;

      state = state.copyWith(
        loading: false,
        clearError: true,
        analysis: result,
        analyzedSide: side,
        blunderEvent: blunder,
      );
    } catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(loading: false, error: e.toString(), blunderEvent: null);
    }
  }

  /// Compares the top line of the analysis shown before the last move (for
  /// the side that then moved) against the top line of [afterMoveResult]
  /// (for the opponent, now to move) - negated to the mover's perspective -
  /// to see how much the mover's position worsened relative to what the
  /// engine considered best. Only fires immediately after a real move (not
  /// after undo/redo/new-game, which don't extend history by exactly one
  /// from the last position this comparison baseline was recorded for).
  BlunderEvent? _detectBlunder({
    required int newHistoryLength,
    required EngineAnalysisResult afterMoveResult,
  }) {
    final before = _previousAnalysis;
    final beforeSide = _previousAnalysisSide;
    if (before == null || beforeSide == null) return null;
    if (newHistoryLength != _previousAnalysisHistoryLength + 1) return null;
    if (before.lines.isEmpty || afterMoveResult.lines.isEmpty) return null;

    final beforeScore = before.lines.first.comparableScore;
    final afterScoreFromMoverPerspective = -afterMoveResult.lines.first.comparableScore;
    final drop = beforeScore - afterScoreFromMoverPerspective;

    if (drop < kBlunderThresholdCentipawns) return null;
    return BlunderEvent(side: beforeSide, dropCentipawns: drop);
  }
}

final engineCoachControllerProvider = NotifierProvider<EngineCoachController, EngineCoachState>(
  EngineCoachController.new,
);
