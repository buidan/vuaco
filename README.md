# Vuaco — Cờ Tướng Master

A Chinese Chess (Xiangqi) app: a Flutter client (Pass & Play, an Engine
Coach powered by Pikafish, online multiplayer, and FEN/board-setup import)
backed by a Node.js/TypeScript API.

**New here?** Start with [`SETUP.md`](SETUP.md) to get the app and backend
running locally.

## Documentation map

- [`SETUP.md`](SETUP.md) — practical guide to running the app and backend
  on your machine.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — the persistent source of
  truth for product/architecture decisions and phase-by-phase status.
- [`RULES_ENGINE.md`](RULES_ENGINE.md) — the client's domain layer (rules
  engine, FEN codec, Engine Coach, online multiplayer, board setup): what
  it is, how it's structured, and integration notes for anyone extending it.
- [`backend/README.md`](backend/README.md) — the backend's own internals
  (auth, rooms/realtime multiplayer, the server-side rules engine port,
  Pikafish integration, migrations, tests).

## Repository layout

```
lib/            Flutter client (domain / data / presentation)
test/           Flutter test suite
backend/        Node.js/TypeScript API (REST + WebSocket)
docs/           Architecture decisions
design/         Visual style guide and design references
```
