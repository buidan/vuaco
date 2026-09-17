import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/data/repositories/auth_repository.dart';
import 'package:vuaco/data/repositories/online_match_repository.dart';
import 'package:vuaco/domain/fen/fen_codec.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/game_result.dart';
import 'package:vuaco/domain/models/online_room.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/presentation/providers/online_match_providers.dart';

const _startFen = 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

RoomState _room({
  required Side sideToMove,
  String fen = _startFen,
  RoomPlayerInfo? black,
  GameResult? result,
  RoomStatus status = RoomStatus.active,
}) {
  return RoomState(
    roomId: 'room-1',
    pin: 'ABC123',
    status: status,
    fen: fen,
    sideToMove: sideToMove,
    result: result ?? const GameResult.ongoing(),
    red: const RoomPlayerInfo(userId: 'host-1', username: 'Alice', connected: true),
    black: black ?? const RoomPlayerInfo(userId: 'guest-1', username: 'Bob', connected: true),
    clock: null,
    history: const [],
  );
}

class FakeAuthRepository implements AuthRepository {
  final AuthSession Function(String username) responder;
  FakeAuthRepository(this.responder);

  @override
  Future<AuthSession> guestLogin(String username) async => responder(username);

  @override
  void close() {}
}

class FakeOnlineMatchRepository implements OnlineMatchRepository {
  RoomState? createdState;
  RoomState? joinedState;
  final StreamController<RoomState> _controller = StreamController<RoomState>.broadcast();
  List<Object?> sentMoves = [];
  Object? nextMoveError;
  bool connected = false;

  @override
  Stream<RoomState> get roomStateStream => _controller.stream;

  void pushState(RoomState state) => _controller.add(state);

  @override
  Future<RoomCreatedInfo> createRoom(String token, {int? timeControlMinutes, int? incrementSeconds}) async {
    return RoomCreatedInfo(roomId: createdState!.roomId, pin: createdState!.pin, shareLink: 'vuaco://x', state: createdState!);
  }

  @override
  Future<RoomState> joinRoomByPin(String token, String pin) async => joinedState!;

  @override
  Future<void> connectLive(String token) async {
    connected = true;
  }

  @override
  Future<RoomState> joinRoomLive(String roomId) async => createdState ?? joinedState!;

  @override
  Future<void> sendMove(String roomId, BoardPoint from, BoardPoint to) async {
    sentMoves.add([roomId, from, to]);
    if (nextMoveError != null) {
      final err = nextMoveError!;
      nextMoveError = null;
      // ignore: only_throw_errors
      throw err;
    }
  }

  @override
  Future<void> disconnectLive() async {
    connected = false;
  }

  @override
  void close() {
    unawaited(_controller.close());
  }
}

