import { IllegalMoveReason } from './illegalMoveReason';
import { Move } from './move';

export type MoveValidationResult =
  | { readonly kind: 'legal'; readonly move: Move; readonly leavesOpponentInCheck: boolean; readonly endsGame: boolean }
  | { readonly kind: 'illegal'; readonly reason: IllegalMoveReason; readonly message: string };
