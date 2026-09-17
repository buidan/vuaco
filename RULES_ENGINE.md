# RULES_ENGINE.md — Domain Layer Integration Guide

This document describes `lib/domain/`, the pure-Dart Xiangqi rules engine
built in Phase 1, plus the Phase 3 Engine Coach models/notation additions
noted inline below. It has no Flutter dependency and no I/O — read it
before wiring multiplayer sync (Phase 4) into it, so that phase reuses this
layer instead of re-deriving move legality.

## Orientation (read this first)

Board coordinates are `(row, col)`: `row` 0-9, `col` 0-8.

- Red occupies rows 0-4 (bottom as rendered), Black occupies rows 5-9 (top).
- The river lies between row 4 and row 5.
- Red's palace: cols 3-5, rows 0-2. Black's palace: cols 3-5, rows 7-9.
- Red advances toward increasing rows; Black advances toward decreasing rows.
- The Pass & Play board does **not** flip between turns in Phase 1 (Red's
  back rank always renders at the bottom) — see `XiangqiBoardView` for where
  to add a flip setting later.

## Layer map

```
lib/domain/
  models/     Plain data: Side, PieceType, Piece, BoardPoint, Board,
              Move, MoveHistoryEntry, GameResult, IllegalMoveReason,
              MoveValidationResult (sealed: LegalMove | IllegalMove),
              ChessClock/ClockConfig.
  rules/      board_geometry.dart  - zone constants (palace/river) shared by
                                     every rule below.
              piece_moves.dart     - pseudo-legal move generation per piece
                                     type (movement shape + blocking only;
                                     does NOT check self-check).
              attack_detector.dart - isSquareAttackedBy, isFlyingGeneralFacing,
                                     isGeneralInCheck.
              legal_move_generator.dart - filters piece_moves' pseudo-legal
                                     moves through attack_detector to produce
                                     fully legal moves.
  fen/        fen_codec.dart - Pikafish/UCCI-style FEN encode/decode.
  notation/   move_notation.dart - "e3-e4" / "e3xe4+" coordinate notation.
  engine/     xiangqi_engine.dart - XiangqiEngine: the façade every other
                                     layer should depend on.
```

`Board` is immutable: every mutation-shaped method (`applyMove`,
`withPieceAt`) returns a new `Board`. This is what makes undo/redo (and,
later, "show the position after move N" or speculative AI search) a matter
of holding onto old `Board` references rather than replaying moves.

## The integration point: `XiangqiEngine`

Everything above `engine/` is an implementation detail. Presentation code,
and later the AI coach / multiplayer sync, should talk to `XiangqiEngine`
only:

```dart
final engine = XiangqiEngine();               // standard starting position
// or: XiangqiEngine.fromFen(fenString);       // resume/import a position

engine.board;                 // current Board
engine.sideToMove;            // Side.red | Side.black
engine.result;                // GameResult (ongoing / redWins / blackWins, + reason)
engine.legalDestinationsFrom(point);  // List<BoardPoint> for UI highlighting
engine.allLegalMoves;         // List<Move> - full legal move list (search/AI hook)
engine.isInCheck(side);
engine.toFen();

final outcome = engine.tryMove(from, to);      // MoveValidationResult
switch (outcome) {
  case LegalMove(move: final move, leavesOpponentInCheck: final check):
    // move applied, history updated, turn flipped
  case IllegalMove(reason: final reason, message: final message):
    // nothing changed; `reason` is a stable enum for UI/AI-coach messaging
}

engine.undo();   // false if there's nothing to undo
engine.redo();   // false if there's nothing to redo
```

`tryMove` is the only way to mutate an engine. It validates, then executes,
in one call — there is no separate "just validate" method, because
computing full legality already requires simulating the move. If you need
to check legality without committing (e.g. an AI evaluating candidate
moves), use `legalDestinationsFrom` / `allLegalMoves` instead, which do not
mutate state.

## Rule implementation notes worth knowing before touching this code

- **Check** (`AttackDetector.isGeneralInCheck`) is "is the general's square
  attacked by any enemy piece's pseudo-legal move" **or** the flying-general
  facing condition — both are folded into one function so
  `LegalMoveGenerator` only has one thing to check after simulating a move.
- **Flying general**: `AttackDetector.isFlyingGeneralFacing` is whole-board
  validation (are the two generals on the same column with nothing between
  them?), not a per-piece rule — it can't be, since neither general can
  normally attack at range. It's checked after every simulated move, same as
  ordinary check.
