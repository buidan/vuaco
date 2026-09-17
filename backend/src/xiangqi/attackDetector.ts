import { Board } from './board';
import { BoardPoint } from './boardPoint';
import { pseudoLegalDestinations } from './pieceMoves';
import { opponent, Side } from './side';

/** Ported 1:1 from `lib/domain/rules/attack_detector.dart`. */

export function isSquareAttackedBy(board: Board, attacker: Side, target: BoardPoint): boolean {
  for (const [from, pc] of board.occupiedSquares()) {
    if (pc.side !== attacker) continue;
    if (pseudoLegalDestinations(board, from).some((d) => d.row === target.row && d.col === target.col)) {
      return true;
    }
  }
  return false;
}

/** The "flying general" rule: the two generals may never face each other
 * on the same open column with no piece between them. Whole-board
 * validation, not a per-piece movement rule, because neither general can
 * normally attack at range - this facing condition IS the illegal state,
 * and counts as delivering check to whichever side is about to move into
 * or already sits in it. */
export function isFlyingGeneralFacing(board: Board): boolean {
  const red = board.findGeneral('red');
  const black = board.findGeneral('black');
  if (red === null || black === null) return false;
  if (red.col !== black.col) return false;
  const col = red.col;
  const lowRow = Math.min(red.row, black.row);
  const highRow = Math.max(red.row, black.row);
  for (let r = lowRow + 1; r < highRow; r++) {
    if (board.pieceAt({ row: r, col }) !== null) return false;
  }
  return true;
}

export function isGeneralInCheck(board: Board, side: Side): boolean {
  const general = board.findGeneral(side);
  if (general === null) return false;
  if (isSquareAttackedBy(board, opponent(side), general)) return true;
  if (isFlyingGeneralFacing(board)) return true;
  return false;
}
