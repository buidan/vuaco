import { BoardPoint } from './boardPoint';
import { Piece } from './piece';

export interface Move {
  readonly from: BoardPoint;
  readonly to: BoardPoint;
  readonly movedPiece: Piece;
  readonly capturedPiece: Piece | null;
}

export function isCapture(move: Move): boolean {
  return move.capturedPiece !== null;
}
