/// A single intersection on the 9x10 Xiangqi grid.
///
/// `row` runs 0-9: row 0 is Red's back rank (bottom of the board as rendered),
/// row 9 is Black's back rank (top). `col` runs 0-8, left to right.
class BoardPoint {
  final int row;
  final int col;

  const BoardPoint(this.row, this.col);

  BoardPoint translate(int deltaRow, int deltaCol) =>
      BoardPoint(row + deltaRow, col + deltaCol);

  @override
  bool operator ==(Object other) =>
      other is BoardPoint && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}
