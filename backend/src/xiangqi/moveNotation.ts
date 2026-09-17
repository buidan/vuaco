import { BoardPoint, point } from './boardPoint';
import { isCapture, Move } from './move';

/** Ported from `lib/domain/notation/move_notation.dart`. Plain coordinate
 * notation (file a-i, rank 0-9) - this happens to be the same alphabet UCI
 * engines like Pikafish use for their coordinate moves, which is why
 * `parseSquare`/`parseUciMove` round-trip against it. */

export function squareLabel(p: BoardPoint): string {
  return `${String.fromCharCode(97 + p.col)}${p.row}`;
}

export function forMove(move: Move, opts: { isCheck?: boolean; isCheckmate?: boolean } = {}): string {
  const separator = isCapture(move) ? 'x' : '-';
  const base = `${squareLabel(move.from)}${separator}${squareLabel(move.to)}`;
  if (opts.isCheckmate) return `${base}#`;
  if (opts.isCheck) return `${base}+`;
  return base;
}

export function parseSquare(label: string): BoardPoint {
  if (label.length < 2) throw new Error(`Invalid square label "${label}"`);
  const col = label.charCodeAt(0) - 97; // 'a' = 0
  const row = Number.parseInt(label.slice(1), 10);
  return point(row, col);
}

export function parseUciMove(move: string): { from: BoardPoint; to: BoardPoint } {
  if (move.length !== 4) throw new Error(`Invalid UCI move "${move}"`);
  return { from: parseSquare(move.slice(0, 2)), to: parseSquare(move.slice(2, 4)) };
}
