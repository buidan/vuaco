import { createServer } from 'node:http';
import { AddressInfo } from 'node:net';
import { io as ioClient, Socket as ClientSocket } from 'socket.io-client';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { signAuthToken } from '../../src/auth/jwt';
import { UNTIMED } from '../../src/rooms/clock';
import { RoomManager } from '../../src/rooms/roomManager';
import { attachSocketServer } from '../../src/websocket/socket';

const HOST = { id: 'host-1', username: 'Alice' };
const GUEST = { id: 'guest-1', username: 'Bob' };

function fakeDb() {
  let roomN = 0;
  return {
    query: async (sql: string) => {
      if (sql.includes('INSERT INTO rooms')) return { rows: [{ id: `room-${++roomN}` }] };
      if (sql.includes('INSERT INTO matches')) return { rows: [{ id: 'match-1' }] };
      return { rows: [] };
    },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any;
}

describe('roomsGateway (real sockets)', () => {
  let httpServer: ReturnType<typeof createServer>;
  let roomManager: RoomManager;
  let baseUrl: string;
  let clients: ClientSocket[] = [];

  beforeEach(async () => {
    roomManager = new RoomManager(fakeDb(), 1000);
    httpServer = createServer();
    attachSocketServer(httpServer, '*', roomManager);
    await new Promise<void>((resolve) => httpServer.listen(0, resolve));
    const { port } = httpServer.address() as AddressInfo;
    baseUrl = `http://localhost:${port}`;
  });

  afterEach(async () => {
    roomManager.stopClockLoop();
    for (const c of clients) c.disconnect();
    clients = [];
    await new Promise<void>((resolve) => httpServer.close(() => resolve()));
  });

  function connect(userId: string, username: string): ClientSocket {
    const token = signAuthToken({ sub: userId, username });
    const socket = ioClient(baseUrl, { auth: { token }, transports: ['websocket'], forceNew: true });
    clients.push(socket);
    return socket;
  }

  function waitFor<T>(socket: ClientSocket, event: string): Promise<T> {
    return new Promise((resolve) => socket.once(event, resolve));
  }

  it('rejects a connection with no auth token', async () => {
    const socket = ioClient(baseUrl, { transports: ['websocket'], forceNew: true });
    clients.push(socket);
    const err = await waitFor<Error>(socket, 'connect_error');
    expect(err.message).toBe('unauthorized');
  });

  it('joins a room and syncs a move to both players in real time', async () => {
    const created = await roomManager.createRoom(HOST, UNTIMED);
    await roomManager.joinRoom(created.pin, GUEST);

    const hostSocket = connect(HOST.id, HOST.username);
    const guestSocket = connect(GUEST.id, GUEST.username);

    await new Promise<void>((resolve) => hostSocket.on('connect', () => resolve()));
    await new Promise<void>((resolve) => guestSocket.on('connect', () => resolve()));

    const hostJoinAck = await new Promise<{ ok: boolean }>((resolve) =>
      hostSocket.emit('room:join', { roomId: created.roomId }, resolve),
    );
    expect(hostJoinAck.ok).toBe(true);

    const guestJoinAck = await new Promise<{ ok: boolean }>((resolve) =>
      guestSocket.emit('room:join', { roomId: created.roomId }, resolve),
    );
    expect(guestJoinAck.ok).toBe(true);

    const guestSeesMove = waitFor<{ sideToMove: string; history: unknown[] }>(guestSocket, 'room:state');

    const moveAck = await new Promise<{ ok: boolean }>((resolve) =>
      hostSocket.emit(
        'move:make',
        { roomId: created.roomId, from: { row: 3, col: 4 }, to: { row: 4, col: 4 } },
        resolve,
      ),
    );
    expect(moveAck.ok).toBe(true);

    const broadcastState = await guestSeesMove;
    expect(broadcastState.sideToMove).toBe('black');
    expect(broadcastState.history).toHaveLength(1);
  });

  it('rejects move:make from a socket that is not a room participant', async () => {
    const created = await roomManager.createRoom(HOST, UNTIMED);
    await roomManager.joinRoom(created.pin, GUEST);

    const strangerSocket = connect('stranger', 'Eve');
    await new Promise<void>((resolve) => strangerSocket.on('connect', () => resolve()));

    const joinAck = await new Promise<{ ok: boolean; error?: string }>((resolve) =>
      strangerSocket.emit('room:join', { roomId: created.roomId }, resolve),
    );
    expect(joinAck).toEqual({ ok: false, error: 'not_a_participant' });
  });
});
