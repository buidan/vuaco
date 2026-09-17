# Vuaco Backend (Phases 2 & 4)

REST + WebSocket API per [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md):
an isolated Pikafish (Xiangqi engine) wrapper for the Engine Coach (Phase 2),
and guest auth + server-authoritative online multiplayer rooms (Phase 4).
This is the only part of the system that ever talks to Pikafish, and the
only thing that ever validates a multiplayer move - the Flutter client only
ever calls this backend's own REST/WebSocket API.

## GPL isolation

Pikafish is GPL-3.0. The Docker image compiles it from its own unmodified
upstream source (`Dockerfile`'s `pikafish-build` stage, pinned to release tag
`Pikafish-2026-09-06`) and the resulting binary is invoked by
[`src/engine/pikafishProcess.ts`](src/engine/pikafishProcess.ts) as a
**separate OS process**, spoken to only over its stdin/stdout via the UCI
text protocol. Nothing here links against Pikafish's code, so this
TypeScript is not a derivative work under GPL. `Copying.txt` (Pikafish's
GPL-3.0 license text) is copied into the runtime image alongside the binary
for distribution compliance.

We build from source rather than downloading Pikafish's own prebuilt release
binary because that binary is linked against a newer glibc than Debian
bookworm ships (`GLIBC_2.38`) and fails to run in a bookworm-based runtime
image; compiling in a bookworm build stage links against the same glibc the
runtime stage has. `ARCH=x86-64-avx2` is a broadly-portable choice - see
`make help` inside the Pikafish source (`src/Makefile`) for the full list if
your deployment target can use something narrower or wider.

## Running locally

### Everything in Docker (closest to production)

```sh
docker compose up -d          # postgres (:5433), redis (:6380), api (:3000)
docker compose run --rm api node dist/db/migrate.js   # first time only
curl http://localhost:3000/api/v1/health
```

Ports are intentionally shifted from Postgres/Redis defaults (`5433`,
`6380`) so this doesn't collide with any other local Postgres/Redis you may
already have running on `5432`/`6379`.

### API on the host, infra in Docker (faster iteration)

```sh
docker compose up -d postgres redis
cp .env.example .env   # then edit PIKAFISH_BIN_PATH (see below)
npm install
npm run migrate
npm run dev
```

Running the API on the host still needs a local Pikafish binary, since
`PIKAFISH_BIN_PATH` in `.env.example` points at the Docker image's install
location (`/opt/pikafish/pikafish`), which doesn't exist on the host. Either:

