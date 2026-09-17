import { PieceType } from './pieceType';
import { Side } from './side';

export interface Piece {
  readonly type: PieceType;
  readonly side: Side;
}

export function piece(type: PieceType, side: Side): Piece {
  return { type, side };
}
