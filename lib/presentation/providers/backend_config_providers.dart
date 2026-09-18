import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Android emulator's own `localhost` is itself, not the host machine
/// running the backend - `10.0.2.2` is the emulator's alias back to the
/// host. Every other target (iOS Simulator, desktop, a real device on the
/// same machine as the backend) reaches the host fine via plain
/// `localhost`. This is just a sensible default for local development -
/// a physical device on a different machine, or a non-default emulator
/// setup, still needs the override described below.
String get _backendHost => (!kIsWeb && Platform.isAndroid) ? '10.0.2.2' : 'localhost';

/// Points every backend-talking feature (Engine Coach, online multiplayer,
/// Cloud Vision board scan) at the Phase 2/4/5 backend. No settings UI
/// exists yet to change this at runtime (see docs/ARCHITECTURE.md) -
/// override these in tests, or here for a non-default deployment (a
/// physical device on another machine needs your host's LAN IP instead -
/// see SETUP.md).
final backendRestBaseUrlProvider = Provider<String>((ref) => 'http://$_backendHost:3000/api/v1');

/// Socket.io connects to the server root, not the REST `/api/v1` path.
final backendSocketUrlProvider = Provider<String>((ref) => 'http://$_backendHost:3000');
