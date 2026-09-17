import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/vision_repository.dart';
import '../../domain/fen/fen_codec.dart';
import '../../domain/models/board.dart';
import '../../domain/models/board_point.dart';
import '../../domain/models/online_room.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/side.dart';
import '../../domain/rules/position_validator.dart';
import 'backend_config_providers.dart';
import 'online_match_providers.dart';

final visionRepositoryProvider = Provider<VisionRepository>((ref) {
  final repository = HttpVisionRepository(baseUrl: ref.watch(backendRestBaseUrlProvider));
  ref.onDispose(repository.close);
  return repository;
});

/// Editing state for the Phase 5 board-setup flow (manual FEN paste, photo
/// scan, or hand-edited position), kept entirely separate from
/// `GameControllerState` - editing has no turns, legal-move highlighting,
/// or history, and the resulting position only becomes a real game once
/// the user starts one from it (`GameController.startFromPosition`).
class BoardEditorState {
  final Board board;
  final Side sideToMove;
  final Piece? selectedPaletteItem;
  final bool eraserSelected;
  final String? fenError;
  final bool scanning;
  final String? scanError;

  /// Set after a successful photo scan, cleared by any subsequent edit -
  /// the UI uses this to prompt "review this before playing", since real
  /// testing found accuracy varies (see RULES_ENGINE.md).
  final double? lastScanConfidence;

  const BoardEditorState({
    required this.board,
    required this.sideToMove,
    this.selectedPaletteItem,
    this.eraserSelected = false,
    this.fenError,
    this.scanning = false,
    this.scanError,
    this.lastScanConfidence,
  });

  BoardEditorState copyWith({
    Board? board,
    Side? sideToMove,
    Piece? selectedPaletteItem,
    bool? eraserSelected,
    String? fenError,
    bool? scanning,
    String? scanError,
    double? lastScanConfidence,
    bool clearPaletteSelection = false,
    bool clearFenError = false,
    bool clearScanError = false,
    bool clearScanConfidence = false,
  }) {
    return BoardEditorState(
      board: board ?? this.board,
      sideToMove: sideToMove ?? this.sideToMove,
      selectedPaletteItem: clearPaletteSelection ? null : (selectedPaletteItem ?? this.selectedPaletteItem),
      eraserSelected: eraserSelected ?? this.eraserSelected,
      fenError: clearFenError ? null : (fenError ?? this.fenError),
      scanning: scanning ?? this.scanning,
      scanError: clearScanError ? null : (scanError ?? this.scanError),
      lastScanConfidence: clearScanConfidence ? null : (lastScanConfidence ?? this.lastScanConfidence),
    );
  }
}

class BoardEditorController extends Notifier<BoardEditorState> {
  AuthSession? _scanSession;

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
      state = state.copyWith(
        board: state.board.withPieceAt(point, null),
        clearFenError: true,
        clearScanConfidence: true,
      );
    } else if (state.selectedPaletteItem != null) {
      state = state.copyWith(
        board: state.board.withPieceAt(point, state.selectedPaletteItem),
        clearFenError: true,
        clearScanConfidence: true,
      );
    }
  }

  void setSideToMove(Side side) {
    state = state.copyWith(sideToMove: side);
  }

  void resetToStandard() {
    state = state.copyWith(
      board: Board.initial(),
      sideToMove: Side.red,
      clearFenError: true,
      clearScanConfidence: true,
    );
  }

  void clearBoard() {
    state = state.copyWith(board: Board.empty(), sideToMove: Side.red, clearFenError: true, clearScanConfidence: true);
  }

  void loadFen(String fen) {
    try {
      final decoded = FenCodec.decode(fen);
      state = state.copyWith(
        board: decoded.board,
        sideToMove: decoded.sideToMove,
        clearFenError: true,
        clearScanConfidence: true,
      );
    } on FenParseException catch (e) {
      state = state.copyWith(fenError: e.message);
    }
  }

  /// Scans a board photo and loads the result into the editor for review -
  /// never starts a game directly, since the read is a best-effort draft
  /// (see [BoardEditorState.lastScanConfidence] and RULES_ENGINE.md).
  Future<void> scanPhoto(Uint8List bytes, String mimeType) async {
    state = state.copyWith(scanning: true, clearScanError: true);
    try {
      final session = _scanSession ??= await ref.read(authRepositoryProvider).guestLogin('Guest');
      final result = await ref.read(visionRepositoryProvider).scanBoardPhoto(session.token, bytes, mimeType);
      final decoded = FenCodec.decode(result.fen);
      state = state.copyWith(
        board: decoded.board,
        sideToMove: decoded.sideToMove,
        scanning: false,
        clearFenError: true,
        clearScanError: true,
        lastScanConfidence: result.confidence,
      );
    } catch (e) {
      state = state.copyWith(scanning: false, scanError: e.toString());
    }
  }

  /// Null if [BoardEditorState.board] is ready to play; otherwise a short
  /// user-facing reason it isn't.
  String? checkPlayability() => PositionValidator.reasonPositionIsUnplayable(state.board);
}

final boardEditorControllerProvider = NotifierProvider<BoardEditorController, BoardEditorState>(
  BoardEditorController.new,
);
