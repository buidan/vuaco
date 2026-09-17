import { EventEmitter } from 'node:events';
import { Pool } from 'pg';

import { BoardPoint } from '../xiangqi/boardPoint';
import { isOngoing } from '../xiangqi/gameResult';
import type { GameResult } from '../xiangqi/gameResult';
import { opponent, Side } from '../xiangqi/side';
import { XiangqiEngine } from '../xiangqi/xiangqiEngine';
import { RoomClock, TimeControl } from './clock';
import { generatePin } from './pin';

export class RoomNotFoundError extends Error {}
export class RoomFullError extends Error {}
export class NotAParticipantError extends Error {}

interface RoomUser {
  userId: string;
  username: string;
  socketId: string | null;
}

interface RoomRuntime {
  id: string;
  pin: string;
  status: 'waiting' | 'active' | 'finished';
  engine: XiangqiEngine;
  clock: RoomClock | null;
  players: { red: RoomUser; black: RoomUser | null };
  matchPersisted: boolean;
}

export interface RoomPlayerInfo {
  userId: string;
  username: string;
  connected: boolean;
}

export interface RoomStateSnapshot {
  roomId: string;
  pin: string;
  status: RoomRuntime['status'];
  fen: string;
  sideToMove: Side;
  result: GameResult;
  players: { red: RoomPlayerInfo; black: RoomPlayerInfo | null };
  clock: { enabled: boolean; redRemainingMs: number; blackRemainingMs: number } | null;
  history: Array<{ notation: string; isCheck: boolean }>;
}

export type MoveOutcome =
  | { kind: 'applied'; state: RoomStateSnapshot }
  | { kind: 'rejected'; reason: string; message: string };

const POSTGRES_UNIQUE_VIOLATION = '23505';

/**
 * Owns every live room's authoritative game state - this is the
 * server-authoritative half of docs/ARCHITECTURE.md section 2 ("client
 * validation is for UX responsiveness only; never trust the client for
 * match results"). Single-process, in-memory (see backend/README.md for
 * what that means for horizontal scaling); Postgres only stores durable
 * room/match metadata, not live board state.
 *
 * Emits `'roomUpdated'` (roomId: string) after every state change - the
 * websocket gateway is the only listener, and re-broadcasts a fresh
 * snapshot to that room's sockets. Deliberately one broad event rather
 * than several narrow ones: a Xiangqi position is small, and a single
 * "here's the full state now" message is much harder to get subtly wrong
 * than reconstructing state from a stream of deltas.
 */
export class RoomManager extends EventEmitter {
  private readonly rooms = new Map<string, RoomRuntime>();
  private readonly roomIdByPin = new Map<string, string>();
  private clockLoop: NodeJS.Timeout | null = null;

  constructor(
    private readonly db: Pool,
    private readonly clockTickIntervalMs: number,
  ) {
    super();
  }

  startClockLoop(): void {
    if (this.clockLoop) return;
    this.clockLoop = setInterval(() => this.checkAllClocksForExpiry(), this.clockTickIntervalMs);
    this.clockLoop.unref?.();
  }

  stopClockLoop(): void {
    if (this.clockLoop) clearInterval(this.clockLoop);
    this.clockLoop = null;
  }

  async createRoom(host: { id: string; username: string }, timeControl: TimeControl): Promise<RoomStateSnapshot> {
    for (let attempt = 0; attempt < 5; attempt++) {
      const pin = generatePin();
      try {
        const result = await this.db.query<{ id: string }>(
          `INSERT INTO rooms (pin, host_id, status, timer_settings) VALUES ($1, $2, 'waiting', $3)
           RETURNING id`,
          [pin, host.id, JSON.stringify(timeControl)],
        );
        const roomId = result.rows[0]!.id;
        const runtime: RoomRuntime = {
          id: roomId,
          pin,
          status: 'waiting',
          engine: new XiangqiEngine(),
          clock: timeControl.enabled ? new RoomClock(timeControl) : null,
          players: { red: { userId: host.id, username: host.username, socketId: null }, black: null },
          matchPersisted: false,
        };
        this.rooms.set(roomId, runtime);
        this.roomIdByPin.set(pin, roomId);
        return this.snapshot(runtime);
      } catch (err) {
        const code = (err as { code?: string }).code;
        if (code === POSTGRES_UNIQUE_VIOLATION && attempt < 4) continue;
        throw err;
      }
    }
    throw new Error('Could not allocate a unique room PIN after several attempts');
  }

  async joinRoom(pin: string, guest: { id: string; username: string }): Promise<RoomStateSnapshot> {
    const roomId = this.roomIdByPin.get(pin.toUpperCase());
    const runtime = roomId ? this.rooms.get(roomId) : undefined;
    if (!runtime) throw new RoomNotFoundError(`No room with PIN "${pin}"`);

    if (runtime.players.red.userId === guest.id) return this.snapshot(runtime); // host reconnecting
    if (runtime.players.black?.userId === guest.id) return this.snapshot(runtime); // guest reconnecting

    if (runtime.players.black !== null) {
      throw new RoomFullError('This room already has two players');
    }

    runtime.players.black = { userId: guest.id, username: guest.username, socketId: null };
    runtime.status = 'active';
    await this.db.query(`UPDATE rooms SET guest_id = $1, status = 'active' WHERE id = $2`, [guest.id, runtime.id]);

    this.emit('roomUpdated', runtime.id);
    return this.snapshot(runtime);
  }

