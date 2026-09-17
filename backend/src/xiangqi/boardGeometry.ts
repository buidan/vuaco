import { BoardPoint } from './boardPoint';
import { Side } from './side';

/** Board dimensions and zone rules (river, palace), ported 1:1 from the
 * client's `lib/domain/rules/board_geometry.dart`. Orientation: Red
 * occupies rows 0-4 (bottom), Black occupies rows 5-9 (top); the river
 * lies between row 4 and row 5. */
export const BOARD_COLUMNS = 9; // cols 0-8
export const BOARD_ROWS = 10; // rows 0-9

export const RED_PALACE_MIN_ROW = 0;
export const RED_PALACE_MAX_ROW = 2;
export const BLACK_PALACE_MIN_ROW = 7;
export const BLACK_PALACE_MAX_ROW = 9;
export const PALACE_MIN_COL = 3;
export const PALACE_MAX_COL = 5;

export function isInsideBoard(p: BoardPoint): boolean {
  return p.row >= 0 && p.row < BOARD_ROWS && p.col >= 0 && p.col < BOARD_COLUMNS;
}

export function isInsidePalace(side: Side, p: BoardPoint): boolean {
  if (p.col < PALACE_MIN_COL || p.col > PALACE_MAX_COL) return false;
  return side === 'red'
    ? p.row >= RED_PALACE_MIN_ROW && p.row <= RED_PALACE_MAX_ROW
    : p.row >= BLACK_PALACE_MIN_ROW && p.row <= BLACK_PALACE_MAX_ROW;
}

/** Red advances toward increasing row numbers; Black advances toward
 * decreasing row numbers. */
export function forwardStep(side: Side): number {
  return side === 'red' ? 1 : -1;
}

export function hasCrossedRiver(side: Side, row: number): boolean {
  return side === 'red' ? row >= 5 : row <= 4;
}
