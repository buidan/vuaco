/// Why a proposed move was rejected. Granular enough for the future Engine
/// Coach to explain blunders/illegal attempts without re-deriving the reason.
enum IllegalMoveReason {
  gameAlreadyOver,
  noPieceAtSource,
  notYourTurn,

  /// The piece's own movement pattern forbids this destination (wrong shape,
  /// blocked path, elephant eye blocked, horse leg blocked, leaves its
  /// palace, crosses the river, moves backward, etc).
  illegalPieceMovement,

  /// The destination is reachable by the piece's movement pattern, but
  /// making the move would leave the mover's own general in check -
  /// including the flying-general (facing generals) condition.
  leavesGeneralInCheck,
}
