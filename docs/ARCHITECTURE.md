# ARCHITECTURE.md — Cờ Tướng Master (Xiangqi App)

This document is the persistent source of truth for architectural decisions. 
Every phase/feature prompt should reference this file rather than restate it. 
Update this doc whenever a major architectural decision changes.

## 1. Product Summary
A proprietary, closed-source Chinese Chess (Xiangqi / Cờ Tướng) mobile app with:
- AI-assisted learning (engine coach, blunder detection)
- Skill assessment & Elo-based placement
- Board import via FEN or camera photo
- Online multiplayer + local Pass & Play

## 2. Non-Negotiable Constraint: GPL Isolation
The Pikafish chess engine is GPL-3.0 licensed. To keep the app proprietary:
- **Pikafish MUST run only as an isolated backend microservice**, communicating 
  via UCI protocol internally, and exposing results to our own backend over an 
  internal API boundary.
- **The Flutter client NEVER links against, bundles, or compiles any GPL code.** 
  The client only talks to our backend over REST/WebSocket, and our backend is 
  the only thing that talks to Pikafish.
- Any future change involving GPL/AGPL-licensed dependencies must be reviewed 
  against this constraint before implementation.

## 3. Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| Client | Flutter (Dart), Riverpod | Clean architecture: domain/data/presentation |
| Backend API | Node.js (TypeScript) | REST + WebSocket (Socket.io) |
| Realtime | WebSocket via backend | Match sync, clocks, presence |
| AI Engine Service | Isolated Pikafish wrapper (UCI) | Internal-only, never exposed to client directly |
| Database | Postgres | Users, matches, rooms, Elo history |
| Cache / Room State | Redis | Active room state, matchmaking, rate limiting |
| Vision (v1) | Cloud Vision API (GPT-4o / Gemini) | Photo → FEN |
| Vision (v2, later) | Local ONNX/TFLite model | Only after v1 proves demand; separate effort with its own data pipeline |
| Auth | Guest JWT (Phase 4) | No password/refresh flow yet - every login creates a fresh guest user; see backend/README.md |

## 4. High-Level System Diagram (textual)

Flutter Client
│
├── REST/WebSocket ──> Backend API (Node.js)
│ │
│ ├── Postgres (persistent data)
│ ├── Redis (room/session state)
│ ├── Engine Service (internal only) ──> Pikafish (UCI)
│ └── Cloud Vision API (external, photo → FEN)
│
└── Local domain layer (rules engine, runs fully offline for Pass & Play)


The **rules engine** (move validation, check/checkmate detection, FEN parsing) 
is pure Dart, lives in the client's domain layer, and has no dependency on the 
backend — it must work fully offline for Pass & Play. The backend has its own 
independent TypeScript port of the same rules (`backend/src/xiangqi/`, see
backend/README.md) for server-authoritative multiplayer, added in Phase 4
(client validation is for UX responsiveness only; never trust the client for
match results). The two implementations are deliberately kept structurally
parallel (same file names/functions, ported 1:1) so a rules change is easy to
apply to both - see RULES_ENGINE.md's "Online Multiplayer" section.

## 5. API Contract Conventions (established in Phase 2, referenced after)
- Base path: `/api/v1/`
- Auth: `Authorization: Bearer <jwt>`, obtained from `POST /api/v1/auth/guest`
  (implemented; see backend/README.md and section 3 above)
- Key endpoints (fill in as built):
  - `POST /api/v1/engine/analyze` — body: `{ fen: string, multiPv?: number,
    depth?: number }` → `{ bestMove, ponder?, depthReached, lines: [{
    multiPv, depth, scoreType: "cp"|"mate", scoreValue, pvMoves }] }`
    (implemented; see `backend/README.md`)
  - `GET /api/v1/health` — Postgres/Redis/engine-pool status (implemented)
  - `POST /api/v1/vision/scan` — body: image → returns `{ fen: string, confidence: number }`
  - `POST /api/v1/auth/guest` — body: `{ username: string }` → `{ token,
    user: { id, username, elo } }` (implemented; always creates a fresh
    guest user, see backend/README.md)
  - `POST /api/v1/rooms` — body: `{ timeControlMinutes?, incrementSeconds?
    }` → `{ roomId, pin, shareLink, state: RoomStateSnapshot }` (implemented,
    requires auth)
  - `POST /api/v1/rooms/join` — body: `{ pin }` → `{ state: RoomStateSnapshot
    }` (implemented, requires auth, Redis-rate-limited per section 7)
  - `GET /api/v1/rooms/:id` — `{ state: RoomStateSnapshot }` (implemented,
    requires auth)
- WebSocket events (implemented, Phase 4; see
  `backend/src/websocket/roomsGateway.ts`). JWT passed via
  `socket.handshake.auth.token` at connect time, same token as REST.
  - Client → server: `room:join` `{ roomId }` (ack: `{ ok, state? }`),
    `move:make` `{ roomId, from: {row,col}, to: {row,col} }` (ack: `{ ok,
    error?, message? }`)
  - Server → client: `room:state` (full `RoomStateSnapshot`, broadcast to
    every socket in the room on any change - join, move, clock timeout)

