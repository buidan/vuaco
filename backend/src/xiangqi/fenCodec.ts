import { Board } from './board';
import { BOARD_COLUMNS, BOARD_ROWS } from './boardGeometry';
import { Piece, piece as makePiece } from './piece';
import { PieceType } from './pieceType';
import { Side } from './side';

/**
 * Same convention as the client's `lib/domain/fen/fen_codec.dart` and this
 * backend's own Pikafish wrapper (`utils/fen.ts` validates the same shape):
 * K/A/B/N/R/C/P uppercase = Red, lowercase = Black; board field lists ranks
 * top-to-bottom (row 9 first); 'w' = Red to move, 'b' = Black.
 */

const RED_LETTERS: Record<PieceType, string> = {
  general: 'K',
  advisor: 'A',
  elephant: 'B',
  horse: 'N',
  chariot: 'R',
  cannon: 'C',
  soldier: 'P',
};

const LETTER_TO_TYPE: Record<string, PieceType> = Object.fromEntries(
  Object.entries(RED_LETTERS).map(([type, letter]) => [letter, type as PieceType]),
);

export interface DecodedFen {
  board: Board;
  sideToMove: Side;
  halfmoveClock: number;
  fullmoveNumber: number;
}

export function encodeFen(board: Board, sideToMove: Side, halfmoveClock = 0, fullmoveNumber = 1): string {
  const rankStrings: string[] = [];
  for (let row = BOARD_ROWS - 1; row >= 0; row--) {
    let buffer = '';
    let emptyRun = 0;
    for (let col = 0; col < BOARD_COLUMNS; col++) {
      const pc = board.pieceAt({ row, col });
      if (pc === null) {
        emptyRun++;
        continue;
      }
      if (emptyRun > 0) {
        buffer += emptyRun;
        emptyRun = 0;
      }
      const letter = RED_LETTERS[pc.type];
      buffer += pc.side === 'red' ? letter : letter.toLowerCase();
    }
    if (emptyRun > 0) buffer += emptyRun;
    rankStrings.push(buffer);
  }
  const boardField = rankStrings.join('/');
  const sideField = sideToMove === 'red' ? 'w' : 'b';
  return `${boardField} ${sideField} - - ${halfmoveClock} ${fullmoveNumber}`;
}

export function decodeFen(fen: string): DecodedFen {
  const parts = fen.trim().split(/\s+/);
  if (parts.length < 2) throw new Error('FEN must have at least board and side-to-move fields');
  const [boardField, sideField] = parts;

  const rankStrings = boardField!.split('/');
  if (rankStrings.length !== BOARD_ROWS) {
    throw new Error(`Expected ${BOARD_ROWS} ranks separated by "/", got ${rankStrings.length}`);
  }

  const grid: (Piece | null)[][] = Array.from({ length: BOARD_ROWS }, () =>
    Array<Piece | null>(BOARD_COLUMNS).fill(null),
  );

  for (let i = 0; i < rankStrings.length; i++) {
    const row = BOARD_ROWS - 1 - i; // first FEN rank = top = row 9
    let col = 0;
    for (const ch of rankStrings[i]!) {
      const digit = Number.parseInt(ch, 10);
      if (!Number.isNaN(digit)) {
        col += digit;
        continue;
      }
      const type = LETTER_TO_TYPE[ch.toUpperCase()];
      if (type === undefined) throw new Error(`Unknown piece letter "${ch}"`);
      if (col >= BOARD_COLUMNS) throw new Error(`Rank "${rankStrings[i]}" overflows board width`);
      const side: Side = ch === ch.toUpperCase() ? 'red' : 'black';
      grid[row]![col] = makePiece(type, side);
      col++;
    }
    if (col !== BOARD_COLUMNS) {
      throw new Error(`Rank "${rankStrings[i]}" has ${col} squares, expected ${BOARD_COLUMNS}`);
    }
  }

  let side: Side;
  if (sideField === 'w') side = 'red';
  else if (sideField === 'b') side = 'black';
  else throw new Error(`Side-to-move field must be "w" or "b", got "${sideField}"`);

  const halfmoveClock = parts.length > 4 ? Number.parseInt(parts[4]!, 10) || 0 : 0;
  const fullmoveNumber = parts.length > 5 ? Number.parseInt(parts[5]!, 10) || 1 : 1;

  return { board: Board.fromGrid(grid), sideToMove: side, halfmoveClock, fullmoveNumber };
}