- **Advisors and elephants can never deliver check.** Advisors never leave
  their own palace, and elephants never cross the river, so neither can ever
  reach a square from which it threatens the *enemy* general. This is a real
  consequence of the rules, not a shortcut — see
  `test/domain/rules/check_detection_test.dart` for the regression tests.
- **No stalemate draw.** `LegalMoveGenerator.hasAnyLegalMove` returning
  `false` is always a loss for the side to move, whether or not they're in
  check (`GameEndReason.checkmate` vs `GameEndReason.noLegalMoves` records
  which, for UI messaging).
- **Cannon captures** need exactly one piece (either color) strictly between
  the cannon and the target; a second piece anywhere in between blocks the
  capture entirely, even if the "real" target further on is an enemy piece.
- **Horse leg-blocking** checks the orthogonal square along the *longer*
  axis of the L (e.g. for a `(±2, ±1)` move, the leg is one step in the row
  direction), not the destination square itself.
- **Perpetual check / chasing rules are out of scope for Phase 1** — see the
  `TODO` near `LegalMoveGenerator`/`XiangqiEngine`. `GameResult` and
  `MoveHistoryEntry` are shaped so a repetition detector can be layered on
  top later without changing their public fields (it would consume
  `engine.history` and inject an additional `GameResult` outcome).

## FEN format

`FenCodec` uses the same piece letters as Pikafish/UCCI (`K A B N R C P`,
uppercase Red / lowercase Black), and the same field order as chess FEN
(`<board> <side> - - <halfmove> <fullmove>`, `w` = Red to move). This is
deliberate: Phase 2's backend talks to Pikafish over UCI, so a FEN produced
by `engine.toFen()` should be usable there unchanged — no translation layer
needed when board import (Phase 5) or the engine coach (Phase 3) send a
position to the backend.

## Notation

Phase 1 uses plain coordinate notation (`e3-e4`, `e3xe4+`, `...#` for mate) —
file `a`-`i` (col 0-8), rank `0`-`9` (row). Traditional Chinese
piece-relative notation (e.g. 炮二平五) needs disambiguation rules (which of
several same-type pieces on a file, "front/middle/back soldier", etc.) that
are out of scope here; if a later phase wants it, add a second notation
module rather than changing `Move`/`MoveHistoryEntry` — they don't store
notation as their source of truth, `XiangqiEngine` computes it at record
time via `MoveNotation`.

`MoveNotation.parseSquare`/`parseUciMove` are the inverse operation
(string -> `BoardPoint`s), added in Phase 3 because this notation happens to
be identical to the UCI coordinate moves Pikafish returns (e.g. "e3e4") -
the Engine Coach overlay uses these to turn a candidate line's first move
back into board points to draw.

## Timer

`ClockConfig`/`ChessClock` (in `models/chess_clock.dart`) are pure data +
countdown math with no wall-clock or `Timer` access — `consume(side,
elapsed)` must be driven by whoever owns real time (a presentation-layer
`Timer.periodic`, or a multiplayer server tick in a later phase). Disabled
by default; `XiangqiEngine` holds one instance and applies `increment` on
each completed move, but nothing currently calls `consume` since Phase 1's
UI doesn't surface a clock.

## What the presentation layer does with this

`lib/data/repositories/pass_and_play_repository.dart` is the only thing
between Riverpod and `XiangqiEngine` — it exists so a later phase can swap
in a repository that resumes a saved/shared game without touching
`lib/presentation/`. `GameController` (in
`lib/presentation/providers/game_providers.dart`) owns one `XiangqiEngine`
instance and re-derives a `GameControllerState` snapshot after every
mutation; it holds no rules logic of its own. `GameControllerState.fen` is
`XiangqiEngine.toFen()` recomputed on every snapshot - it exists specifically
so the Engine Coach can send the current position to the backend without
reaching into the engine directly.

## Engine Coach (Phase 3)

`lib/domain/models/engine_analysis.dart` (`EngineAnalysisResult`/
`EngineAnalysisLine`) mirrors the backend's `AnalysisResult`/`AnalysisLine`
(`backend/src/engine/types.ts`) - plain data only, no JSON knowledge; decoding
the `POST /api/v1/engine/analyze` response into these lives in
`lib/data/repositories/engine_coach_repository.dart`
(`HttpEngineCoachRepository`), keeping the domain model serialization-agnostic
the same way `Board`/`Move` are.