  getSnapshot(roomId: string): RoomStateSnapshot {
    return this.snapshot(this.requireRoom(roomId));
  }

  /** Associates a live socket with whichever side `userId` plays in this
   * room. Returns that side, or null if `userId` isn't a participant
   * (e.g. a spectator link, not supported yet). */
  attachSocket(roomId: string, userId: string, socketId: string): Side | null {
    const runtime = this.requireRoom(roomId);
    const side = this.sideOf(runtime, userId);
    if (side === null) return null;
    if (side === 'red') runtime.players.red.socketId = socketId;
    else runtime.players.black!.socketId = socketId;
    this.emit('roomUpdated', roomId);
    return side;
  }

  /** Clears whichever player slot `socketId` belongs to, across every
   * room - called on socket disconnect. */
  detachSocket(socketId: string): void {
    for (const runtime of this.rooms.values()) {
      let changed = false;
      if (runtime.players.red.socketId === socketId) {
        runtime.players.red.socketId = null;
        changed = true;
      }
      if (runtime.players.black?.socketId === socketId) {
        runtime.players.black.socketId = null;
        changed = true;
      }
      if (changed) this.emit('roomUpdated', runtime.id);
    }
  }

  async makeMove(roomId: string, userId: string, from: BoardPoint, to: BoardPoint): Promise<MoveOutcome> {
    const runtime = this.requireRoom(roomId);
    const side = this.sideOf(runtime, userId);
    if (side === null) {
      throw new NotAParticipantError('This user is not a participant in this room');
    }

    if (!isOngoing(runtime.engine.result)) {
      return { kind: 'rejected', reason: 'gameAlreadyOver', message: 'The game has already ended.' };
    }

    if (runtime.clock) {
      runtime.clock.consumeElapsed(side);
      if (runtime.clock.isExpired(side)) {
        runtime.engine.endGame(opponent(side), 'timeout');
        await this.persistMatchIfEnded(runtime);
        this.emit('roomUpdated', roomId);
        return { kind: 'applied', state: this.snapshot(runtime) };
      }
    }

    if (side !== runtime.engine.sideToMove) {
      return { kind: 'rejected', reason: 'notYourTurn', message: "It is not this player's turn to move." };
    }

    const result = runtime.engine.tryMove(from, to);
    if (result.kind === 'illegal') {
      return { kind: 'rejected', reason: result.reason, message: result.message };
    }

    runtime.clock?.applyIncrementAndSwitch(side);
    await this.persistMatchIfEnded(runtime);
    this.emit('roomUpdated', roomId);
    return { kind: 'applied', state: this.snapshot(runtime) };
  }

  private async checkAllClocksForExpiry(): Promise<void> {
    for (const runtime of this.rooms.values()) {
      if (!runtime.clock || !isOngoing(runtime.engine.result)) continue;
      const side = runtime.engine.sideToMove;
      runtime.clock.consumeElapsed(side);
      if (runtime.clock.isExpired(side)) {
        runtime.engine.endGame(opponent(side), 'timeout');
        await this.persistMatchIfEnded(runtime);
        this.emit('roomUpdated', runtime.id);
      }
    }
  }

  private async persistMatchIfEnded(runtime: RoomRuntime): Promise<void> {
    if (runtime.matchPersisted || isOngoing(runtime.engine.result)) return;
    runtime.matchPersisted = true;
    runtime.status = 'finished';

    const moveHistory = runtime.engine.history.map((entry) => entry.notation);
    const result = await this.db.query<{ id: string }>(
      `INSERT INTO matches (player_red_id, player_black_id, result, move_history) VALUES ($1, $2, $3, $4)
       RETURNING id`,
      [
        runtime.players.red.userId,
        runtime.players.black?.userId ?? null,
        JSON.stringify(runtime.engine.result),
        JSON.stringify(moveHistory),
      ],
    );
    await this.db.query(`UPDATE rooms SET status = 'finished', match_id = $1 WHERE id = $2`, [
      result.rows[0]!.id,
      runtime.id,
    ]);
  }

  private sideOf(runtime: RoomRuntime, userId: string): Side | null {
    if (runtime.players.red.userId === userId) return 'red';
    if (runtime.players.black?.userId === userId) return 'black';
    return null;
  }

  private requireRoom(roomId: string): RoomRuntime {
    const runtime = this.rooms.get(roomId);
    if (!runtime) throw new RoomNotFoundError(`No room with id "${roomId}"`);
    return runtime;
  }

  private snapshot(runtime: RoomRuntime): RoomStateSnapshot {
    const toPlayerInfo = (user: RoomUser | null): RoomPlayerInfo | null =>
      user ? { userId: user.userId, username: user.username, connected: user.socketId !== null } : null;

    return {
      roomId: runtime.id,
      pin: runtime.pin,
      status: runtime.status,
      fen: runtime.engine.toFen(),
      sideToMove: runtime.engine.sideToMove,
      result: runtime.engine.result,
      players: {
        red: toPlayerInfo(runtime.players.red)!,
        black: toPlayerInfo(runtime.players.black),
      },
      clock: runtime.clock
        ? { enabled: true, redRemainingMs: runtime.clock.redRemainingMs, blackRemainingMs: runtime.clock.blackRemainingMs }
        : null,
      history: runtime.engine.history.map((entry) => ({ notation: entry.notation, isCheck: entry.isCheck })),
    };
  }
}