## 6. Data Model (high-level, expand in Phase 2+)
- `User`: id, username, elo, created_at
- `Match`: id, player_red_id, player_black_id, result, move_history, created_at
- `Room`: id, pin, host_id, guest_id, status, timer_settings, match_id
  (`guest_id`/`match_id` added in Phase 4 - see
  `backend/migrations/0002_rooms_multiplayer.sql`)
- Live game state (board, clock) is NOT in Postgres - it lives in the
  backend's in-memory `RoomManager` for as long as the room is active, and
  a `Match` row is written once the game ends. See backend/README.md for
  what this means for horizontal scaling (currently single-process only).

## 7. Security Notes
- Room PINs must be rate-limited on join attempts (Redis-backed) to prevent 
  brute-forcing 6-digit codes.
- Server is authoritative for all multiplayer match results — client-side move 
  validation is UX-only.
- Cloud Vision API calls must strip/avoid sending any user PII beyond the board 
  photo itself.

## 8. Phased Build Plan
- **Phase 1** — Core rules engine + local Pass & Play (client-only, offline). ✅
  Domain layer + full unit test suite in `lib/domain/`, integration contract
  documented in `RULES_ENGINE.md`. Pass & Play UI in `lib/presentation/`.
- **Phase 2** — Backend API skeleton + Pikafish microservice + `/engine/analyze`. ✅
  Node/TypeScript API in `backend/`, see `backend/README.md`. Pikafish is
  compiled from unmodified upstream source in its own Docker build stage
  and invoked only as a separate OS process over UCI (GPL isolation intact
  - client still never talks to it directly). `/api/v1/engine/analyze` and
  `/api/v1/health` verified end-to-end against the real engine, both
  spawned directly and through the full `docker compose` stack (Postgres +
  Redis + api). Socket.io is wired but has no events yet (Phase 4).
- **Phase 3** — Engine Coach UI (candidate move overlay, blunder detection). ✅
  Flutter client calls the Phase 2 backend's `/api/v1/engine/analyze`
  (`EngineCoachController` in `lib/presentation/providers/`) whenever the
  position changes; candidate lines render as ranked arrows on the board,
  and blunders are flagged by diffing consecutive analyses (no extra API
  calls) against `kBlunderThresholdCentipawns`. No settings UI yet for the
  backend base URL (hardcoded `http://localhost:3000/api/v1`) - add one
  before this leaves local dev. See RULES_ENGINE.md's "Engine Coach" section.
- **Phase 4** — Online multiplayer (rooms, WebSocket sync, auth, matchmaking). ✅
  Guest-JWT auth (`POST /auth/guest`), PIN-based rooms (`POST /rooms`,
  `POST /rooms/join`, Redis-rate-limited per section 7) backed by a
  TypeScript port of the rules engine (`backend/src/xiangqi/`) for
  server-authoritative move validation and clock enforcement, synced over
  Socket.io (`room:join`, `move:make`, `room:state`). Flutter gets a new
  Online Lobby + Online Match screen (`lib/presentation/screens/`) reusing
  `XiangqiBoardView` against a server-sent FEN. "Matchmaking" here means
  PIN-based room joining only - no ranked queue and no username-search
  friend invite (out of scope for this pass, see RULES_ENGINE.md). No deep
  link handling for the room share link yet (placeholder `vuaco://` scheme).
  See RULES_ENGINE.md's "Online Multiplayer" section and backend/README.md.
- **Phase 5** — FEN import + Cloud Vision board scan + correction UI. ⬜
- **Phase 6** (later, separate effort) — Local on-device vision model. ⬜

Update the checkboxes/status as phases complete. Each phase's implementation 
prompt should link back to this file and only restate what's new/changed.

## 9. Design Reference
Visual style: mahogany/parchment/gold/jade Xiangqi aesthetic.
Full Stitch-exported design files (HTML/CSS + assets) are located at:
`/design/stitch-export/`
Reference these directly for exact spacing, colors, and component styling 
rather than re-deriving from the text description below.

Quick-reference palette (see `design/StyleGuide.md` for the full system;
mirrored in code as `XiangqiColors` in `lib/presentation/theme/app_theme.dart`):
- Primary Background: Deep Mahogany `#2C1810`
- Secondary Background: Warm Walnut `#4A2E1B`
- Surface / Card: Aged Parchment `#F4E8C1`
- Accent Primary: Traditional Crimson `#A8342A` (CTAs, alerts, Red pieces)
- Accent Secondary: Imperial Gold `#C9A24B` (highlights, badges, borders)
- Accent Tertiary: Jade Green `#2E5A44` (secondary actions, Black pieces)
- Text on dark: Cream `#F4E8C1` · Text on parchment: Dark Walnut `#2C1810`

Typography: custom serif/CJK type from the style guide is not yet bundled as
a Flutter font asset (Phase 1 uses system fonts, which already render the
Chinese piece glyphs correctly) — add the font files and wire them into
`pubspec.yaml`/`ThemeData.textTheme` in a later pass.

## 10. Testing Philosophy
- Domain/rules logic: full unit test coverage, especially edge-case piece rules 
  (elephant eye-blocking, horse leg-blocking, cannon screen-capture, flying 
  general) and checkmate/stalemate detection.
- Backend: integration tests for API contracts, especially move validation and 
  match state transitions.
- No phase is "done" until its stated test requirements pass.