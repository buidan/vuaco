import '../fen/fen_codec.dart';
import '../models/board.dart';
import '../models/board_point.dart';
import '../models/chess_clock.dart';
import '../models/game_result.dart';
import '../models/illegal_move_reason.dart';
import '../models/move.dart';
import '../models/move_history_entry.dart';
import '../models/move_validation_result.dart';
import '../models/side.dart';
import '../notation/move_notation.dart';
import '../rules/attack_detector.dart';
import '../rules/legal_move_generator.dart';
import '../rules/piece_moves.dart';

/// The single entry point the presentation layer (and, later, the AI coach
/// and multiplayer sync logic) should depend on. Owns the current board,
/// whose turn it is, move history (for undo/redo and display), the game
/// result, and an optional clock. See RULES_ENGINE.md for the integration
/// contract.
class XiangqiEngine {
  Board _board;
  Side _sideToMove;
  GameResult _result;
  final List<MoveHistoryEntry> _history = [];
  final List<MoveHistoryEntry> _redoStack = [];
  final ChessClock clock;

  XiangqiEngine({
    Board? board,
    Side sideToMove = Side.red,
    ClockConfig clockConfig = const ClockConfig(),
  })  : _board = board ?? Board.initial(),
        _sideToMove = sideToMove,
        _result = const GameResult.ongoing(),
        clock = ChessClock(clockConfig) {
    _result = _computeResult(_board, _sideToMove);
  }

  factory XiangqiEngine.fromFen(
    String fen, {
    ClockConfig clockConfig = const ClockConfig(),
  }) {
    final decoded = FenCodec.decode(fen);
    return XiangqiEngine(
      board: decoded.board,
      sideToMove: decoded.sideToMove,
      clockConfig: clockConfig,
    );
  }

  Board get board => _board;
  Side get sideToMove => _sideToMove;
  GameResult get result => _result;
  List<MoveHistoryEntry> get history => List.unmodifiable(_history);
  bool get canUndo => _history.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  bool isInCheck(Side side) => AttackDetector.isGeneralInCheck(_board, side);

  List<Move> get allLegalMoves =>
      _result.isOngoing ? LegalMoveGenerator.allLegalMoves(_board, _sideToMove) : const [];

  List<BoardPoint> legalDestinationsFrom(BoardPoint from) {
    if (!_result.isOngoing) return const [];
    return LegalMoveGenerator.legalDestinationsFrom(_board, from, _sideToMove);
  }

  String toFen() => FenCodec.encode(
        _board,
        _sideToMove,
        fullmoveNumber: (_history.length ~/ 2) + 1,
      );

  /// Validates [from] -> [to] against the current position and, if legal,
  /// executes it: updates the board, flips the turn, records history,
  /// advances the clock increment, and recomputes the game result.
  MoveValidationResult tryMove(BoardPoint from, BoardPoint to) {
    if (!_result.isOngoing) {
      return const IllegalMove(IllegalMoveReason.gameAlreadyOver, 'The game has already ended.');
    }

    final piece = _board.pieceAt(from);
    if (piece == null) {
      return const IllegalMove(
          IllegalMoveReason.noPieceAtSource, 'There is no piece on the selected point.');
    }
    if (piece.side != _sideToMove) {
      return const IllegalMove(
          IllegalMoveReason.notYourTurn, "It is not this piece's turn to move.");
    }

    final legalDestinations = LegalMoveGenerator.legalDestinationsFrom(_board, from, _sideToMove);
    if (!legalDestinations.contains(to)) {
      final isPseudoLegal = pseudoLegalDestinations(_board, from).contains(to);
      if (isPseudoLegal) {
        return const IllegalMove(
          IllegalMoveReason.leavesGeneralInCheck,
          'That move would leave your general in check (or violates the flying-general rule).',
        );
      }
      return const IllegalMove(
          IllegalMoveReason.illegalPieceMovement, 'That piece cannot move there.');
    }

    final move = Move(from: from, to: to, movedPiece: piece, capturedPiece: _board.pieceAt(to));
    final boardBefore = _board;
    final sideBefore = _sideToMove;

    final nextBoard = _board.applyMove(from, to);
    final nextSide = _sideToMove.opponent;
    final opponentInCheck = AttackDetector.isGeneralInCheck(nextBoard, nextSide);
    final opponentHasMoves = LegalMoveGenerator.hasAnyLegalMove(nextBoard, nextSide);
    final isCheckmate = opponentInCheck && !opponentHasMoves;
    final noLegalMoves = !opponentInCheck && !opponentHasMoves;

    final resultAfter = isCheckmate
        ? GameResult.win(sideBefore, GameEndReason.checkmate)
        : noLegalMoves
            ? GameResult.win(sideBefore, GameEndReason.noLegalMoves)
            : const GameResult.ongoing();

    final notation = MoveNotation.forMove(move, isCheck: opponentInCheck, isCheckmate: isCheckmate);

    _history.add(MoveHistoryEntry(
      move: move,
      notation: notation,
      isCheck: opponentInCheck,
      resultAfter: resultAfter,
      boardBefore: boardBefore,
      sideToMoveBefore: sideBefore,
    ));
    _redoStack.clear();

    _board = nextBoard;
    _sideToMove = nextSide;
    clock.applyIncrement(sideBefore);
    _result = resultAfter;

    return LegalMove(move, leavesOpponentInCheck: opponentInCheck, endsGame: !resultAfter.isOngoing);
  }

  bool undo() {
    if (_history.isEmpty) return false;
    final entry = _history.removeLast();
    _redoStack.add(entry);
    _board = entry.boardBefore;
    _sideToMove = entry.sideToMoveBefore;
    _result = const GameResult.ongoing();
    return true;
  }

  bool redo() {
    if (_redoStack.isEmpty) return false;
    final entry = _redoStack.removeLast();
    _history.add(entry);
    _board = entry.boardBefore.applyMove(entry.move.from, entry.move.to);
    _sideToMove = entry.sideToMoveBefore.opponent;
    _result = entry.resultAfter;
    return true;
  }

  static GameResult _computeResult(Board board, Side sideToMove) {
    final inCheck = AttackDetector.isGeneralInCheck(board, sideToMove);
    final hasMoves = LegalMoveGenerator.hasAnyLegalMove(board, sideToMove);
    if (hasMoves) return const GameResult.ongoing();
    return GameResult.win(
        sideToMove.opponent, inCheck ? GameEndReason.checkmate : GameEndReason.noLegalMoves);
  }
}
