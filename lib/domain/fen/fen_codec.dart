import '../models/board.dart';
import '../models/board_point.dart';
import '../models/piece.dart';
import '../models/piece_type.dart';
import '../models/side.dart';
import '../rules/board_geometry.dart';

class FenParseException implements Exception {
  final String message;
  FenParseException(this.message);

  @override
  String toString() => 'FenParseException: $message';
}

class DecodedFen {
  final Board board;
  final Side sideToMove;
  final int halfmoveClock;
  final int fullmoveNumber;

  const DecodedFen({
    required this.board,
    required this.sideToMove,
    this.halfmoveClock = 0,
    this.fullmoveNumber = 1,
  });
}

/// Xiangqi FEN, using the same piece-letter convention as Pikafish/UCCI
/// engines (K/A/B/N/R/C/P for General/Advisor/Elephant/Horse/Chariot/Cannon/
/// Soldier), so this codec's output can be fed to a Pikafish-backed backend
/// unchanged in a later phase. Uppercase = Red, lowercase = Black.
///
/// Format: `<board> <sideToMove> - - <halfmoveClock> <fullmoveNumber>`
/// The board field lists ranks top-to-bottom (Black's back rank, i.e. row 9,
/// first; Red's back rank, row 0, last), matching standard FEN row order.
/// `w` means Red to move, `b` means Black to move (Red is the first-moving
/// side, playing the role chess assigns to White).
class FenCodec {
  FenCodec._();

  static const Map<PieceType, String> _redLetters = {
    PieceType.general: 'K',
    PieceType.advisor: 'A',
    PieceType.elephant: 'B',
    PieceType.horse: 'N',
    PieceType.chariot: 'R',
    PieceType.cannon: 'C',
    PieceType.soldier: 'P',
  };

  static final Map<String, PieceType> _letterToType = {
    for (final entry in _redLetters.entries) entry.value: entry.key,
  };

  static String encode(
    Board board,
    Side sideToMove, {
    int halfmoveClock = 0,
    int fullmoveNumber = 1,
  }) {
    final rankStrings = <String>[];
    for (var row = BoardGeometry.rows - 1; row >= 0; row--) {
      final buffer = StringBuffer();
      var emptyRun = 0;
      for (var col = 0; col < BoardGeometry.columns; col++) {
        final piece = board.pieceAt(BoardPoint(row, col));
        if (piece == null) {
          emptyRun++;
          continue;
        }
        if (emptyRun > 0) {
          buffer.write(emptyRun);
          emptyRun = 0;
        }
        final letter = _redLetters[piece.type]!;
        buffer.write(piece.side == Side.red ? letter : letter.toLowerCase());
      }
      if (emptyRun > 0) buffer.write(emptyRun);
      rankStrings.add(buffer.toString());
    }
    final boardField = rankStrings.join('/');
    final sideField = sideToMove == Side.red ? 'w' : 'b';
    return '$boardField $sideField - - $halfmoveClock $fullmoveNumber';
  }

  static DecodedFen decode(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      throw FenParseException('FEN must have at least board and side-to-move fields');
    }
    final boardField = parts[0];
    final sideField = parts[1];

    final rankStrings = boardField.split('/');
    if (rankStrings.length != BoardGeometry.rows) {
      throw FenParseException(
          'Expected ${BoardGeometry.rows} ranks separated by "/", got ${rankStrings.length}');
    }

    final grid = List.generate(
      BoardGeometry.rows,
      (_) => List<Piece?>.filled(BoardGeometry.columns, null),
    );

    for (var i = 0; i < rankStrings.length; i++) {
      final row = BoardGeometry.rows - 1 - i; // first FEN rank = top = row 9
      var col = 0;
      for (final ch in rankStrings[i].split('')) {
        final digit = int.tryParse(ch);
        if (digit != null) {
          col += digit;
          continue;
        }
        final type = _letterToType[ch.toUpperCase()];
        if (type == null) throw FenParseException('Unknown piece letter "$ch"');
        if (col >= BoardGeometry.columns) {
          throw FenParseException('Rank "${rankStrings[i]}" overflows board width');
        }
        final side = ch == ch.toUpperCase() ? Side.red : Side.black;
        grid[row][col] = Piece(type, side);
        col++;
      }
      if (col != BoardGeometry.columns) {
        throw FenParseException(
            'Rank "${rankStrings[i]}" has $col squares, expected ${BoardGeometry.columns}');
      }
    }

    Side side;
    if (sideField == 'w') {
      side = Side.red;
    } else if (sideField == 'b') {
      side = Side.black;
    } else {
      throw FenParseException('Side-to-move field must be "w" or "b", got "$sideField"');
    }

    final halfmove = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
    final fullmove = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;

    return DecodedFen(
      board: Board.fromGrid(grid),
      sideToMove: side,
      halfmoveClock: halfmove,
      fullmoveNumber: fullmove,
    );
  }
}
