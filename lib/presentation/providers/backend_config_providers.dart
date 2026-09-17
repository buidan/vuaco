import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Points every backend-talking feature (Engine Coach, online multiplayer)
/// at the Phase 2/4 backend. No settings UI exists yet to change this at
/// runtime (see docs/ARCHITECTURE.md) - override these in tests, or here
/// for a non-default deployment.
final backendRestBaseUrlProvider = Provider<String>((ref) => 'http://localhost:3000/api/v1');

/// Socket.io connects to the server root, not the REST `/api/v1` path.
final backendSocketUrlProvider = Provider<String>((ref) => 'http://localhost:3000');
