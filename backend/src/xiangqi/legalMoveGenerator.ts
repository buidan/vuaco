import { isGeneralInCheck } from './attackDetector';
import { Board } from './board';
import { BoardPoint } from './boardPoint';
import { Move } from './move';
import { pseudoLegalDestinations } from './pieceMoves';
import { Side } from './side';

/** Ported 1:1 from `lib/domain/rules/legal_move_generator.dart`: filters
 * pseudo-legal moves through a simulated-check test, which by construction
 * also covers the flying-general facing condition. */

export function legalDestinationsFrom(board: Board, from: BoardPoint, sideToMove: Side): BoardPoint[] {
  const pc = board.pieceAt(from);
  if (pc === null || pc.side !== sideToMove) return [];
  return pseudoLegalDestinations(board, from).filter((to) => {
    const next = board.applyMove(from, to);
    return !isGeneralInCheck(next, sideToMove);
  });
}

export function allLegalMoves(board: Board, sideToMove: Side): Move[] {
  const moves: Move[] = [];
  for (const [from, pc] of board.occupiedSquares()) {
    if (pc.side !== sideToMove) continue;
    for (const to of legalDestinationsFrom(board, from, sideToMove)) {
      moves.push({ from, to, movedPiece: pc, capturedPiece: board.pieceAt(to) });
    }
  }
  return moves;
}

export function hasAnyLegalMove(board: Board, sideToMove: Side): boolean {
  for (const [from, pc] of board.occupiedSquares()) {
    if (pc.side !== sideToMove) continue;
    if (legalDestinationsFrom(board, from, sideToMove).length > 0) return true;
  }
  return false;
}
