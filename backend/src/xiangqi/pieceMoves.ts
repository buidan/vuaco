import { Board } from './board';
import { hasCrossedRiver, isInsideBoard, isInsidePalace } from './boardGeometry';
import { BoardPoint, translate } from './boardPoint';
import { Side } from './side';

/** Pseudo-legal move generation, ported 1:1 from the client's
 * `lib/domain/rules/piece_moves.dart`. Obeys each piece's own movement
 * shape, blocking, and zone rules - but does NOT check whether the move
 * would leave the mover's own general in check; `legalMoveGenerator.ts`
 * does that by simulating the move against the whole board. */

const ORTHOGONAL_DIRECTIONS: ReadonlyArray<[number, number]> = [
  [1, 0],
  [-1, 0],
  [0, 1],
  [0, -1],
];
const DIAGONAL_DIRECTIONS: ReadonlyArray<[number, number]> = [
  [1, 1],
  [1, -1],
  [-1, 1],
  [-1, -1],
];
const ELEPHANT_DIRECTIONS: ReadonlyArray<[number, number]> = [
  [2, 2],
  [2, -2],
  [-2, 2],
  [-2, -2],
];
const HORSE_DIRECTIONS: ReadonlyArray<[number, number]> = [
  [1, 2],
  [1, -2],
  [-1, 2],
  [-1, -2],
  [2, 1],
  [2, -1],
  [-2, 1],
  [-2, -1],
];

function canLandOn(board: Board, side: Side, p: BoardPoint): boolean {
  const occupant = board.pieceAt(p);
  return occupant === null || occupant.side !== side;
}

export function pseudoLegalDestinations(board: Board, from: BoardPoint): BoardPoint[] {
  const pc = board.pieceAt(from);
  if (pc === null) return [];
  switch (pc.type) {
    case 'general':
      return generalMoves(board, from, pc.side);
    case 'advisor':
      return advisorMoves(board, from, pc.side);
    case 'elephant':
      return elephantMoves(board, from, pc.side);
    case 'horse':
      return horseMoves(board, from, pc.side);
    case 'chariot':
      return slidingMoves(board, from, pc.side, ORTHOGONAL_DIRECTIONS);
    case 'cannon':
      return cannonMoves(board, from, pc.side);
    case 'soldier':
      return soldierMoves(board, from, pc.side);
  }
}

function generalMoves(board: Board, from: BoardPoint, side: Side): BoardPoint[] {
  const moves: BoardPoint[] = [];
  for (const [dr, dc] of ORTHOGONAL_DIRECTIONS) {
    const dest = translate(from, dr, dc);
    if (!isInsidePalace(side, dest)) continue;
    if (canLandOn(board, side, dest)) moves.push(dest);
  }
  return moves;
}

function advisorMoves(board: Board, from: BoardPoint, side: Side): BoardPoint[] {
  const moves: BoardPoint[] = [];
  for (const [dr, dc] of DIAGONAL_DIRECTIONS) {
    const dest = translate(from, dr, dc);
    if (!isInsidePalace(side, dest)) continue;
    if (canLandOn(board, side, dest)) moves.push(dest);
  }
  return moves;
}

function elephantMoves(board: Board, from: BoardPoint, side: Side): BoardPoint[] {
  const moves: BoardPoint[] = [];
  for (const [dr, dc] of ELEPHANT_DIRECTIONS) {
    const dest = translate(from, dr, dc);
    if (!isInsideBoard(dest)) continue;
    if (hasCrossedRiver(side, dest.row)) continue; // never crosses the river
    const eye = translate(from, dr / 2, dc / 2);
    if (board.pieceAt(eye) !== null) continue; // blocked at the elephant eye
    if (canLandOn(board, side, dest)) moves.push(dest);
  }
  return moves;
}

function horseMoves(board: Board, from: BoardPoint, side: Side): BoardPoint[] {
  const moves: BoardPoint[] = [];
  for (const [dr, dc] of HORSE_DIRECTIONS) {
    const dest = translate(from, dr, dc);
    if (!isInsideBoard(dest)) continue;
    // The "leg" is the orthogonal square along the longer axis of the L.
    const leg = Math.abs(dr) === 2 ? translate(from, dr / 2, 0) : translate(from, 0, dc / 2);
    if (board.pieceAt(leg) !== null) continue; // blocked at the horse leg
    if (canLandOn(board, side, dest)) moves.push(dest);
  }
  return moves;
}

function slidingMoves(
  board: Board,
  from: BoardPoint,
  side: Side,
  directions: ReadonlyArray<[number, number]>,
): BoardPoint[] {
  const moves: BoardPoint[] = [];
  for (const [dr, dc] of directions) {
    let step = 1;
    while (true) {
      const dest = translate(from, dr * step, dc * step);
      if (!isInsideBoard(dest)) break;
      const occupant = board.pieceAt(dest);
      if (occupant === null) {
        moves.push(dest);
      } else {
        if (occupant.side !== side) moves.push(dest); // capture
        break; // blocked either way past this point
      }
      step++;
    }
  }
  return moves;
}

function cannonMoves(board: Board, from: BoardPoint, side: Side): BoardPoint[] {
  const moves: BoardPoint[] = [];
  for (const [dr, dc] of ORTHOGONAL_DIRECTIONS) {
    let step = 1;
    let screenFound = false;
    while (true) {
      const dest = translate(from, dr * step, dc * step);
      if (!isInsideBoard(dest)) break;
      const occupant = board.pieceAt(dest);
      if (!screenFound) {
        if (occupant === null) {
          moves.push(dest); // ordinary slide, no jump yet
        } else {
          screenFound = true; // this piece becomes the screen
        }
      } else {
        if (occupant !== null) {
          if (occupant.side !== side) moves.push(dest); // capture over the screen
          break; // a second piece always blocks further travel
        }
      }
      step++;
    }
  }
  return moves;
}

function soldierMoves(board: Board, from: BoardPoint, side: Side): BoardPoint[] {
  const moves: BoardPoint[] = [];
  const forward = translate(from, side === 'red' ? 1 : -1, 0);
  if (isInsideBoard(forward) && canLandOn(board, side, forward)) {
    moves.push(forward);
  }
  if (hasCrossedRiver(side, from.row)) {
    for (const dc of [1, -1]) {
      const dest = translate(from, 0, dc);
      if (isInsideBoard(dest) && canLandOn(board, side, dest)) moves.push(dest);
    }
  }
  return moves;
}
