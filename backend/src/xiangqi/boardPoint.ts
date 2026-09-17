/** A single intersection on the 9x10 Xiangqi grid. `row` 0-9 (0 = Red's
 * back rank), `col` 0-8. Plain, comparable-by-value via `pointKey`/`pointsEqual`
 * since TS objects don't get structural `==` the way the Dart `BoardPoint`
 * does. */
export interface BoardPoint {
  readonly row: number;
  readonly col: number;
}

export function point(row: number, col: number): BoardPoint {
  return { row, col };
}

export function translate(p: BoardPoint, deltaRow: number, deltaCol: number): BoardPoint {
  return { row: p.row + deltaRow, col: p.col + deltaCol };
}

export function pointsEqual(a: BoardPoint, b: BoardPoint): boolean {
  return a.row === b.row && a.col === b.col;
}

/** Stable string key for using BoardPoints in Sets/Maps. */
export function pointKey(p: BoardPoint): string {
  return `${p.row},${p.col}`;
}
