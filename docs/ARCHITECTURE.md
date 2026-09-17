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
| Auth | TBD — decide before Phase 4 (multiplayer/friends) | Needed for username search & invites |

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
move-validation logic in Phase 4+ for server-authoritative multiplayer (client 
validation is for UX responsiveness only; never trust the client for match results).

## 5. API Contract Conventions (established in Phase 2, referenced after)
- Base path: `/api/v1/`
- Auth: TBD, likely JWT bearer tokens once decided
- Key endpoints (fill in as built):
  - `POST /api/v1/engine/analyze` — body: `{ fen: string, multiPv?: number,
    depth?: number }` → `{ bestMove, ponder?, depthReached, lines: [{
    multiPv, depth, scoreType: "cp"|"mate", scoreValue, pvMoves }] }`
    (implemented; see `backend/README.md`)
  - `GET /api/v1/health` — Postgres/Redis/engine-pool status (implemented)
  - `POST /api/v1/vision/scan` — body: image → returns `{ fen: string, confidence: number }`
  - `POST /api/v1/rooms` — create private room, returns 6-digit PIN + share link
  - WebSocket events: TBD, document namespace/event names here once Phase 4 starts

## 6. Data Model (high-level, expand in Phase 2+)
- `User`: id, username, elo, created_at
- `Match`: id, player_red_id, player_black_id, result, move_history, created_at
- `Room`: id, pin, host_id, status, timer_settings
- Full schema to be defined in Phase 2 backend prompt.

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
- **Phase 3** — Engine Coach UI (candidate move overlay, blunder detection). ⬜
- **Phase 4** — Online multiplayer (rooms, WebSocket sync, auth, matchmaking). ⬜
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