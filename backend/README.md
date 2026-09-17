# Vuaco Backend (Phase 2)

REST API skeleton + an isolated Pikafish (Xiangqi engine) wrapper, per
[`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md). This is the only part of
the system that ever talks to Pikafish - the Flutter client only ever calls
this backend's own REST endpoints.

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

Socket.io is initialized (see `src/websocket/socket.ts`) but has no
events/namespaces yet - that's Phase 4 (online multiplayer).

## Data model / migrations

`migrations/*.sql` are applied in filename order by `npm run migrate`
(tracked in a `schema_migrations` table, no down-migrations). `0001_init.sql`
creates the `users`/`matches`/`rooms` skeleton from
`docs/ARCHITECTURE.md` section 6 - expand these as later phases need real
columns (auth in particular is still TBD, see that doc's section 3).

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

Known: `npm audit` flags moderate/high advisories in `vitest`'s `vite`/
`esbuild` dev-server dependencies. These are dev-only tooling (never
shipped in the runtime image) and exploitable only via a locally-running
Vite dev server, which this project doesn't use - left as-is rather than
force-upgrading vitest's major version for a Phase 2 skeleton.

## Config

See `.env.example` for every environment variable and its default
(`src/config/index.ts` is the source of truth).
