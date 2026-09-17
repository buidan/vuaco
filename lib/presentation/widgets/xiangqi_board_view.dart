import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/board.dart';
import '../../domain/models/board_point.dart';
import '../../domain/models/move.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/piece_type.dart';
import '../../domain/models/side.dart';
import '../../domain/rules/board_geometry.dart';
import '../theme/app_theme.dart';

const Map<PieceType, String> _redGlyphs = {
  PieceType.general: '帥',
  PieceType.advisor: '仕',
  PieceType.elephant: '相',
  PieceType.horse: '馬',
  PieceType.chariot: '俥',
  PieceType.cannon: '炮',
  PieceType.soldier: '兵',
};

const Map<PieceType, String> _blackGlyphs = {
  PieceType.general: '將',
  PieceType.advisor: '士',
  PieceType.elephant: '象',
  PieceType.horse: '馬',
  PieceType.chariot: '車',
  PieceType.cannon: '砲',
  PieceType.soldier: '卒',
};

String glyphFor(Piece piece) =>
    (piece.side == Side.red ? _redGlyphs : _blackGlyphs)[piece.type]!;

/// Maps between board intersections and pixel offsets within the widget's
/// bounds. Red's back rank (row 0) renders at the bottom, matching the fixed
/// orientation documented in `BoardGeometry` - the board does not flip
/// between turns in Phase 1 (see RULES_ENGINE.md).
class BoardLayout {
  final double cellSize;
  final double left;
  final double top;

  const BoardLayout({required this.cellSize, required this.left, required this.top});

  factory BoardLayout.fromSize(Size size) {
    const margin = 28.0;
    final usableW = size.width - margin * 2;
    final usableH = size.height - margin * 2;
    final cell = math.min(usableW / (BoardGeometry.columns - 1), usableH / (BoardGeometry.rows - 1));
    final boardW = cell * (BoardGeometry.columns - 1);
    final boardH = cell * (BoardGeometry.rows - 1);
    return BoardLayout(
      cellSize: cell,
      left: (size.width - boardW) / 2,
      top: (size.height - boardH) / 2,
    );
  }

  Offset pointToOffset(BoardPoint p) =>
      Offset(left + p.col * cellSize, top + (BoardGeometry.rows - 1 - p.row) * cellSize);

  BoardPoint? offsetToPoint(Offset local) {
    final col = ((local.dx - left) / cellSize).round();
    final rowFromTop = ((local.dy - top) / cellSize).round();
    final row = BoardGeometry.rows - 1 - rowFromTop;
    final candidate = BoardPoint(row, col);
    if (!BoardGeometry.isInsideBoard(candidate)) return null;
    if ((pointToOffset(candidate) - local).distance > cellSize * 0.5) return null;
    return candidate;
  }
}

/// One Engine Coach candidate move to draw as an arrow, ranked 1 (best) up.
class CandidateMoveArrow {
  final BoardPoint from;
  final BoardPoint to;
  final int rank;

  const CandidateMoveArrow({required this.from, required this.to, required this.rank});
}

class _CandidateArrowsPainter extends CustomPainter {
  final BoardLayout layout;
  final List<CandidateMoveArrow> candidates;

  _CandidateArrowsPainter({required this.layout, required this.candidates});

  static const List<Color> _rankColors = [
    XiangqiColors.gold,
    XiangqiColors.jade,
    XiangqiColors.crimson,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final candidate in candidates) {
      final color = _rankColors[(candidate.rank - 1).clamp(0, _rankColors.length - 1)];
      final opacity = candidate.rank == 1 ? 0.85 : 0.55;
      _drawArrow(
        canvas,
        layout.pointToOffset(candidate.from),
        layout.pointToOffset(candidate.to),
        color.withValues(alpha: opacity),
        strokeWidth: candidate.rank == 1 ? 5 : 3.5,
        headSize: layout.cellSize * 0.22,
      );
    }
  }

  void _drawArrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color, {
    required double strokeWidth,
    required double headSize,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);

    final angle = (to - from).direction;
    final headPaint = Paint()..color = color;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - headSize * math.cos(angle - math.pi / 7),
        to.dy - headSize * math.sin(angle - math.pi / 7),
      )
      ..lineTo(
        to.dx - headSize * math.cos(angle + math.pi / 7),
        to.dy - headSize * math.sin(angle + math.pi / 7),
      )
      ..close();
    canvas.drawPath(path, headPaint);
  }

  @override
  bool shouldRepaint(covariant _CandidateArrowsPainter oldDelegate) => oldDelegate.candidates != candidates;
}

