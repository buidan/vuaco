import { BOARD_COLUMNS, BOARD_ROWS, isInsideBoard } from './boardGeometry';
import { BoardPoint, point } from './boardPoint';
import { Piece, piece as makePiece } from './piece';
import { PieceType } from './pieceType';
import { Side } from './side';

/** Immutable-by-convention snapshot of every piece's position, ported 1:1
 * from `lib/domain/models/board.dart`. Every "mutating" method returns a
 * new Board rather than modifying this one. */
export class Board {
  private readonly grid: ReadonlyArray<ReadonlyArray<Piece | null>>;

  private constructor(grid: ReadonlyArray<ReadonlyArray<Piece | null>>) {
    this.grid = grid;
  }

  static empty(): Board {
    const grid: (Piece | null)[][] = Array.from({ length: BOARD_ROWS }, () =>
      Array<Piece | null>(BOARD_COLUMNS).fill(null),
    );
    return new Board(grid);
  }

  static fromGrid(grid: ReadonlyArray<ReadonlyArray<Piece | null>>): Board {
    if (grid.length !== BOARD_ROWS) {
      throw new Error(`Expected ${BOARD_ROWS} rows, got ${grid.length}`);
    }
    const copy = grid.map((row) => {
      if (row.length !== BOARD_COLUMNS) {
        throw new Error(`Expected ${BOARD_COLUMNS} columns, got ${row.length}`);
      }
      return [...row];
    });
    return new Board(copy);
  }

  static initial(): Board {
    const grid: (Piece | null)[][] = Array.from({ length: BOARD_ROWS }, () =>
      Array<Piece | null>(BOARD_COLUMNS).fill(null),
    );
    const put = (row: number, col: number, type: PieceType, side: Side) => {
      grid[row]![col] = makePiece(type, side);
    };

    for (const side of ['red', 'black'] as const) {
      const backRank = side === 'red' ? 0 : 9;
      const cannonRow = side === 'red' ? 2 : 7;
      const soldierRow = side === 'red' ? 3 : 6;

      put(backRank, 0, 'chariot', side);
      put(backRank, 1, 'horse', side);
      put(backRank, 2, 'elephant', side);
      put(backRank, 3, 'advisor', side);
      put(backRank, 4, 'general', side);
      put(backRank, 5, 'advisor', side);
      put(backRank, 6, 'elephant', side);
      put(backRank, 7, 'horse', side);
      put(backRank, 8, 'chariot', side);

      put(cannonRow, 1, 'cannon', side);
      put(cannonRow, 7, 'cannon', side);

      for (const col of [0, 2, 4, 6, 8]) {
        put(soldierRow, col, 'soldier', side);
      }
    }

    return new Board(grid);
  }

  pieceAt(p: BoardPoint): Piece | null {
    if (!isInsideBoard(p)) return null;
    return this.grid[p.row]![p.col]!;
  }

  withPieceAt(p: BoardPoint, newPiece: Piece | null): Board {
    const newGrid = this.grid.map((row) => [...row]);
    newGrid[p.row]![p.col] = newPiece;
    return new Board(newGrid);
  }

  applyMove(from: BoardPoint, to: BoardPoint): Board {
    const moving = this.pieceAt(from);
    const newGrid = this.grid.map((row) => [...row]);
    newGrid[to.row]![to.col] = moving;
    newGrid[from.row]![from.col] = null;
    return new Board(newGrid);
  }

  findGeneral(side: Side): BoardPoint | null {
    for (let r = 0; r < BOARD_ROWS; r++) {
      for (let c = 0; c < BOARD_COLUMNS; c++) {
        const p = this.grid[r]![c]!;
        if (p !== null && p.type === 'general' && p.side === side) return point(r, c);
      }
    }
    return null;
  }

  *occupiedSquares(): IterableIterator<[BoardPoint, Piece]> {
    for (let r = 0; r < BOARD_ROWS; r++) {
      for (let c = 0; c < BOARD_COLUMNS; c++) {
        const p = this.grid[r]![c]!;
        if (p !== null) yield [point(r, c), p];
      }
    }
  }

  piecesOf(side: Side): BoardPoint[] {
    const result: BoardPoint[] = [];
    for (const [p, pc] of this.occupiedSquares()) {
      if (pc.side === side) result.push(p);
    }
    return result;
  }
}
