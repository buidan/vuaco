import { Server as HttpServer } from 'node:http';
import { Server as SocketIoServer } from 'socket.io';

import { RoomManager } from '../rooms/roomManager';
import { attachRoomsGateway, ClientToServerEvents, ServerToClientEvents, SocketData } from './roomsGateway';

/**
 * Real-time transport for Phase 4 multiplayer. `attachRoomsGateway` (in
 * `roomsGateway.ts`) owns the actual event handlers - this function is
 * just the socket.io server setup (CORS, JWT auth on handshake happens
 * inside the gateway).
 */
export function attachSocketServer(
  httpServer: HttpServer,
  corsOrigin: string,
  roomManager: RoomManager,
): SocketIoServer<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData> {
  const io = new SocketIoServer<ClientToServerEvents, ServerToClientEvents, Record<string, never>, SocketData>(
    httpServer,
    { cors: { origin: corsOrigin } },
  );

  attachRoomsGateway(io, roomManager);

  return io;
}