class _BoardGridPainter extends CustomPainter {
  final BoardLayout layout;
  final BoardPoint? selected;
  final List<BoardPoint> legalDestinations;
  final Board board;
  final BoardPoint? redGeneral;
  final BoardPoint? blackGeneral;
  final bool redInCheck;
  final bool blackInCheck;

  _BoardGridPainter({
    required this.layout,
    required this.selected,
    required this.legalDestinations,
    required this.board,
    required this.redGeneral,
    required this.blackGeneral,
    required this.redInCheck,
    required this.blackInCheck,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Rect.fromLTRB(
      layout.left - layout.cellSize * 0.5,
      layout.top - layout.cellSize * 0.5,
      layout.left + (BoardGeometry.columns - 1) * layout.cellSize + layout.cellSize * 0.5,
      layout.top + (BoardGeometry.rows - 1) * layout.cellSize + layout.cellSize * 0.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, Radius.circular(layout.cellSize * 0.25)),
      Paint()..color = XiangqiColors.parchment,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, Radius.circular(layout.cellSize * 0.25)),
      Paint()
        ..color = XiangqiColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final linePaint = Paint()
      ..color = XiangqiColors.mahogany.withValues(alpha: 0.75)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Horizontal lines run uninterrupted across every row.
    for (var row = 0; row < BoardGeometry.rows; row++) {
      final y = layout.pointToOffset(BoardPoint(row, 0)).dy;
      canvas.drawLine(
        Offset(layout.left, y),
        Offset(layout.left + (BoardGeometry.columns - 1) * layout.cellSize, y),
        linePaint,
      );
    }

    // Vertical lines: the two outer files run the full height; the seven
    // inner files break for the river gap between row 4 and row 5.
    for (var col = 0; col < BoardGeometry.columns; col++) {
      final x = layout.left + col * layout.cellSize;
      if (col == 0 || col == BoardGeometry.columns - 1) {
        canvas.drawLine(
          Offset(x, layout.pointToOffset(BoardPoint(0, col)).dy),
          Offset(x, layout.pointToOffset(BoardPoint(BoardGeometry.rows - 1, col)).dy),
          linePaint,
        );
      } else {
        canvas.drawLine(
          Offset(x, layout.pointToOffset(BoardPoint(0, col)).dy),
          Offset(x, layout.pointToOffset(BoardPoint(4, col)).dy),
          linePaint,
        );
        canvas.drawLine(
          Offset(x, layout.pointToOffset(BoardPoint(5, col)).dy),
          Offset(x, layout.pointToOffset(BoardPoint(BoardGeometry.rows - 1, col)).dy),
          linePaint,
        );
      }
    }

    void drawPalaceCross(int minRow, int maxRow) {
      final a = layout.pointToOffset(BoardPoint(minRow, 3));
      final b = layout.pointToOffset(BoardPoint(maxRow, 5));
      final c = layout.pointToOffset(BoardPoint(minRow, 5));
      final d = layout.pointToOffset(BoardPoint(maxRow, 3));
      canvas.drawLine(a, b, linePaint);
      canvas.drawLine(c, d, linePaint);
    }

    drawPalaceCross(0, 2);
    drawPalaceCross(7, 9);

    // Check highlight: a soft red glow behind the checked general.
    void drawCheckGlow(BoardPoint? point, bool inCheck) {
      if (point == null || !inCheck) return;
      final center = layout.pointToOffset(point);
      canvas.drawCircle(
        center,
        layout.cellSize * 0.55,
        Paint()..color = XiangqiColors.crimson.withValues(alpha: 0.45),
      );
    }

    drawCheckGlow(redGeneral, redInCheck);
    drawCheckGlow(blackGeneral, blackInCheck);

    // Selected point ring.
    if (selected != null) {
      canvas.drawCircle(
        layout.pointToOffset(selected!),
        layout.cellSize * 0.42,
        Paint()
          ..color = XiangqiColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Legal destination markers.
    for (final dest in legalDestinations) {
      final center = layout.pointToOffset(dest);
      final occupied = board.pieceAt(dest) != null;
      if (occupied) {
        canvas.drawCircle(
          center,
          layout.cellSize * 0.42,
          Paint()
            ..color = XiangqiColors.jade
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      } else {
        canvas.drawCircle(center, layout.cellSize * 0.12, Paint()..color = XiangqiColors.jade);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardGridPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.legalDestinations != legalDestinations ||
        oldDelegate.board != board ||
        oldDelegate.redInCheck != redInCheck ||
        oldDelegate.blackInCheck != blackInCheck;
  }
}

class PieceDisc extends StatelessWidget {
  final Piece piece;
  final double size;

  const PieceDisc({super.key, required this.piece, required this.size});

  @override
  Widget build(BuildContext context) {
    final isRed = piece.side == Side.red;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: XiangqiColors.parchment,
        border: Border.all(color: XiangqiColors.gold, width: size * 0.06),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2))],
      ),
      alignment: Alignment.center,
      child: Text(
        glyphFor(piece),
        style: TextStyle(
          color: isRed ? XiangqiColors.crimson : XiangqiColors.mahogany,
          fontSize: size * 0.52,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Renders the board grid plus every piece, animating the piece that just
/// moved (per [lastMove]) sliding from its origin to its destination.
/// Undo/redo/new-game pass a null [lastMove], so pieces there simply snap to
/// their restored positions.
class XiangqiBoardView extends StatelessWidget {
  final Board board;
  final BoardPoint? selected;
  final List<BoardPoint> legalDestinations;
  final bool redInCheck;
  final bool blackInCheck;
  final Move? lastMove;
  final int moveSerial;
  final List<CandidateMoveArrow> candidateMoves;
  final void Function(BoardPoint point) onTapPoint;

  const XiangqiBoardView({
    super.key,
    required this.board,
    required this.selected,
    required this.legalDestinations,
    required this.redInCheck,
    required this.blackInCheck,
    required this.lastMove,
    required this.moveSerial,
    required this.onTapPoint,
    this.candidateMoves = const [],
  });

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
                painter: _BoardGridPainter(
                  layout: layout,
                  selected: selected,
                  legalDestinations: legalDestinations,
                  board: board,
                  redGeneral: board.findGeneral(Side.red),
                  blackGeneral: board.findGeneral(Side.black),
                  redInCheck: redInCheck,
                  blackInCheck: blackInCheck,
                ),
              ),
            ),
          ];

          for (final entry in board.occupiedSquares) {
            final isAnimatingPiece = lastMove != null && entry.key == lastMove!.to;
            if (isAnimatingPiece) continue; // rendered separately below, animated
            final offset = layout.pointToOffset(entry.key);
            children.add(Positioned(
              left: offset.dx - pieceSize / 2,
              top: offset.dy - pieceSize / 2,
              child: PieceDisc(piece: entry.value, size: pieceSize),
            ));
          }

          if (lastMove != null) {
            final movedPiece = board.pieceAt(lastMove!.to);
            if (movedPiece != null) {
              children.add(TweenAnimationBuilder<Offset>(
                key: ValueKey(moveSerial),
                tween: Tween(
                  begin: layout.pointToOffset(lastMove!.from),
                  end: layout.pointToOffset(lastMove!.to),
                ),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                builder: (context, offset, child) => Positioned(
                  left: offset.dx - pieceSize / 2,
                  top: offset.dy - pieceSize / 2,
                  child: child!,
                ),
                child: PieceDisc(piece: movedPiece, size: pieceSize),
              ));
            }
          }

          if (candidateMoves.isNotEmpty) {
            children.add(Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CandidateArrowsPainter(layout: layout, candidates: candidateMoves),
                ),
              ),
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
