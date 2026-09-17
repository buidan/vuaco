import { Server as SocketIoServer, Socket } from 'socket.io';

import { AuthTokenPayload, verifyAuthToken } from '../auth/jwt';
import { RoomManager, RoomNotFoundError, RoomStateSnapshot } from '../rooms/roomManager';
import { BoardPoint } from '../xiangqi/boardPoint';

export interface ClientToServerEvents {
  'room:join': (payload: { roomId: string }, ack?: (res: AckResult) => void) => void;
  'move:make': (payload: { roomId: string; from: BoardPoint; to: BoardPoint }, ack?: (res: AckResult) => void) => void;
}

export interface ServerToClientEvents {
  'room:state': (state: RoomStateSnapshot) => void;
}

export interface SocketData {
  user: AuthTokenPayload;
}

type AckResult = { ok: true; state?: RoomStateSnapshot } | { ok: false; error: string; message?: string };

/**
 * Real-time half of Phase 4 multiplayer: authenticates the socket with the
 * same JWT the REST API uses, joins a socket.io room per game room (so
 * `io.to(roomId).emit(...)` reaches exactly its two players), and wires
 * `move:make` to `RoomManager.makeMove` - the server-authoritative move
 * validator (see docs/ARCHITECTURE.md section 2). `room:state` is a single
 * broadcast channel: every join/move/clock-expiry re-sends the full
 * snapshot rather than a delta, driven by `RoomManager`'s `'roomUpdated'`
 * event (see that file for why).
 */
export function attachRoomsGateway(
  io: SocketIoServer<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>,
  roomManager: RoomManager,
): void {
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) {
      next(new Error('unauthorized'));
      return;
    }
    try {
      socket.data.user = verifyAuthToken(token);
      next();
    } catch {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket: Socket<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>) => {
    socket.on('room:join', (payload, ack) => {
      try {
        const side = roomManager.attachSocket(payload.roomId, socket.data.user.sub, socket.id);
        if (side === null) {
          ack?.({ ok: false, error: 'not_a_participant' });
          return;
        }
        socket.join(payload.roomId);
        ack?.({ ok: true, state: roomManager.getSnapshot(payload.roomId) });
      } catch (err) {
        ack?.({ ok: false, error: err instanceof RoomNotFoundError ? 'room_not_found' : 'internal_error' });
      }
    });

    socket.on('move:make', async (payload, ack) => {
      try {
        const outcome = await roomManager.makeMove(payload.roomId, socket.data.user.sub, payload.from, payload.to);
        if (outcome.kind === 'rejected') {
          ack?.({ ok: false, error: outcome.reason, message: outcome.message });
        } else {
          ack?.({ ok: true, state: outcome.state });
        }
      } catch (err) {
        ack?.({
          ok: false,
          error: err instanceof RoomNotFoundError ? 'room_not_found' : 'internal_error',
        });
      }
    });

    socket.on('disconnect', () => {
      roomManager.detachSocket(socket.id);
    });
  });

  roomManager.on('roomUpdated', (roomId: string) => {
    try {
      io.to(roomId).emit('room:state', roomManager.getSnapshot(roomId));
    } catch {
      // Room no longer tracked (shouldn't happen in practice) - nothing to broadcast.
    }
  });
}
