import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/online_match_repository.dart';
import '../../domain/fen/fen_codec.dart';
import '../../domain/models/board_point.dart';
import '../../domain/models/online_room.dart';
import '../../domain/models/side.dart';
import '../../domain/rules/legal_move_generator.dart';
import 'backend_config_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = HttpAuthRepository(baseUrl: ref.watch(backendRestBaseUrlProvider));
  ref.onDispose(repository.close);
  return repository;
});

final onlineMatchRepositoryProvider = Provider<OnlineMatchRepository>((ref) {
  final repository = SocketIoOnlineMatchRepository(
    restBaseUrl: ref.watch(backendRestBaseUrlProvider),
    socketUrl: ref.watch(backendSocketUrlProvider),
  );
  ref.onDispose(repository.close);
  return repository;
});

class OnlineMatchState {
  final AuthSession? session;
  final RoomState? room;
  final Side? mySide;
  final BoardPoint? selected;
  final List<BoardPoint> legalDestinations;
  final bool busy;
  final String? error;

  const OnlineMatchState({
    this.session,
    this.room,
    this.mySide,
    this.selected,
    this.legalDestinations = const [],
    this.busy = false,
    this.error,
  });

  OnlineMatchState copyWith({
    AuthSession? session,
    RoomState? room,
    Side? mySide,
    BoardPoint? selected,
    List<BoardPoint>? legalDestinations,
    bool? busy,
    String? error,
    bool clearSelection = false,
    bool clearError = false,
    bool clearRoom = false,
  }) {
    return OnlineMatchState(
      session: session ?? this.session,
      room: clearRoom ? null : (room ?? this.room),
      mySide: clearRoom ? null : (mySide ?? this.mySide),
      selected: clearSelection ? null : (selected ?? this.selected),
      legalDestinations: clearSelection ? const [] : (legalDestinations ?? this.legalDestinations),
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives Phase 4's online multiplayer screens. Never validates a move
/// itself before sending it - `legalDestinations` here is purely for
/// tap-to-highlight UX (docs/ARCHITECTURE.md section 2: "client validation
/// is for UX responsiveness only"); the board actually updates only once
/// the server's `room:state` broadcast arrives via [roomStateStream].
class OnlineMatchController extends Notifier<OnlineMatchState> {
  StreamSubscription<RoomState>? _roomStateSubscription;

  @override
  OnlineMatchState build() {
    ref.onDispose(() => _roomStateSubscription?.cancel());
    return const OnlineMatchState();
  }

  Future<void> continueAsGuest(String username) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await ref.read(authRepositoryProvider).guestLogin(username);
      state = state.copyWith(session: session, busy: false, clearError: true);
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  Future<void> hostRoom({int? timeControlMinutes, int? incrementSeconds}) async {
    final session = state.session;
    if (session == null) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final repo = ref.read(onlineMatchRepositoryProvider);
      final created = await repo.createRoom(
        session.token,
        timeControlMinutes: timeControlMinutes,
        incrementSeconds: incrementSeconds,
      );
      await _goLive(repo, session, created.roomId, created.state);
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  Future<void> joinRoomByPin(String pin) async {
    final session = state.session;
    if (session == null) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final repo = ref.read(onlineMatchRepositoryProvider);
      final joined = await repo.joinRoomByPin(session.token, pin);
      await _goLive(repo, session, joined.roomId, joined);
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  Future<void> _goLive(
    OnlineMatchRepository repo,
    AuthSession session,
    String roomId,
    RoomState initialState,
  ) async {
    await repo.connectLive(session.token);
    _roomStateSubscription?.cancel();
    _roomStateSubscription = repo.roomStateStream.listen((room) {
      state = state.copyWith(room: room, mySide: _sideOf(room, session.userId), clearSelection: true);
    });
    final liveState = await repo.joinRoomLive(roomId);
    state = state.copyWith(
      busy: false,
      clearError: true,
      room: liveState,
      mySide: _sideOf(liveState, session.userId),
    );
  }

  Side? _sideOf(RoomState room, String userId) {
    if (room.red.userId == userId) return Side.red;
    if (room.black?.userId == userId) return Side.black;
    return null;
  }

  void selectPoint(BoardPoint point) {
    final room = state.room;
    final mySide = state.mySide;
    if (room == null || mySide == null || !room.result.isOngoing) return;

    if (state.selected == point) {
      state = state.copyWith(clearSelection: true);
      return;
    }

    if (state.selected != null && state.legalDestinations.contains(point)) {
      final from = state.selected!;
      state = state.copyWith(clearSelection: true);
      unawaited(_sendMove(room.roomId, from, point));
      return;
    }

    if (room.sideToMove != mySide) {
      state = state.copyWith(clearSelection: true);
      return;
    }

    final board = FenCodec.decode(room.fen).board;
    final piece = board.pieceAt(point);
    if (piece != null && piece.side == mySide) {
      final legal = LegalMoveGenerator.legalDestinationsFrom(board, point, mySide);
      state = state.copyWith(selected: point, legalDestinations: legal);
    } else {
      state = state.copyWith(clearSelection: true);
    }
  }

  Future<void> _sendMove(String roomId, BoardPoint from, BoardPoint to) async {
    try {
      await ref.read(onlineMatchRepositoryProvider).sendMove(roomId, from, to);
    } on MoveRejectedException catch (e) {
      state = state.copyWith(error: e.message ?? e.reason);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> leaveRoom() async {
    await _roomStateSubscription?.cancel();
    _roomStateSubscription = null;
    await ref.read(onlineMatchRepositoryProvider).disconnectLive();
    state = state.copyWith(clearSelection: true, clearError: true, clearRoom: true);
  }
}

final onlineMatchControllerProvider = NotifierProvider<OnlineMatchController, OnlineMatchState>(
  OnlineMatchController.new,
);
