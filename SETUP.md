# SETUP.md — Running Vuaco locally

This is the practical "get it running on my machine" guide. For what's
been built and why, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
(product/architecture decisions), [`RULES_ENGINE.md`](RULES_ENGINE.md)
(the domain layer), and [`backend/README.md`](backend/README.md) (backend
internals) - this doc just gets you to a running app.

## What needs to run for what

Pass & Play and the board-setup (FEN import / hand-edit) flow work fully
offline - no backend needed. Everything else needs the backend running:

| Feature | Needs the backend? |
|---|---|
| Pass & Play | No |
| Set Up Position (FEN paste / board editor) | No |
| Engine Coach (candidate moves, blunder detection) | Yes |
| Play Online (multiplayer rooms) | Yes |
| Photo → FEN board scan | Yes, and the backend also needs `GEMINI_API_KEY` set - see step 2 |

If you only want to poke at Pass & Play or the board editor, skip straight
to "Flutter app" below and you can ignore the backend section entirely.

## 1. Prerequisites

- **Flutter SDK** (this project targets Dart `^3.12.2` per `pubspec.yaml`;
  `flutter --version` should report a matching Dart version). Install via
  https://docs.flutter.dev/get-started/install if you don't have it.
- **A place to run the app**: see "Setting up a device" right below -
  `flutter doctor` and `flutter devices` tell you what's already usable.
- **Docker Desktop** (or another Docker-compatible runtime) - only needed
  if you want Engine Coach, Play Online, or the Cloud Vision board scan,
  since the backend's Pikafish build and Postgres/Redis run in containers.
- **Node.js 20+** - only needed if you want to run the backend directly on
  your host instead of in Docker (faster iteration, but see the Pikafish
  caveat below).

### Setting up a device

Run `flutter doctor` first - it tells you exactly what's missing for each
platform. In order of least to most setup:

- **Android emulator (usually fastest if Android Studio is already
  installed)**: `flutter emulators` lists any AVD you've already created
  in Android Studio - if one's listed, `flutter emulators --launch <id>`
  starts it, no further setup needed. If none is listed, create one in
  Android Studio (More Actions -> Virtual Device Manager -> Create Device)
  or via `flutter emulators --create`. The emulator's built-in webcam can
  stand in for a real camera when testing the board-scan photo flow.
- **Physical Android device**: enable Developer Options + USB debugging on
  the phone, plug it in via USB, accept the debugging prompt - it then
  shows up in `flutter devices`.
