import 'package:flutter/material.dart';

import '../../domain/models/board.dart';
import '../../domain/models/board_point.dart';
import '../../domain/rules/board_geometry.dart';
import 'xiangqi_board_view.dart';

/// Static (non-animated) board for the setup/edit flow: tapping a point
/// stamps down whatever the piece palette has selected, or erases it -
/// there's no move validation, turns, or highlighting here, so this is
/// deliberately a much thinner widget than [XiangqiBoardView], sharing only
/// the grid painter and piece rendering.
class BoardEditorView extends StatelessWidget {
  final Board board;
  final void Function(BoardPoint point) onTapPoint;

  const BoardEditorView({super.key, required this.board, required this.onTapPoint});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: (BoardGeometry.columns - 1 + 1) / (BoardGeometry.rows - 1 + 1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final layout = BoardLayout.fromSize(size);
          final pieceSize = layout.cellSize * 0.82;

          final children = <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: BoardGridPainter(
                  layout: layout,
                  selected: null,
                  legalDestinations: const [],
                  board: board,
                  redGeneral: null,
                  blackGeneral: null,
                  redInCheck: false,
                  blackInCheck: false,
                ),
              ),
            ),
          ];

          for (final entry in board.occupiedSquares) {
            final offset = layout.pointToOffset(entry.key);
            children.add(Positioned(
              left: offset.dx - pieceSize / 2,
              top: offset.dy - pieceSize / 2,
              child: PieceDisc(piece: entry.value, size: pieceSize),
            ));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final point = layout.offsetToPoint(details.localPosition);
              if (point != null) onTapPoint(point);
            },
            child: Stack(children: children),
          );
        },
      ),
    );
  }
}
