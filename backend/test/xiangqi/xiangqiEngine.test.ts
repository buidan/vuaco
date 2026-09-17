import { describe, expect, it } from 'vitest';

import { Board } from '../../src/xiangqi/board';
import { point } from '../../src/xiangqi/boardPoint';
import { piece } from '../../src/xiangqi/piece';
import { XiangqiEngine } from '../../src/xiangqi/xiangqiEngine';

describe('XiangqiEngine', () => {
  it('starts with Red to move on the standard position', () => {
    const engine = new XiangqiEngine();
    expect(engine.sideToMove).toBe('red');
    expect(engine.result.outcome).toBe('ongoing');
  });

  it('executes a legal move and flips the turn', () => {
    const engine = new XiangqiEngine();
    const result = engine.tryMove(point(3, 4), point(4, 4));
    expect(result.kind).toBe('legal');
    expect(engine.sideToMove).toBe('black');
    expect(engine.history).toHaveLength(1);
  });

  it('rejects moving out of turn', () => {
    const engine = new XiangqiEngine();
    const result = engine.tryMove(point(6, 4), point(5, 4));
    expect(result).toMatchObject({ kind: 'illegal', reason: 'notYourTurn' });
  });

  it('rejects a geometrically illegal move', () => {
    const engine = new XiangqiEngine();
    const result = engine.tryMove(point(0, 0), point(1, 1));
    expect(result).toMatchObject({ kind: 'illegal', reason: 'illegalPieceMovement' });
  });

  it('detects checkmate: two chariots cover both of the general\'s escape squares', () => {
    let board = Board.empty();
    board = board.withPieceAt(point(0, 3), piece('general', 'red'));
    board = board.withPieceAt(point(9, 3), piece('chariot', 'black'));
    board = board.withPieceAt(point(9, 4), piece('chariot', 'black'));
    const engine = new XiangqiEngine(board, 'red');
    expect(engine.isInCheck('red')).toBe(true);
    expect(engine.result).toEqual({ outcome: 'blackWins', reason: 'checkmate' });
  });

  it('a player with no legal moves loses even when not currently in check', () => {
    let board = Board.empty();
    board = board.withPieceAt(point(1, 4), piece('general', 'red'));
    board = board.withPieceAt(point(0, 0), piece('chariot', 'black'));
    board = board.withPieceAt(point(2, 8), piece('chariot', 'black'));
    board = board.withPieceAt(point(8, 3), piece('chariot', 'black'));
    board = board.withPieceAt(point(8, 5), piece('chariot', 'black'));
    const engine = new XiangqiEngine(board, 'red');
    expect(engine.isInCheck('red')).toBe(false);
    expect(engine.result).toEqual({ outcome: 'blackWins', reason: 'noLegalMoves' });
  });

  it('no moves are accepted once the game has ended', () => {
    const engine = XiangqiEngine.fromFen('3rr4/9/9/9/9/9/9/9/9/3K5 w - - 0 1');
    expect(engine.result.outcome).not.toBe('ongoing');
    const result = engine.tryMove(point(0, 3), point(0, 4));
    expect(result).toMatchObject({ kind: 'illegal', reason: 'gameAlreadyOver' });
  });

  it('toFen round-trips the starting position', () => {
    const engine = new XiangqiEngine();
    const fen = engine.toFen();
    expect(fen).toBe('rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1');
    const restored = XiangqiEngine.fromFen(fen);
    expect(restored.toFen()).toBe(fen);
  });
});
