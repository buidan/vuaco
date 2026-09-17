import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/fen/fen_codec.dart';
import '../../domain/models/board.dart';
import '../../domain/models/board_point.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/side.dart';
import '../../domain/rules/position_validator.dart';

/// Editing state for the Phase 5 board-setup flow (manual FEN paste +
/// hand-edited position), kept entirely separate from `GameControllerState`
/// - editing has no turns, legal-move highlighting, or history, and the
/// resulting position only becomes a real game once the user starts one
/// from it (`GameController.startFromPosition`).
class BoardEditorState {
  final Board board;
  final Side sideToMove;
  final Piece? selectedPaletteItem;
  final bool eraserSelected;
  final String? fenError;

  const BoardEditorState({
    required this.board,
    required this.sideToMove,
    this.selectedPaletteItem,
    this.eraserSelected = false,
    this.fenError,
  });

  BoardEditorState copyWith({
    Board? board,
    Side? sideToMove,
    Piece? selectedPaletteItem,
    bool? eraserSelected,
    String? fenError,
    bool clearPaletteSelection = false,
    bool clearFenError = false,
  }) {
    return BoardEditorState(
      board: board ?? this.board,
      sideToMove: sideToMove ?? this.sideToMove,
      selectedPaletteItem: clearPaletteSelection ? null : (selectedPaletteItem ?? this.selectedPaletteItem),
      eraserSelected: eraserSelected ?? this.eraserSelected,
      fenError: clearFenError ? null : (fenError ?? this.fenError),
    );
  }
}

class BoardEditorController extends Notifier<BoardEditorState> {
  @override
  BoardEditorState build() => BoardEditorState(board: Board.initial(), sideToMove: Side.red);

  void selectPaletteItem(Piece piece) {
    state = state.copyWith(selectedPaletteItem: piece, eraserSelected: false);
  }

  void selectEraser() {
    state = state.copyWith(clearPaletteSelection: true, eraserSelected: true);
  }

  void tapBoardPoint(BoardPoint point) {
    if (state.eraserSelected) {
      state = state.copyWith(board: state.board.withPieceAt(point, null), clearFenError: true);
    } else if (state.selectedPaletteItem != null) {
      state = state.copyWith(board: state.board.withPieceAt(point, state.selectedPaletteItem), clearFenError: true);
    }
  }

  void setSideToMove(Side side) {
    state = state.copyWith(sideToMove: side);
  }

  void resetToStandard() {
    state = state.copyWith(board: Board.initial(), sideToMove: Side.red, clearFenError: true);
  }

  void clearBoard() {
    state = state.copyWith(board: Board.empty(), sideToMove: Side.red, clearFenError: true);
  }

  void loadFen(String fen) {
    try {
      final decoded = FenCodec.decode(fen);
      state = state.copyWith(board: decoded.board, sideToMove: decoded.sideToMove, clearFenError: true);
    } on FenParseException catch (e) {
      state = state.copyWith(fenError: e.message);
    }
  }

  /// Null if [BoardEditorState.board] is ready to play; otherwise a short
  /// user-facing reason it isn't.
  String? checkPlayability() => PositionValidator.reasonPositionIsUnplayable(state.board);
}

final boardEditorControllerProvider = NotifierProvider<BoardEditorController, BoardEditorState>(
  BoardEditorController.new,
);
