import { Server as HttpServer } from 'node:http';
import { Server as SocketIoServer } from 'socket.io';

/**
 * Socket.io is initialized in Phase 2 purely as infrastructure - no
 * namespaces or events are defined yet. Real-time match sync, room
 * presence, and clock events are Phase 4 (see docs/ARCHITECTURE.md
 * sections 4 and 5, which say to document namespace/event names here once
 * that phase starts). Logging connections now is enough to prove the
 * transport works end-to-end.
 */
export function attachSocketServer(httpServer: HttpServer, corsOrigin: string): SocketIoServer {
  const io = new SocketIoServer(httpServer, {
    cors: { origin: corsOrigin },
  });

  io.on('connection', (socket) => {
    socket.emit('server:hello', { message: 'connected - no events defined until Phase 4' });
  });

  return io;
}
