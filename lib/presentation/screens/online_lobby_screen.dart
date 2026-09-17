import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/online_match_providers.dart';
import '../theme/app_theme.dart';
import 'online_match_screen.dart';

/// Guest sign-in, then create-or-join a room. Deliberately no username
/// search / friend invite here (out of scope for this pass - see
/// docs/ARCHITECTURE.md's Phase 4 note) - PIN sharing is the only way to
/// get a specific opponent into your room.
class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _timeControlController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    _timeControlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onlineMatchControllerProvider);
    final controller = ref.read(onlineMatchControllerProvider.notifier);

    ref.listen(onlineMatchControllerProvider, (previous, next) {
      if (next.room != null && previous?.room != next.room) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnlineMatchScreen()));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Play Online')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: state.session == null ? _buildSignIn(state, controller) : _buildLobby(state, controller),
        ),
      ),
    );
  }

  Widget _buildSignIn(OnlineMatchState state, OnlineMatchController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Choose a display name', style: TextStyle(color: XiangqiColors.parchment, fontSize: 16)),
        const SizedBox(height: 12),
        TextField(controller: _usernameController, decoration: const InputDecoration(hintText: 'e.g. Dan')),
        const SizedBox(height: 16),
        if (state.error != null) _ErrorText(state.error!),
        ElevatedButton(
          onPressed: state.busy ? null : () => controller.continueAsGuest(_usernameController.text.trim()),
          child: state.busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue as guest'),
        ),
      ],
    );
  }

  Widget _buildLobby(OnlineMatchState state, OnlineMatchController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Signed in as ${state.session!.username}', style: const TextStyle(color: XiangqiColors.parchment)),
        const SizedBox(height: 24),
        const Text('Host a room', style: TextStyle(color: XiangqiColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _timeControlController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Minutes per side (blank = untimed)'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: state.busy ? null : () => controller.hostRoom(timeControlMinutes: int.tryParse(_timeControlController.text)),
          child: const Text('Create room'),
        ),
        const SizedBox(height: 32),
        const Text('Join a room', style: TextStyle(color: XiangqiColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _pinController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: '6-character PIN'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: state.busy ? null : () => controller.joinRoomByPin(_pinController.text.trim()),
          child: const Text('Join room'),
        ),
        const SizedBox(height: 16),
        if (state.busy) const Center(child: CircularProgressIndicator()),
        if (state.error != null) _ErrorText(state.error!),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message, style: const TextStyle(color: XiangqiColors.crimson)),
    );
  }
}
