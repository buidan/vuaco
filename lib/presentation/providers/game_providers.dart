import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/pass_and_play_repository.dart';
import '../../domain/engine/xiangqi_engine.dart';
import '../../domain/models/board.dart';
import '../../domain/models/board_point.dart';
import '../../domain/models/game_result.dart';
import '../../domain/models/move.dart';
import '../../domain/models/move_history_entry.dart';
import '../../domain/models/move_validation_result.dart';
import '../../domain/models/side.dart';

final passAndPlayRepositoryProvider = Provider<PassAndPlayRepository>(
  (ref) => InMemoryPassAndPlayRepository(),
);

/// Snapshot of everything the UI needs to render one frame: board, whose
/// turn it is, the current selection and its legal destinations, check
/// state for both generals, and the move just made (so the board widget
/// knows which piece to slide, and null for undo/redo/new game).
class GameControllerState {
  final Board board;
  final Side sideToMove;
  final GameResult result;
  final List<MoveHistoryEntry> history;
  final BoardPoint? selected;
  final List<BoardPoint> legalDestinations;
  final bool redInCheck;
  final bool blackInCheck;
  final Move? lastMove;

  /// FEN of the current position - the Engine Coach (Phase 3) sends this
  /// straight to the backend's `/engine/analyze`, so it must stay in sync
  /// with [board]/[sideToMove] (see `GameController._stateFromEngine`).
  final String fen;

  const GameControllerState({
    required this.board,
    required this.sideToMove,
    required this.result,
    required this.history,
    required this.redInCheck,
    required this.blackInCheck,
    required this.fen,
    this.selected,
    this.legalDestinations = const [],
    this.lastMove,
  });
}

class GameController extends Notifier<GameControllerState> {
  late XiangqiEngine _engine;

  @override
  GameControllerState build() {
    _engine = ref.read(passAndPlayRepositoryProvider).createNewGame();
    return _stateFromEngine();
  }

  GameControllerState _stateFromEngine({
    BoardPoint? selected,
    List<BoardPoint> legalDestinations = const [],
    Move? lastMove,
  }) {
    return GameControllerState(
      board: _engine.board,
      sideToMove: _engine.sideToMove,
      result: _engine.result,
      history: _engine.history,
      selected: selected,
      legalDestinations: legalDestinations,
      redInCheck: _engine.isInCheck(Side.red),
      blackInCheck: _engine.isInCheck(Side.black),
      fen: _engine.toFen(),
      lastMove: lastMove,
    );
  }

  /// Tap handler for any board intersection: selects a piece, moves a
  /// selected piece to a legal destination, or clears the selection.
  void tapPoint(BoardPoint point) {
    if (!state.result.isOngoing) return;

    if (state.selected == point) {
      state = _stateFromEngine();
      return;
    }

    if (state.selected != null && state.legalDestinations.contains(point)) {
      final validation = _engine.tryMove(state.selected!, point);
      state = switch (validation) {
        LegalMove(move: final move) => _stateFromEngine(lastMove: move),
        IllegalMove() => _stateFromEngine(),
      };
      return;
    }

    final piece = _engine.board.pieceAt(point);
    if (piece != null && piece.side == _engine.sideToMove) {
      final legal = _engine.legalDestinationsFrom(point);
      state = _stateFromEngine(selected: point, legalDestinations: legal);
    } else {
      state = _stateFromEngine();
    }
  }

  void undo() {
    if (_engine.undo()) state = _stateFromEngine();
  }

  void redo() {
    if (_engine.redo()) state = _stateFromEngine();
  }

  void newGame() {
    _engine = ref.read(passAndPlayRepositoryProvider).createNewGame();
    state = _stateFromEngine();
  }
}

final gameControllerProvider = NotifierProvider<GameController, GameControllerState>(GameController.new);
