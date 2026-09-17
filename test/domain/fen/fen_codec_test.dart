import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/fen/fen_codec.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';

void main() {
  group('FenCodec', () {
    test('encodes the standard starting position using the Pikafish-style letters', () {
      final fen = FenCodec.encode(Board.initial(), Side.red);
      expect(
        fen,
        'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1',
      );
    });

    test('round-trips the starting position through encode -> decode -> encode', () {
      final board = Board.initial();
      final fen = FenCodec.encode(board, Side.red);
      final decoded = FenCodec.decode(fen);
      expect(decoded.sideToMove, Side.red);
      expect(FenCodec.encode(decoded.board, decoded.sideToMove), fen);
    });

    test('round-trips an empty board with just the two generals, Black to move', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.general, Side.black));
      final fen = FenCodec.encode(board, Side.black);
      final decoded = FenCodec.decode(fen);

      expect(decoded.sideToMove, Side.black);
      expect(decoded.board.pieceAt(const BoardPoint(0, 4)), const Piece(PieceType.general, Side.red));
      expect(decoded.board.pieceAt(const BoardPoint(9, 4)), const Piece(PieceType.general, Side.black));
      for (final entry in board.occupiedSquares) {
        expect(decoded.board.pieceAt(entry.key), entry.value);
      }
      expect(FenCodec.encode(decoded.board, decoded.sideToMove), fen);
    });

    test('round-trips an arbitrary mid-game-shaped position with pieces of every type', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(0, 3), const Piece(PieceType.advisor, Side.red));
      board = board.withPieceAt(const BoardPoint(2, 2), const Piece(PieceType.elephant, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.horse, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 0), const Piece(PieceType.chariot, Side.red));
      board = board.withPieceAt(const BoardPoint(2, 1), const Piece(PieceType.cannon, Side.red));
      board = board.withPieceAt(const BoardPoint(5, 4), const Piece(PieceType.soldier, Side.red));
      board = board.withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.general, Side.black));
      board = board.withPieceAt(const BoardPoint(9, 5), const Piece(PieceType.advisor, Side.black));
      board = board.withPieceAt(const BoardPoint(7, 6), const Piece(PieceType.elephant, Side.black));
      board = board.withPieceAt(const BoardPoint(6, 6), const Piece(PieceType.horse, Side.black));
      board = board.withPieceAt(const BoardPoint(9, 8), const Piece(PieceType.chariot, Side.black));
      board = board.withPieceAt(const BoardPoint(7, 7), const Piece(PieceType.cannon, Side.black));
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.soldier, Side.black));

      for (final side in Side.values) {
        final fen = FenCodec.encode(board, side, halfmoveClock: 3, fullmoveNumber: 12);
        final decoded = FenCodec.decode(fen);
        expect(decoded.sideToMove, side);
        expect(decoded.halfmoveClock, 3);
        expect(decoded.fullmoveNumber, 12);
        for (final entry in board.occupiedSquares) {
          expect(decoded.board.pieceAt(entry.key), entry.value, reason: 'square ${entry.key}');
        }
        expect(FenCodec.encode(decoded.board, decoded.sideToMove, halfmoveClock: 3, fullmoveNumber: 12), fen);
      }
    });

    test('rejects malformed FEN with the wrong number of ranks', () {
      expect(() => FenCodec.decode('9/9 w - - 0 1'), throwsA(isA<FenParseException>()));
    });

    test('rejects a rank whose square count does not add up to 9', () {
      final badFen = List.generate(10, (i) => i == 0 ? '5' : '9').join('/');
      expect(() => FenCodec.decode('$badFen w - - 0 1'), throwsA(isA<FenParseException>()));
    });

    test('rejects an unknown piece letter', () {
      final badFen = List.generate(10, (i) => i == 0 ? '4z4' : '9').join('/');
      expect(() => FenCodec.decode('$badFen w - - 0 1'), throwsA(isA<FenParseException>()));
    });
  });
}