- extract a [Pikafish release](https://github.com/official-pikafish/Pikafish/releases)
  for your platform (it ships a prebuilt binary + `pikafish.nnue` net in one
  archive) and point `PIKAFISH_BIN_PATH`/`PIKAFISH_CWD` at wherever you put
  them, or
- build it yourself per the "Compiling Pikafish" section of its README
  (`cd src && make -j profile-build`).

## Endpoints

- `GET /api/v1/health` - checks Postgres, Redis, and the Pikafish pool;
  `200` if all three are up, `503` (body `status: "degraded"`) otherwise.
- `POST /api/v1/engine/analyze` - body `{ fen: string, multiPv?: number,
  depth?: number }` (multiPv default 3, depth default from
  `PIKAFISH_DEFAULT_DEPTH`) -> `{ bestMove, ponder?, depthReached, lines: [{
  multiPv, depth, scoreType: "cp"|"mate", scoreValue, pvMoves }] }`, ranked
  best (`multiPv: 1`) first. `fen` must use the same convention as the
  client's `lib/domain/fen/fen_codec.dart` - see `src/utils/fen.ts`.
- `POST /api/v1/auth/guest` - body `{ username }` -> `{ token, user: { id,
  username, elo } }`. See "Auth" below.
- `POST /api/v1/rooms` (auth required) - body `{ timeControlMinutes?,
  incrementSeconds? }` -> `{ roomId, pin, shareLink, state }`.
- `POST /api/v1/rooms/join` (auth required, Redis-rate-limited) - body
  `{ pin }` -> `{ state }`.
- `GET /api/v1/rooms/:id` (auth required) -> `{ state }`.
- `POST /api/v1/vision/scan` - **stub only**, always responds `501
  not_implemented`. See the TODO comment in `src/routes/vision.routes.ts`
  for the planned Cloud Vision (photo -> FEN) integration once a provider
  and API key are chosen; Phase 5 shipped manual FEN paste and the board-
  correction UI instead (Flutter side).

See "Rooms & realtime multiplayer" below for the WebSocket half and what
`state` (`RoomStateSnapshot`) looks like.

## Auth

`POST /api/v1/auth/guest` is the only auth flow implemented - no password,
no refresh token. Every call creates a **brand-new** user row (see
`src/auth/userStore.ts`); it is not "log in as an existing username", since
there's nothing to prove ownership of one. This is deliberately minimal:
good enough to give multiplayer rooms a stable user identity without
building a full account system before it's needed. `src/auth/jwt.ts` signs
a long-lived (`JWT_EXPIRES_IN`, default 30d) token carrying `{ sub, username
}`; `src/auth/authMiddleware.ts`'s `requireAuth` verifies it for REST routes,
and `websocket/roomsGateway.ts` verifies the same token during the socket
handshake (`socket.handshake.auth.token`). **Set `JWT_SECRET` in any shared
or deployed environment** - the default in `config/index.ts` is an
insecure, obviously-named placeholder for solo local dev only.

## Rooms & realtime multiplayer

`src/rooms/roomManager.ts`'s `RoomManager` owns every live room's
authoritative game state in memory (one process, not sharded across
instances - see "Scaling" below) and is the only thing that ever validates
a multiplayer move, via its own TypeScript port of the client's rules
engine at `src/xiangqi/` (see "Xiangqi rules engine" below). Postgres only
stores durable metadata (`rooms`/`matches` tables) - `RoomManager` writes a
room row on create/join and a match row once a game ends.

Room codes are 6-character alphanumeric (`src/rooms/pin.ts`, excluding
visually ambiguous characters like `0`/`O`/`1`/`I`), created via REST and
then joined live over Socket.io:

1. `POST /rooms` (host) / `POST /rooms/join` (guest) - creates or joins the
   Postgres room row and the in-memory `RoomRuntime`.
2. Client connects a socket with the same JWT, then emits `room:join`
   `{ roomId }` (ack `{ ok, state? }`) to attach that connection to the
   room's Socket.io room (`io.to(roomId)`) - only the two participants can
   attach; everyone else gets `{ ok: false, error: 'not_a_participant' }`.
3. `move:make` `{ roomId, from: {row,col}, to: {row,col} }` (ack `{ ok,
   error?, message? }`) - validated by `RoomManager.makeMove` against the
   room's `XiangqiEngine`. Whether accepted or not, an ack goes only to the
   sender; on any accepted change (join, move, clock timeout),
   `RoomManager` emits `'roomUpdated'` and every socket in the room
   receives a fresh full `room:state` broadcast (`RoomStateSnapshot`) -
   deliberately whole-state, not deltas, since a Xiangqi position is small
   and this is much harder to get subtly wrong than delta reconstruction.

Clocks (`src/rooms/clock.ts`) are enforced server-side: `RoomManager`
deducts elapsed wall-clock time from the mover's clock on every move
attempt, and a single interval (`RoomManager.startClockLoop`, one timer for
all rooms, not one per room) periodically checks every timed room's
side-to-move for a flag-fall even if nobody moves.

**Scaling note**: because `RoomManager` state is in-process memory, running
more than one backend instance would split rooms across instances with no
way for a client connected to instance A to reach a room created on
instance B. Horizontally scaling this needs a shared store (Redis pub/sub
for cross-instance Socket.io broadcast at minimum, `@socket.io/redis-adapter`
is the standard fit) - out of scope for this pass.

## Xiangqi rules engine (server-authoritative)

`src/xiangqi/` is a TypeScript port of the client's entire
`lib/domain/{models,rules,fen,notation,engine}` - same files, same function
names, ported 1:1 on purpose so the two are easy to keep in sync. If you
change a rule (or fix a bug) in one, make the matching change in the other;
`test/xiangqi/*.test.ts` mirrors the Dart test suite's key cases (piece
movement edge cases, flying general, check/checkmate, FEN round-trip) so a
divergence should show up as a failing test on whichever side you forgot.
See `RULES_ENGINE.md` (client-side) for the domain layer's own
documentation - it applies here too, module-for-module.

## Data model / migrations

`migrations/*.sql` are applied in filename order by `npm run migrate`
(tracked in a `schema_migrations` table, no down-migrations). `0001_init.sql`
creates the `users`/`matches`/`rooms` skeleton from `docs/ARCHITECTURE.md`
section 6; `0002_rooms_multiplayer.sql` (Phase 4) adds `rooms.guest_id` and
`rooms.match_id`.

## Tests

```sh
npm test
```

`test/engine/pikafishProcess.test.ts` and the fixture at
`test/fixtures/fakeUciEngine.js` exercise the UCI protocol handling
(handshake, MultiPV parsing, the timeout -> `stop` -> recovery path) against
a tiny fake engine, not the real Pikafish binary, so the suite runs without
it. The real binary was exercised manually end-to-end during development
(spawned directly, then through the full `docker compose` stack) - see the
git history / PR description for that session rather than re-deriving it
here.

`test/rooms/roomManager.test.ts` exercises room create/join/move/clock-
timeout/match-persistence logic against a mocked Postgres pool.
`test/websocket/roomsGateway.test.ts` spins up a real `http.Server` +
Socket.io server and a real `socket.io-client`, so it's the one test that
actually exercises the JWT-handshake-auth and room-broadcast wiring
end-to-end rather than through mocks. The real backend (Docker stack) was
also driven manually with a real Flutter/Dart `socket_io_client` during
development - see `RULES_ENGINE.md`'s "Online Multiplayer" section for the
one gotcha that manual pass caught that no automated test here would have
(a client-side connection-caching issue, fixed with `enableForceNew()`).

Known: `npm audit` flags moderate/high advisories in `vitest`'s `vite`/
`esbuild` dev-server dependencies. These are dev-only tooling (never
shipped in the runtime image) and exploitable only via a locally-running
Vite dev server, which this project doesn't use - left as-is rather than
force-upgrading vitest's major version for a Phase 2 skeleton.

## Config

See `.env.example` for every environment variable and its default
(`src/config/index.ts` is the source of truth).
