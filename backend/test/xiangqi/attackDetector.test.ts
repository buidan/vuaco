import { describe, expect, it } from 'vitest';

import { isFlyingGeneralFacing, isGeneralInCheck } from '../../src/xiangqi/attackDetector';
import { Board } from '../../src/xiangqi/board';
import { point } from '../../src/xiangqi/boardPoint';
import { piece } from '../../src/xiangqi/piece';
import { legalDestinationsFrom } from '../../src/xiangqi/legalMoveGenerator';

describe('Flying general rule', () => {
  it('detects an open, unobstructed column', () => {
    let board = Board.empty();
    board = board.withPieceAt(point(0, 4), piece('general', 'red'));
    board = board.withPieceAt(point(9, 4), piece('general', 'black'));
    expect(isFlyingGeneralFacing(board)).toBe(true);
  });

  it('is not triggered when a piece blocks the column', () => {
    let board = Board.empty();
    board = board.withPieceAt(point(0, 4), piece('general', 'red'));
    board = board.withPieceAt(point(9, 4), piece('general', 'black'));
    board = board.withPieceAt(point(5, 4), piece('soldier', 'red'));
    expect(isFlyingGeneralFacing(board)).toBe(false);
  });

  it('scenario: moving a screening piece away to expose facing generals is illegal', () => {
    let board = Board.empty();
    board = board.withPieceAt(point(0, 4), piece('general', 'red'));
    board = board.withPieceAt(point(9, 4), piece('general', 'black'));
    board = board.withPieceAt(point(5, 4), piece('chariot', 'red'));
    const moves = legalDestinationsFrom(board, point(5, 4), 'red');
    expect(moves.some((m) => m.row === 5 && m.col === 0)).toBe(false); // would open the column
    expect(moves.some((m) => m.row === 3 && m.col === 4)).toBe(true); // still screening
  });
});

describe('Check detection per piece type', () => {
  it('chariot delivers check along an open file', () => {
    let board = Board.empty();
    board = board.withPieceAt(point(0, 4), piece('general', 'red'));
    board = board.withPieceAt(point(5, 4), piece('chariot', 'black'));
    expect(isGeneralInCheck(board, 'red')).toBe(true);
  });

  it('cannon delivers check only with exactly one screen', () => {
    let board = Board.empty();
    board = board.withPieceAt(point(0, 4), piece('general', 'red'));
    board = board.withPieceAt(point(5, 4), piece('cannon', 'black'));
    expect(isGeneralInCheck(board, 'red')).toBe(false);
    board = board.withPieceAt(point(2, 4), piece('soldier', 'red'));
    expect(isGeneralInCheck(board, 'red')).toBe(true);
  });

  it('horse delivers check respecting leg-blocking', () => {
    let board = Board.empty();
    board = board.withPieceAt(point(2, 4), piece('general', 'red'));
    board = board.withPieceAt(point(0, 3), piece('horse', 'black'));
    expect(isGeneralInCheck(board, 'red')).toBe(true);
    board = board.withPieceAt(point(1, 3), piece('soldier', 'red'));
    expect(isGeneralInCheck(board, 'red')).toBe(false);
  });

  it('advisor/elephant can never deliver check - confined to their own side', () => {
    let board = Board.empty();
    board = board.withPieceAt(point(2, 4), piece('general', 'red'));
    board = board.withPieceAt(point(1, 3), piece('advisor', 'black'));
    board = board.withPieceAt(point(4, 6), piece('elephant', 'black'));
    expect(isGeneralInCheck(board, 'red')).toBe(false);
  });
});
