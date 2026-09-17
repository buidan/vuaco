import 'piece_type.dart';
import 'side.dart';

/// An immutable piece: its type plus which side owns it.
class Piece {
  final PieceType type;
  final Side side;

  const Piece(this.type, this.side);

  @override
  bool operator ==(Object other) =>
      other is Piece && other.type == type && other.side == side;

  @override
  int get hashCode => Object.hash(type, side);

  @override
  String toString() => '${side.name}.${type.name}';
}