`EngineCoachController` (`lib/presentation/providers/engine_coach_providers.dart`)
watches `gameControllerProvider` and, while enabled, calls `analyze()` after
every position change (`ref.listen` inside `build()`, comparing `Board`
instances by reference - every real move/undo/redo/new-game produces a new
`Board`, so reference inequality is a cheap, correct "position changed"
check). Blunder detection reuses this same continuous loop rather than
making extra API calls: each analysis is both the "after" eval for the move
that was just made *and* the "before" eval (baseline) for whichever move
comes next, so `_detectBlunder` just diffs consecutive results (negating one
side's centipawn score to the other's perspective - see
`EngineAnalysisLine.comparableScore` for how mate scores are folded onto the
same scale for this comparison only; display code should still special-case
`EngineScoreType.mate` for "Mate in N" text). This only fires immediately
after a real move (history length exactly +1 from the last recorded
baseline) - it does not try to handle undo/redo interleavings precisely.

The board overlay (`XiangqiBoardView`'s `candidateMoves` param, drawn by
`_CandidateArrowsPainter`) turns each line's first PV move (a UCI string like
"e3e4") into board points via `MoveNotation.parseUciMove`. The screen only
passes candidates through when `EngineCoachState.analyzedSide` matches the
current side to move, so a stale arrow for the position-before-last-move
never flashes up while a fresh analysis is in flight.

## Online Multiplayer (Phase 4)

The client is never trusted here - the backend has its own independent
TypeScript port of this entire domain layer at `backend/src/xiangqi/`
(`board.ts`, `pieceMoves.ts`, `attackDetector.ts`, `legalMoveGenerator.ts`,
`xiangqiEngine.ts`, `fenCodec.ts`, `moveNotation.ts`), ported 1:1 file-by-file
from the Dart originals specifically so the two stay easy to keep in sync -
**if you change a rule here, make the matching change there too** (see
backend/README.md for that side). The client's own domain layer is still
used for online play, but only for UX responsiveness: computing legal
destinations to highlight on tap (`LegalMoveGenerator.legalDestinationsFrom`,
called from `OnlineMatchController.selectPoint`), never as the source of
truth for what actually happened.

`lib/domain/models/online_room.dart` (`RoomState`/`RoomPlayerInfo`/
`RoomClockInfo`) mirrors the backend's `RoomStateSnapshot`
(`backend/src/rooms/roomManager.ts`) - plain data, no JSON/socket knowledge,
same split as `EngineAnalysisResult`. Note `RoomState.fen` is decoded with
the existing `FenCodec.decode` to get a `Board` for rendering - the online
match screen and Pass & Play's screen both feed `XiangqiBoardView` a `Board`
regardless of where it came from, they just decode it differently
(`XiangqiEngine.board` locally vs. `FenCodec.decode(room.fen)` here). This
extended `GameEndReason` with `timeout`/`resignation` (`game_result.dart`) -
values only the backend's `RoomManager` ever produces, never the local
`XiangqiEngine` (no clock UI or resign action there).

`lib/data/repositories/online_match_repository.dart`
(`SocketIoOnlineMatchRepository`) is the only thing that touches
`package:socket_io_client` - REST calls (`createRoom`/`joinRoomByPin`) go
through `package:http` like every other repository here;
`connectLive`/`joinRoomLive`/`sendMove` are the realtime half, matching
`backend/src/websocket/roomsGateway.ts`'s events 1:1. **Gotcha found the
hard way**: `socket_io_client`'s `io()` caches one `Manager` per host:port
within a process and will silently *share* (and deadlock) a connection
across two `io()` calls to the same backend unless each call passes
`enableForceNew()` - `connectLive` always does this, so don't remove it even
though it looks redundant for the common case of "one connection per app
instance." This was only caught by a real two-socket smoke test against a
live backend, not by any mocked unit test - if you touch this file, rerun a
real end-to-end check (two guest logins, two live connections, one move,
confirm the other side's `room:state` arrives) rather than trusting the
fake-repository controller tests alone.

`OnlineMatchController` (`lib/presentation/providers/online_match_providers.dart`)
never applies a move locally before the server confirms it - `selectPoint`
only manages tap-to-highlight state and calls `sendMove`; the board only
actually updates once `roomStateStream` delivers the server's broadcast.
This also means there's no move-slide animation for online play yet (unlike
Pass & Play's `TweenAnimationBuilder`) - the board snaps to each new
`RoomState.fen`, noted in `online_match_screen.dart` as an acceptable
simplification for this pass.

Deliberately out of scope this pass (see docs/ARCHITECTURE.md Phase 4
entry): real deep-link handling for the room share link (`shareLink` is a
placeholder `vuaco://join?pin=...` string, not wired to any platform deep
link), username-search friend invites, and a ranked matchmaking queue -
"matchmaking" here is PIN-based room joining only.
