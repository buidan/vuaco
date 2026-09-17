import { isGeneralInCheck } from './attackDetector';
import { Board } from './board';
import { BoardPoint } from './boardPoint';
import { decodeFen, encodeFen } from './fenCodec';
import { GameResult, isOngoing, ONGOING, resultForNoMoves, winResult } from './gameResult';
import { allLegalMoves as computeAllLegalMoves, hasAnyLegalMove, legalDestinationsFrom } from './legalMoveGenerator';
import { forMove } from './moveNotation';
import { Move } from './move';
import { opponent, Side } from './side';
import { MoveValidationResult } from './moveValidationResult';
import { pseudoLegalDestinations } from './pieceMoves';

export interface MoveHistoryEntry {
  readonly move: Move;
  readonly notation: string;
  readonly isCheck: boolean;
  readonly resultAfter: GameResult;
}

/**
 * Server-authoritative counterpart of the client's
 * `lib/domain/engine/xiangqi_engine.dart`. This is what
 * `backend/src/rooms/roomManager.ts` uses to validate every multiplayer
 * move - the client's own Dart engine is UX-only for Pass & Play and
 * legal-destination highlighting, never trusted for a live match's result
 * (see docs/ARCHITECTURE.md section 2 and backend/README.md).
 *
 * No undo/redo here (unlike the Dart engine) - a live match has no use for
 * it, and "takebacks" aren't a feature this phase implements.
 */
export class XiangqiEngine {
  private _board: Board;
  private _sideToMove: Side;
  private _result: GameResult;
  private readonly _history: MoveHistoryEntry[] = [];

  constructor(board?: Board, sideToMove: Side = 'red') {
    this._board = board ?? Board.initial();
    this._sideToMove = sideToMove;
    this._result = XiangqiEngine.computeResult(this._board, this._sideToMove);
  }

  static fromFen(fen: string): XiangqiEngine {
    const decoded = decodeFen(fen);
    return new XiangqiEngine(decoded.board, decoded.sideToMove);
  }

  get board(): Board {
    return this._board;
  }

  get sideToMove(): Side {
    return this._sideToMove;
  }

  get result(): GameResult {
    return this._result;
  }

  get history(): ReadonlyArray<MoveHistoryEntry> {
    return this._history;
  }

  isInCheck(side: Side): boolean {
    return isGeneralInCheck(this._board, side);
  }

  get allLegalMoves(): Move[] {
    return isOngoing(this._result) ? computeAllLegalMoves(this._board, this._sideToMove) : [];
  }

  legalDestinationsFrom(from: BoardPoint): BoardPoint[] {
    if (!isOngoing(this._result)) return [];
    return legalDestinationsFrom(this._board, from, this._sideToMove);
  }

  toFen(): string {
    return encodeFen(this._board, this._sideToMove, 0, Math.floor(this._history.length / 2) + 1);
  }

  tryMove(from: BoardPoint, to: BoardPoint): MoveValidationResult {
    if (!isOngoing(this._result)) {
      return { kind: 'illegal', reason: 'gameAlreadyOver', message: 'The game has already ended.' };
    }

    const pc = this._board.pieceAt(from);
    if (pc === null) {
      return { kind: 'illegal', reason: 'noPieceAtSource', message: 'There is no piece on the selected point.' };
    }
    if (pc.side !== this._sideToMove) {
      return { kind: 'illegal', reason: 'notYourTurn', message: "It is not this piece's turn to move." };
    }

    const legal = legalDestinationsFrom(this._board, from, this._sideToMove);
    if (!legal.some((d) => d.row === to.row && d.col === to.col)) {
      const pseudoLegal = pseudoLegalDestinations(this._board, from).some((d) => d.row === to.row && d.col === to.col);
      if (pseudoLegal) {
        return {
          kind: 'illegal',
          reason: 'leavesGeneralInCheck',
          message: 'That move would leave your general in check (or violates the flying-general rule).',
        };
      }
      return { kind: 'illegal', reason: 'illegalPieceMovement', message: 'That piece cannot move there.' };
    }

    const move: Move = { from, to, movedPiece: pc, capturedPiece: this._board.pieceAt(to) };
    const sideBefore = this._sideToMove;

    const nextBoard = this._board.applyMove(from, to);
    const nextSide = opponent(this._sideToMove);
    const opponentInCheck = isGeneralInCheck(nextBoard, nextSide);
    const opponentHasMoves = hasAnyLegalMove(nextBoard, nextSide);
    const isCheckmate = opponentInCheck && !opponentHasMoves;
    const noLegalMoves = !opponentInCheck && !opponentHasMoves;

    const resultAfter = isCheckmate
      ? winResult(sideBefore, 'checkmate')
      : noLegalMoves
        ? winResult(sideBefore, 'noLegalMoves')
        : ONGOING;

    const notation = forMove(move, { isCheck: opponentInCheck, isCheckmate });

    this._history.push({ move, notation, isCheck: opponentInCheck, resultAfter });
    this._board = nextBoard;
    this._sideToMove = nextSide;
    this._result = resultAfter;

    return { kind: 'legal', move, leavesOpponentInCheck: opponentInCheck, endsGame: !isOngoing(resultAfter) };
  }

  /** Ends the game immediately (e.g. clock expiry, resignation) without a move. */
  endGame(winner: Side, reason: 'timeout' | 'resignation'): void {
    this._result = winResult(winner, reason);
  }

  private static computeResult(board: Board, sideToMove: Side): GameResult {
    const inCheck = isGeneralInCheck(board, sideToMove);
    const hasMoves = hasAnyLegalMove(board, sideToMove);
    if (hasMoves) return ONGOING;
    return resultForNoMoves(sideToMove, inCheck);
  }
}
