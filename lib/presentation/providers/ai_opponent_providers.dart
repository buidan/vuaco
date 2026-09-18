import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/ai_difficulty.dart';
import '../../domain/models/side.dart';
import '../../domain/notation/move_notation.dart';
import 'engine_coach_providers.dart';
import 'game_providers.dart';

/// A second, independent `GameController` instance for "Play vs Computer" -
/// deliberately *not* the same [gameControllerProvider] Pass & Play uses,
/// so starting an AI match can never clobber (or be clobbered by) whatever
/// Pass & Play game is in progress elsewhere in the app. Reuses the exact
/// same controller class, since an AI match is otherwise a completely
/// normal game as far as the rules engine is concerned.
final aiMatchGameControllerProvider = NotifierProvider<GameController, GameControllerState>(GameController.new);

class AiMatchState {
  final Side? humanSide; // null until startGame() is called
  final AiDifficulty difficulty;
  final bool aiThinking;
  final String? aiError;

  const AiMatchState({
    this.humanSide,
    this.difficulty = AiDifficulty.medium,
    this.aiThinking = false,
    this.aiError,
  });

  AiMatchState copyWith({
    Side? humanSide,
    AiDifficulty? difficulty,
    bool? aiThinking,
    String? aiError,
    bool clearAiError = false,
  }) {
    return AiMatchState(
      humanSide: humanSide ?? this.humanSide,
      difficulty: difficulty ?? this.difficulty,
      aiThinking: aiThinking ?? this.aiThinking,
      aiError: clearAiError ? null : (aiError ?? this.aiError),
    );
  }
}

/// Drives "Play vs Computer": whenever it's not the human's turn in
/// [aiMatchGameControllerProvider]'s game, asks the backend's
/// `/engine/analyze` (the same endpoint the Engine Coach uses) for a move
/// at a depth set by [AiMatchState.difficulty] and plays it via
/// [GameController.applyMove]. The AI never sees or touches anything the
/// client didn't already validate itself first - same "client engine for
/// responsiveness, but the move still has to be legal" shape as
/// everywhere else, just with the client as its own opponent instead of a
/// second device.
class AiMatchController extends Notifier<AiMatchState> {
  @override
  AiMatchState build() {
    ref.listen<GameControllerState>(aiMatchGameControllerProvider, (previous, next) {
      _maybeMakeAiMove(next);
    });
    return const AiMatchState();
  }

  void startGame({required Side humanSide, required AiDifficulty difficulty}) {
    ref.read(aiMatchGameControllerProvider.notifier).newGame();
    state = AiMatchState(humanSide: humanSide, difficulty: difficulty);
    _maybeMakeAiMove(ref.read(aiMatchGameControllerProvider));
  }

  void _maybeMakeAiMove(GameControllerState gameState) {
    final humanSide = state.humanSide;
    if (humanSide == null) return; // no game started yet
    if (!gameState.result.isOngoing) return;
    if (gameState.sideToMove == humanSide) return; // human's turn
    if (state.aiThinking) return; // already have a request in flight
    unawaited(_makeAiMove(gameState));
  }

  Future<void> _makeAiMove(GameControllerState gameState) async {
    state = state.copyWith(aiThinking: true, clearAiError: true);
    try {
      final result = await ref.read(engineCoachRepositoryProvider).analyze(
            gameState.fen,
            multiPv: 1,
            depth: state.difficulty.searchDepth,
          );
      final bestMove = result.bestMove;
      if (bestMove == null) {
        // No legal move - shouldn't happen while result.isOngoing, but
        // don't leave the UI stuck on "thinking" if it somehow does.
        state = state.copyWith(aiThinking: false);
        return;
      }
      final (from, to) = MoveNotation.parseUciMove(bestMove);
      ref.read(aiMatchGameControllerProvider.notifier).applyMove(from, to);
      state = state.copyWith(aiThinking: false);
    } catch (e) {
      state = state.copyWith(aiThinking: false, aiError: e.toString());
    }
  }

  /// Undoes the human's last move together with the AI's reply to it (if
  /// any), so the human always lands back on their own turn rather than
  /// bouncing straight into another AI move.
  void undoHumanMove() {
    final notifier = ref.read(aiMatchGameControllerProvider.notifier);
    if (!notifier.canUndo) return;
    notifier.undo();
    if (ref.read(aiMatchGameControllerProvider).sideToMove != state.humanSide) {
      notifier.undo();
    }
  }
}

final aiMatchControllerProvider = NotifierProvider<AiMatchController, AiMatchState>(AiMatchController.new);