void main() {
  group('OnlineMatchController', () {
    test('continueAsGuest stores the session', () async {
      final fakeAuth = FakeAuthRepository((u) => AuthSession(token: 't1', userId: 'host-1', username: u));
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
      ]);
      addTearDown(container.dispose);

      await container.read(onlineMatchControllerProvider.notifier).continueAsGuest('Alice');
      final state = container.read(onlineMatchControllerProvider);
      expect(state.session?.username, 'Alice');
      expect(state.error, isNull);
    });

    test('hostRoom creates, connects, and joins live, exposing my side', () async {
      final fakeAuth = FakeAuthRepository((u) => const AuthSession(token: 't1', userId: 'host-1', username: 'Alice'));
      final fakeMatch = FakeOnlineMatchRepository()..createdState = _room(sideToMove: Side.red);

      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        onlineMatchRepositoryProvider.overrideWithValue(fakeMatch),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(onlineMatchControllerProvider.notifier);
      await controller.continueAsGuest('Alice');
      await controller.hostRoom(timeControlMinutes: 10);

      final state = container.read(onlineMatchControllerProvider);
      expect(fakeMatch.connected, isTrue);
      expect(state.room?.roomId, 'room-1');
      expect(state.mySide, Side.red);
      expect(state.busy, isFalse);
    });

    test('room state stream updates propagate into controller state', () async {
      final fakeAuth = FakeAuthRepository((u) => const AuthSession(token: 't1', userId: 'host-1', username: 'Alice'));
      final fakeMatch = FakeOnlineMatchRepository()..createdState = _room(sideToMove: Side.red);
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        onlineMatchRepositoryProvider.overrideWithValue(fakeMatch),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(onlineMatchControllerProvider.notifier);
      await controller.continueAsGuest('Alice');
      await controller.hostRoom();

      fakeMatch.pushState(_room(sideToMove: Side.black));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(onlineMatchControllerProvider).room?.sideToMove, Side.black);
    });

    test('selectPoint highlights legal destinations only on my turn', () async {
      final fakeAuth = FakeAuthRepository((u) => const AuthSession(token: 't1', userId: 'host-1', username: 'Alice'));
      final fakeMatch = FakeOnlineMatchRepository()..createdState = _room(sideToMove: Side.red);
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        onlineMatchRepositoryProvider.overrideWithValue(fakeMatch),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(onlineMatchControllerProvider.notifier);
      await controller.continueAsGuest('Alice');
      await controller.hostRoom(); // mySide = red, sideToMove = red

      controller.selectPoint(const BoardPoint(3, 4)); // central red soldier
      final state = container.read(onlineMatchControllerProvider);
      expect(state.selected, const BoardPoint(3, 4));
      expect(state.legalDestinations, contains(const BoardPoint(4, 4)));
    });

    test('selectPoint does not allow selecting when it is not my turn', () async {
      final fakeAuth = FakeAuthRepository((u) => const AuthSession(token: 't1', userId: 'guest-1', username: 'Bob'));
      final fakeMatch = FakeOnlineMatchRepository()..createdState = _room(sideToMove: Side.red);
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        onlineMatchRepositoryProvider.overrideWithValue(fakeMatch),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(onlineMatchControllerProvider.notifier);
      await controller.continueAsGuest('Bob');
      await controller.hostRoom(); // mySide resolves to black (guest-1), sideToMove = red

      controller.selectPoint(const BoardPoint(6, 4)); // a black soldier, but not black's turn
      final state = container.read(onlineMatchControllerProvider);
      expect(state.selected, isNull);
    });

    test('tapping a legal destination sends the move to the repository', () async {
      final fakeAuth = FakeAuthRepository((u) => const AuthSession(token: 't1', userId: 'host-1', username: 'Alice'));
      final fakeMatch = FakeOnlineMatchRepository()..createdState = _room(sideToMove: Side.red);
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        onlineMatchRepositoryProvider.overrideWithValue(fakeMatch),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(onlineMatchControllerProvider.notifier);
      await controller.continueAsGuest('Alice');
      await controller.hostRoom();

      controller.selectPoint(const BoardPoint(3, 4));
      controller.selectPoint(const BoardPoint(4, 4));
      await Future<void>.delayed(Duration.zero);

      expect(fakeMatch.sentMoves, hasLength(1));
      expect(container.read(onlineMatchControllerProvider).selected, isNull);
    });

    test('a rejected move surfaces its message as an error', () async {
      final fakeAuth = FakeAuthRepository((u) => const AuthSession(token: 't1', userId: 'host-1', username: 'Alice'));
      final fakeMatch = FakeOnlineMatchRepository()..createdState = _room(sideToMove: Side.red);
      fakeMatch.nextMoveError = const MoveRejectedException('notYourTurn', 'not your turn');
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        onlineMatchRepositoryProvider.overrideWithValue(fakeMatch),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(onlineMatchControllerProvider.notifier);
      await controller.continueAsGuest('Alice');
      await controller.hostRoom();

      controller.selectPoint(const BoardPoint(3, 4));
      controller.selectPoint(const BoardPoint(4, 4));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(onlineMatchControllerProvider).error, 'not your turn');
    });

    test('leaveRoom disconnects and clears room state', () async {
      final fakeAuth = FakeAuthRepository((u) => const AuthSession(token: 't1', userId: 'host-1', username: 'Alice'));
      final fakeMatch = FakeOnlineMatchRepository()..createdState = _room(sideToMove: Side.red);
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        onlineMatchRepositoryProvider.overrideWithValue(fakeMatch),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(onlineMatchControllerProvider.notifier);
      await controller.continueAsGuest('Alice');
      await controller.hostRoom();
      await controller.leaveRoom();

      final state = container.read(onlineMatchControllerProvider);
      expect(state.room, isNull);
      expect(fakeMatch.connected, isFalse);
    });
  });

  test('sanity: FenCodec decodes the fixture FEN used above', () {
    final board = FenCodec.decode(_startFen).board;
    expect(board, isA<Board>());
  });
}