- **iOS Simulator or macOS desktop build**: needs the **full Xcode app**
  (not just the Command Line Tools - `flutter doctor` says "Xcode
  installation is incomplete" if you only have those). Install Xcode from
  the App Store (it's large, plan for a while), then run the two commands
  `flutter doctor` prints (`sudo xcode-select --switch
  /Applications/Xcode.app/Contents/Developer` and `sudo xcodebuild
  -runFirstLaunch`). You'll also need **CocoaPods** (`brew install
  cocoapods` is simplest) - this project's `image_picker` dependency
  (photo scan) has native iOS/macOS code that needs Pods to link, so a
  build will fail without it even once Xcode itself is set up.
- **Chrome (web)**: install Chrome normally, or point `flutter doctor` at
  another Chromium build via the `CHROME_EXECUTABLE` environment variable.
  Not a primary target for this app, but it works for a quick look.

## 2. Backend

### Option A: everything in Docker (simplest)

```sh
cd backend
docker compose up -d --build      # postgres (:5433), redis (:6380), api (:3000)
docker compose run --rm api node dist/db/migrate.js   # first time only, and after any new migration
curl http://localhost:3000/api/v1/health
```

`--build` compiles Pikafish from source the first time (a few minutes);
subsequent `docker compose up -d` calls reuse the cached image. The health
check should report `{"status":"ok", ...}` once Postgres, Redis, and the
Pikafish pool are all up (the API container waits for Postgres/Redis to be
healthy before starting, but still takes a couple of seconds to load the
NNUE network - retry the health check once or twice if it's not there yet).

Ports are intentionally shifted from Postgres/Redis defaults (`5433`,
`6380`) so this won't collide with any other local Postgres/Redis you may
already have running on `5432`/`6379`.

To stop everything: `docker compose down` (add `-v` if you also want to
drop the Postgres volume and start from a clean database next time).

### Option B: backend on the host, infra in Docker (faster iteration)

```sh
cd backend
docker compose up -d postgres redis
cp .env.example .env
npm install
npm run migrate
npm run dev
```

You'll need a Pikafish binary on your host for this option, since
`.env.example`'s `PIKAFISH_BIN_PATH` points at the Docker image's install
location. Either:
- extract a [Pikafish release](https://github.com/official-pikafish/Pikafish/releases)
  for your platform (one archive contains a prebuilt binary + the
  `pikafish.nnue` network file for macOS/Linux/Windows) and point
  `PIKAFISH_BIN_PATH`/`PIKAFISH_CWD` in `.env` at wherever you extracted
  it, or
- build it yourself (`cd src && make -j profile-build` in the Pikafish
  source) - see `backend/README.md`'s "GPL isolation" section for why the
  Docker image compiles from source instead of using the release binary.

Either way, `.env.example` lists every environment variable and its
default - copy it to `.env` and edit what you need (`src/config/index.ts`
is the source of truth if you want to double-check a default).

### Verifying the backend works end to end

```sh
# guest login
curl -s -X POST http://localhost:3000/api/v1/auth/guest \
  -H 'Content-Type: application/json' -d '{"username":"Test"}'

# engine analysis (paste the token from above if you want to test /rooms too)
curl -s -X POST http://localhost:3000/api/v1/engine/analyze \
  -H 'Content-Type: application/json' \
  -d '{"fen":"rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1","multiPv":2}'
```

Both should return JSON, not an error. If `/engine/analyze` times out or
errors, check `docker compose logs api` for Pikafish startup issues.

## 3. Flutter app

```sh
flutter pub get
flutter devices        # see what you can run on
flutter run             # pick a device if more than one is listed
```

The app opens on a Home screen with three entries: **Pass & Play**, **Play
Online**, and **Set Up Position**. Pass & Play and Set Up Position work
immediately with no further configuration.

### Pointing the app at your backend

The backend URLs are hardcoded in
[`lib/presentation/providers/backend_config_providers.dart`](lib/presentation/providers/backend_config_providers.dart)
(no settings UI yet - see docs/ARCHITECTURE.md):

```dart
final backendRestBaseUrlProvider = Provider<String>((ref) => 'http://localhost:3000/api/v1');
final backendSocketUrlProvider = Provider<String>((ref) => 'http://localhost:3000');
```

`localhost` only reaches a backend running on the **same machine** as the
Flutter process, which works out of the box for:
- an iOS Simulator or a Flutter desktop build (macOS/Linux/Windows) on the
  same computer running Docker.

It does **not** work for:
- **Android emulator**: the emulator's `localhost` is itself, not your
  host machine. Change both URLs above to use `10.0.2.2` instead of
  `localhost` (the emulator's special alias for the host).
- **A physical device** (phone/tablet): change `localhost` to your
  computer's LAN IP address (e.g. `192.168.1.23`) and make sure the device
  is on the same network and nothing (firewall, VPN) blocks port 3000.

After editing, hot-restart the app (not hot-reload - these are `Provider`
defaults, resolved once) for the change to take effect.

### Running the test suite

```sh
flutter test
```

No backend or emulator needed - every test either exercises pure Dart
domain logic, uses a fake/mocked repository, or drives the widget tree
with simulated taps (see `RULES_ENGINE.md` for why: this sandbox had no
simulator/browser during development, so that became the standard pattern
here too, and it stuck because it's fast and deterministic).

## 4. Backend test suite

```sh
cd backend
npm test
```

Also needs no live Postgres/Redis/Pikafish for most of it - one test
(`test/websocket/roomsGateway.test.ts`) spins up a real `http.Server` and a
real `socket.io-client` against it, but that's self-contained within the
test process. See `backend/README.md`'s "Tests" section for what's mocked
vs. real.

## 5. Common issues

- **`docker compose up` fails to bind a port**: something else is already
  using `5433`, `6380`, or `3000`. Either stop that process or edit the
  port mappings in `backend/docker-compose.yml`.
- **`/engine/analyze` or a multiplayer room hangs**: check
  `docker compose logs api` - a common cause is the Pikafish pool still
  loading (~a few seconds after container start) or (Option B only) a
  wrong `PIKAFISH_BIN_PATH`.
- **Play Online works on the simulator but not a real device**: almost
  always the `localhost` vs. LAN-IP issue above.
- **Postgres migration errors after pulling new backend changes**: run
  `docker compose run --rm api node dist/db/migrate.js` (or
  `npm run migrate` for Option B) again - migrations are additive and
  tracked in a `schema_migrations` table, so re-running is always safe.
- **A backend code change doesn't show up in Docker**: Option A's
  `docker compose up -d --build` is needed to rebuild the image; plain
  `docker compose up -d` reuses whatever was last built. Option B's
  `npm run dev` hot-reloads automatically.
