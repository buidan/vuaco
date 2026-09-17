import { opponent, Side } from './side';

export type GameOutcome = 'ongoing' | 'redWins' | 'blackWins' | 'draw';
export type GameEndReason = 'checkmate' | 'noLegalMoves' | 'timeout' | 'resignation';

export interface GameResult {
  readonly outcome: GameOutcome;
  readonly reason: GameEndReason | null;
}

export const ONGOING: GameResult = { outcome: 'ongoing', reason: null };

export function winResult(winner: Side, reason: GameEndReason): GameResult {
  return { outcome: winner === 'red' ? 'redWins' : 'blackWins', reason };
}

export function isOngoing(result: GameResult): boolean {
  return result.outcome === 'ongoing';
}

export function winnerOf(result: GameResult): Side | null {
  if (result.outcome === 'redWins') return 'red';
  if (result.outcome === 'blackWins') return 'black';
  return null;
}

/** Convenience for "the side to move has no legal moves" callers, mirroring
 * `XiangqiEngine._computeResult` in the Dart engine. */
export function resultForNoMoves(sideToMove: Side, inCheck: boolean): GameResult {
  return winResult(opponent(sideToMove), inCheck ? 'checkmate' : 'noLegalMoves');
}
