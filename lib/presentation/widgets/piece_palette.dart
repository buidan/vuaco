import 'package:flutter/material.dart';

import '../../domain/models/piece.dart';
import '../../domain/models/piece_type.dart';
import '../../domain/models/side.dart';
import '../theme/app_theme.dart';
import 'xiangqi_board_view.dart';

/// Lets the board-setup screen pick which piece to stamp down next, or the
/// eraser to clear a square. One disc per (type, side) combination, reusing
/// [PieceDisc] so a palette piece looks exactly like its on-board twin.
class PiecePalette extends StatelessWidget {
  final Piece? selectedPiece;
  final bool eraserSelected;
  final ValueChanged<Piece> onSelectPiece;
  final VoidCallback onSelectEraser;

  const PiecePalette({
    super.key,
    required this.selectedPiece,
    required this.eraserSelected,
    required this.onSelectPiece,
    required this.onSelectEraser,
  });

  static const double _discSize = 40;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final side in Side.values)
          for (final type in PieceType.values) _paletteEntry(context, Piece(type, side)),
        _eraserEntry(context),
      ],
    );
  }

  Widget _paletteEntry(BuildContext context, Piece piece) {
    final isSelected = !eraserSelected && selectedPiece?.type == piece.type && selectedPiece?.side == piece.side;
    return GestureDetector(
      onTap: () => onSelectPiece(piece),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? XiangqiColors.gold : Colors.transparent, width: 3),
        ),
        child: PieceDisc(piece: piece, size: _discSize),
      ),
    );
  }

  Widget _eraserEntry(BuildContext context) {
    return GestureDetector(
      onTap: onSelectEraser,
      child: Container(
        width: _discSize,
        height: _discSize,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: eraserSelected ? XiangqiColors.gold : Colors.transparent, width: 3),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: XiangqiColors.walnut,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.close, color: XiangqiColors.parchment, size: 20),
        ),
      ),
    );
  }
}
