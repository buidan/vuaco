/** Why a proposed move was rejected. Ported from
 * `lib/domain/models/illegal_move_reason.dart`. */
export type IllegalMoveReason =
  | 'gameAlreadyOver'
  | 'noPieceAtSource'
  | 'notYourTurn'
  | 'illegalPieceMovement'
  | 'leavesGeneralInCheck';
