import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/data/repositories/auth_repository.dart';
import 'package:vuaco/data/repositories/vision_repository.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/online_room.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/presentation/providers/board_editor_providers.dart';
import 'package:vuaco/presentation/providers/online_match_providers.dart';

const _sampleFen = 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

class _FakeAuthRepository implements AuthRepository {
  int guestLoginCalls = 0;

  @override
  Future<AuthSession> guestLogin(String username) async {
    guestLoginCalls++;
    return const AuthSession(token: 'fake-token', userId: 'guest-1', username: 'Guest');
  }

  @override
  void close() {}
}

class _FakeVisionRepository implements VisionRepository {
  VisionScanResult Function(String token, Uint8List bytes, String mimeType)? responder;
  Object? nextError;

  @override
  Future<VisionScanResult> scanBoardPhoto(String token, Uint8List bytes, String mimeType) async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      // ignore: only_throw_errors
      throw err;
    }
    return responder?.call(token, bytes, mimeType) ?? const VisionScanResult(fen: _sampleFen, confidence: 0.75);
  }

  @override
  void close() {}
}

void main() {
  group('BoardEditorController', () {
    test('starts from the standard position', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(boardEditorControllerProvider);
      expect(state.board.pieceAt(const BoardPoint(0, 4)), const Piece(PieceType.general, Side.red));
      expect(state.sideToMove, Side.red);
      expect(container.read(boardEditorControllerProvider.notifier).checkPlayability(), isNull);
    });

    test('clearBoard empties every square', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(boardEditorControllerProvider.notifier).clearBoard();
      final state = container.read(boardEditorControllerProvider);
      expect(state.board.occupiedSquares, isEmpty);
    });

    test('selecting a palette piece then tapping a point stamps it down', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      controller.clearBoard();
      controller.selectPaletteItem(const Piece(PieceType.chariot, Side.black));
      controller.tapBoardPoint(const BoardPoint(5, 5));

      final state = container.read(boardEditorControllerProvider);
      expect(state.board.pieceAt(const BoardPoint(5, 5)), const Piece(PieceType.chariot, Side.black));
    });

    test('the eraser clears whatever is on a square', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      controller.selectEraser();
      controller.tapBoardPoint(const BoardPoint(0, 4)); // the red general on the standard board

      final state = container.read(boardEditorControllerProvider);
      expect(state.board.pieceAt(const BoardPoint(0, 4)), isNull);
      expect(controller.checkPlayability(), contains('Red needs'));
    });

    test('selecting a piece deselects the eraser and vice versa', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      controller.selectEraser();
      expect(container.read(boardEditorControllerProvider).eraserSelected, isTrue);

      controller.selectPaletteItem(const Piece(PieceType.horse, Side.red));
      final state = container.read(boardEditorControllerProvider);
      expect(state.eraserSelected, isFalse);
      expect(state.selectedPaletteItem, const Piece(PieceType.horse, Side.red));
    });

    test('loadFen replaces the board and side to move on success', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      controller.loadFen('4k4/9/9/9/9/9/9/9/9/4K4 b - - 0 1');

      final state = container.read(boardEditorControllerProvider);
      expect(state.sideToMove, Side.black);
      expect(state.board.pieceAt(const BoardPoint(9, 4)), const Piece(PieceType.general, Side.black));
      expect(state.board.pieceAt(const BoardPoint(0, 1)), isNull); // standard-position piece is gone
      expect(state.fenError, isNull);
    });

    test('loadFen reports an error and leaves the board untouched on malformed input', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      final before = container.read(boardEditorControllerProvider).board;

      controller.loadFen('not a fen');

      final state = container.read(boardEditorControllerProvider);
      expect(state.fenError, isNotNull);
      expect(state.board, same(before));
    });

    test('setSideToMove updates the side without touching the board', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      final before = container.read(boardEditorControllerProvider).board;
      controller.setSideToMove(Side.black);

      final state = container.read(boardEditorControllerProvider);
      expect(state.sideToMove, Side.black);
      expect(state.board, same(before));
    });

    test('scanPhoto loads the returned position and records confidence for review', () async {
      final fakeAuth = _FakeAuthRepository();
      final fakeVision = _FakeVisionRepository()
        ..responder = (token, bytes, mimeType) {
          expect(token, 'fake-token');
          return const VisionScanResult(fen: '4k4/9/9/9/9/9/9/9/9/4K4 w - - 0 1', confidence: 0.6);
        };
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        visionRepositoryProvider.overrideWithValue(fakeVision),
      ]);
      addTearDown(container.dispose);

      await container.read(boardEditorControllerProvider.notifier).scanPhoto(Uint8List(0), 'image/jpeg');

      final state = container.read(boardEditorControllerProvider);
      expect(state.board.pieceAt(const BoardPoint(0, 4)), const Piece(PieceType.general, Side.red));
      expect(state.board.pieceAt(const BoardPoint(0, 1)), isNull); // standard-position piece is gone
      expect(state.lastScanConfidence, 0.6);
      expect(state.scanError, isNull);
      expect(state.scanning, isFalse);
      expect(fakeAuth.guestLoginCalls, 1);
    });

    test('scanPhoto only logs in as guest once across multiple scans', () async {
      final fakeAuth = _FakeAuthRepository();
      final fakeVision = _FakeVisionRepository();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        visionRepositoryProvider.overrideWithValue(fakeVision),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);

      await controller.scanPhoto(Uint8List(0), 'image/jpeg');
      await controller.scanPhoto(Uint8List(0), 'image/jpeg');

      expect(fakeAuth.guestLoginCalls, 1);
    });

    test('scanPhoto surfaces a scan error and leaves the board untouched', () async {
      final fakeAuth = _FakeAuthRepository();
      final fakeVision = _FakeVisionRepository()..nextError = const VisionScanException('upstream exploded');
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        visionRepositoryProvider.overrideWithValue(fakeVision),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);
      final before = container.read(boardEditorControllerProvider).board;

      await controller.scanPhoto(Uint8List(0), 'image/jpeg');

      final state = container.read(boardEditorControllerProvider);
      expect(state.scanError, contains('upstream exploded'));
      expect(state.scanning, isFalse);
      expect(state.board, same(before));
      expect(state.lastScanConfidence, isNull);
    });

    test('editing the board after a scan clears the confidence hint', () async {
      final fakeAuth = _FakeAuthRepository();
      final fakeVision = _FakeVisionRepository();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        visionRepositoryProvider.overrideWithValue(fakeVision),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(boardEditorControllerProvider.notifier);

      await controller.scanPhoto(Uint8List(0), 'image/jpeg');
      expect(container.read(boardEditorControllerProvider).lastScanConfidence, isNotNull);

      controller.selectEraser();
      controller.tapBoardPoint(const BoardPoint(0, 0));
      expect(container.read(boardEditorControllerProvider).lastScanConfidence, isNull);
    });
  });
}
