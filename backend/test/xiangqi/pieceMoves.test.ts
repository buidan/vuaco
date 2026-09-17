import { describe, expect, it } from 'vitest';

import { Board } from '../../src/xiangqi/board';
import { point } from '../../src/xiangqi/boardPoint';
import { piece } from '../../src/xiangqi/piece';
import { pseudoLegalDestinations } from '../../src/xiangqi/pieceMoves';

function toSet(points: ReturnType<typeof pseudoLegalDestinations>) {
  return new Set(points.map((p) => `${p.row},${p.col}`));
}

describe('General', () => {
  it('moves one point orthogonally within an empty palace', () => {
    const board = Board.empty().withPieceAt(point(1, 4), piece('general', 'red'));
    expect(toSet(pseudoLegalDestinations(board, point(1, 4)))).toEqual(
      new Set(['0,4', '2,4', '1,3', '1,5']),
    );
  });

  it('cannot leave the palace under any circumstance', () => {
    const board = Board.empty().withPieceAt(point(2, 4), piece('general', 'red'));
    const moves = pseudoLegalDestinations(board, point(2, 4));
    expect(moves.some((m) => m.row === 3 && m.col === 4)).toBe(false);
  });
});

describe('Advisor', () => {
  it('cannot step outside the palace', () => {
    const board = Board.empty().withPieceAt(point(0, 3), piece('advisor', 'red'));
    expect(toSet(pseudoLegalDestinations(board, point(0, 3)))).toEqual(new Set(['1,4']));
  });
});

describe('Elephant', () => {
  it('is blocked by a piece sitting on the elephant eye', () => {
    let board = Board.empty().withPieceAt(point(2, 4), piece('elephant', 'red'));
    board = board.withPieceAt(point(3, 5), piece('soldier', 'black'));
    const moves = toSet(pseudoLegalDestinations(board, point(2, 4)));
    expect(moves.has('4,6')).toBe(false);
    expect(moves).toEqual(new Set(['0,2', '0,6', '4,2']));
  });

  it('cannot cross the river even if the eye is clear', () => {
    const board = Board.empty().withPieceAt(point(4, 4), piece('elephant', 'red'));
    expect(toSet(pseudoLegalDestinations(board, point(4, 4)))).toEqual(new Set(['2,2', '2,6']));
  });
});

describe('Horse', () => {
  it('is blocked by a piece on the horse leg, even though the destination is empty', () => {
    let board = Board.empty().withPieceAt(point(4, 4), piece('horse', 'red'));
    board = board.withPieceAt(point(5, 4), piece('soldier', 'black'));
    const moves = toSet(pseudoLegalDestinations(board, point(4, 4)));
    expect(moves.has('6,5')).toBe(false);
    expect(moves.has('6,3')).toBe(false);
    expect(moves.has('5,6')).toBe(true);
  });

  it('a piece on the destination square itself does not block the leg check', () => {
    let board = Board.empty().withPieceAt(point(4, 4), piece('horse', 'red'));
    board = board.withPieceAt(point(6, 5), piece('soldier', 'black'));
    const moves = toSet(pseudoLegalDestinations(board, point(4, 4)));
    expect(moves.has('6,5')).toBe(true); // capture, not blocked
  });
});

describe('Chariot', () => {
  it('is blocked by the first piece in its path and cannot jump over it', () => {
    let board = Board.empty().withPieceAt(point(4, 4), piece('chariot', 'red'));
    board = board.withPieceAt(point(4, 6), piece('soldier', 'black'));
    const moves = toSet(pseudoLegalDestinations(board, point(4, 4)));
    expect(moves.has('4,5')).toBe(true);
    expect(moves.has('4,6')).toBe(true); // capture
    expect(moves.has('4,7')).toBe(false); // beyond the captured piece
  });
});

describe('Cannon', () => {
  it('slides without capturing when the path is clear', () => {
    const board = Board.empty().withPieceAt(point(4, 4), piece('cannon', 'red'));
    const moves = toSet(pseudoLegalDestinations(board, point(4, 4)));
    expect(moves.has('4,8')).toBe(true);
  });

  it('captures by jumping exactly one screen piece', () => {
    let board = Board.empty().withPieceAt(point(4, 4), piece('cannon', 'red'));
    board = board.withPieceAt(point(4, 6), piece('soldier', 'black'));
    board = board.withPieceAt(point(4, 8), piece('soldier', 'black'));
    const moves = toSet(pseudoLegalDestinations(board, point(4, 4)));
    expect(moves.has('4,8')).toBe(true);
    expect(moves.has('4,7')).toBe(false); // empty square beyond the screen, not a landing spot
  });

  it('cannot capture with two pieces between it and the target', () => {
    let board = Board.empty().withPieceAt(point(4, 4), piece('cannon', 'red'));
    board = board.withPieceAt(point(4, 5), piece('soldier', 'black'));
    board = board.withPieceAt(point(4, 6), piece('soldier', 'red'));
    board = board.withPieceAt(point(4, 7), piece('soldier', 'black'));
    const moves = toSet(pseudoLegalDestinations(board, point(4, 4)));
    expect(moves.has('4,6')).toBe(false);
    expect(moves.has('4,7')).toBe(false);
  });
});

describe('Soldier', () => {
  it('can only step forward before crossing the river', () => {
    const board = Board.empty().withPieceAt(point(3, 4), piece('soldier', 'red'));
    expect(toSet(pseudoLegalDestinations(board, point(3, 4)))).toEqual(new Set(['4,4']));
  });

  it('gains sideways moves after crossing the river, but never moves backward', () => {
    const board = Board.empty().withPieceAt(point(5, 4), piece('soldier', 'red'));
    const moves = toSet(pseudoLegalDestinations(board, point(5, 4)));
    expect(moves).toEqual(new Set(['6,4', '5,3', '5,5']));
    expect(moves.has('4,4')).toBe(false);
  });

  it('Black soldier advances toward decreasing rows', () => {
    const board = Board.empty().withPieceAt(point(6, 4), piece('soldier', 'black'));
    expect(toSet(pseudoLegalDestinations(board, point(6, 4)))).toEqual(new Set(['5,4']));
  });
});
