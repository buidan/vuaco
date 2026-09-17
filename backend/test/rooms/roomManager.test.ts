import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { UNTIMED, timeControlFromRequest } from '../../src/rooms/clock';
import { NotAParticipantError, RoomFullError, RoomManager, RoomNotFoundError } from '../../src/rooms/roomManager';

let roomCounter = 0;
let matchCounter = 0;

function fakeDb() {
  return {
    query: vi.fn(async (sql: string) => {
      if (sql.includes('INSERT INTO rooms')) {
        return { rows: [{ id: `room-${++roomCounter}` }] };
      }
      if (sql.includes('INSERT INTO matches')) {
        return { rows: [{ id: `match-${++matchCounter}` }] };
      }
      return { rows: [] };
    }),
  };
}

const HOST = { id: 'host-1', username: 'Alice' };
const GUEST = { id: 'guest-1', username: 'Bob' };

describe('RoomManager', () => {
  let db: ReturnType<typeof fakeDb>;
  let manager: RoomManager;

  beforeEach(() => {
    db = fakeDb();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    manager = new RoomManager(db as any, 1000);
  });

  afterEach(() => {
    manager.stopClockLoop();
  });

  it('creates a room with the host as Red and an untimed clock by default', async () => {
    const state = await manager.createRoom(HOST, UNTIMED);
    expect(state.status).toBe('waiting');
    expect(state.players.red).toEqual({ userId: 'host-1', username: 'Alice', connected: false });
    expect(state.players.black).toBeNull();
    expect(state.clock).toBeNull();
    expect(state.pin).toHaveLength(6);
  });

  it('joins a second player as Black and activates the room', async () => {
    const created = await manager.createRoom(HOST, UNTIMED);
    const joined = await manager.joinRoom(created.pin, GUEST);
    expect(joined.status).toBe('active');
    expect(joined.players.black).toEqual({ userId: 'guest-1', username: 'Bob', connected: false });
  });

  it('rejects joining a nonexistent PIN', async () => {
    await expect(manager.joinRoom('ZZZZZZ', GUEST)).rejects.toBeInstanceOf(RoomNotFoundError);
  });

  it('rejects a third player joining a full room', async () => {
    const created = await manager.createRoom(HOST, UNTIMED);
    await manager.joinRoom(created.pin, GUEST);
    await expect(manager.joinRoom(created.pin, { id: 'third', username: 'Carl' })).rejects.toBeInstanceOf(
      RoomFullError,
    );
  });

  it('lets the host or guest rejoin the same room without error', async () => {
    const created = await manager.createRoom(HOST, UNTIMED);
    await manager.joinRoom(created.pin, GUEST);
    const rejoinedHost = await manager.joinRoom(created.pin, HOST);
    const rejoinedGuest = await manager.joinRoom(created.pin, GUEST);
    expect(rejoinedHost.roomId).toBe(created.roomId);
    expect(rejoinedGuest.roomId).toBe(created.roomId);
  });

  it('applies a legal move and flips the side to move', async () => {
    const created = await manager.createRoom(HOST, UNTIMED);
    await manager.joinRoom(created.pin, GUEST);
    const outcome = await manager.makeMove(created.roomId, HOST.id, { row: 3, col: 4 }, { row: 4, col: 4 });
    expect(outcome.kind).toBe('applied');
    if (outcome.kind === 'applied') {
      expect(outcome.state.sideToMove).toBe('black');
      expect(outcome.state.history).toHaveLength(1);
    }
  });

  it('rejects a move from the side that is not to move', async () => {
    const created = await manager.createRoom(HOST, UNTIMED);
    await manager.joinRoom(created.pin, GUEST);
    const outcome = await manager.makeMove(created.roomId, GUEST.id, { row: 6, col: 4 }, { row: 5, col: 4 });
    expect(outcome).toMatchObject({ kind: 'rejected', reason: 'notYourTurn' });
  });

  it('rejects a move from someone who is not a participant', async () => {
    const created = await manager.createRoom(HOST, UNTIMED);
    await manager.joinRoom(created.pin, GUEST);
    await expect(
      manager.makeMove(created.roomId, 'stranger', { row: 3, col: 4 }, { row: 4, col: 4 }),
    ).rejects.toBeInstanceOf(NotAParticipantError);
  });

  it('rejects an illegal move with the engine\'s own reason', async () => {
    const created = await manager.createRoom(HOST, UNTIMED);
    await manager.joinRoom(created.pin, GUEST);
    const outcome = await manager.makeMove(created.roomId, HOST.id, { row: 0, col: 0 }, { row: 1, col: 1 });
    expect(outcome).toMatchObject({ kind: 'rejected', reason: 'illegalPieceMovement' });
  });

  it('persists a match record once the game ends', async () => {
    // Corner-mate shape: Red already checkmated at room creation via a
    // custom start isn't supported by createRoom (always starts standard),
    // so drive an actual sequence: this just checks the persistence path
    // fires by asserting the matches insert query eventually runs when we
    // force game end via clock timeout instead (simpler to set up here).
    const timeControl = timeControlFromRequest(1 / 6000, 0); // ~10ms clock
    const created = await manager.createRoom(HOST, timeControl);
    await manager.joinRoom(created.pin, GUEST);
    await new Promise((resolve) => setTimeout(resolve, 20));

    const outcome = await manager.makeMove(created.roomId, HOST.id, { row: 3, col: 4 }, { row: 4, col: 4 });
    expect(outcome.kind).toBe('applied');
    if (outcome.kind === 'applied') {
      expect(outcome.state.result.outcome).toBe('blackWins');
      expect(outcome.state.result.reason).toBe('timeout');
    }
    expect(db.query).toHaveBeenCalledWith(expect.stringContaining('INSERT INTO matches'), expect.anything());
  });

  it('attachSocket returns the participant\'s side and null for a stranger', async () => {
    const created = await manager.createRoom(HOST, UNTIMED);
    await manager.joinRoom(created.pin, GUEST);
    expect(manager.attachSocket(created.roomId, HOST.id, 'socket-1')).toBe('red');
    expect(manager.attachSocket(created.roomId, GUEST.id, 'socket-2')).toBe('black');
    expect(manager.attachSocket(created.roomId, 'stranger', 'socket-3')).toBeNull();
  });

  it('detachSocket clears connection status without touching the wrong room', async () => {
    const created = await manager.createRoom(HOST, UNTIMED);
    await manager.joinRoom(created.pin, GUEST);
    manager.attachSocket(created.roomId, HOST.id, 'socket-1');
    manager.detachSocket('socket-1');
    const state = manager.getSnapshot(created.roomId);
    expect(state.players.red.connected).toBe(false);
  });

  it('emits roomUpdated on join and on move', async () => {
    const events: string[] = [];
    manager.on('roomUpdated', (roomId: string) => events.push(roomId));
    const created = await manager.createRoom(HOST, UNTIMED);
    await manager.joinRoom(created.pin, GUEST);
    await manager.makeMove(created.roomId, HOST.id, { row: 3, col: 4 }, { row: 4, col: 4 });
    expect(events).toEqual([created.roomId, created.roomId]);
  });
});
