import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/fen/fen_codec.dart';
import '../../domain/models/game_result.dart';
import '../../domain/models/online_room.dart';
import '../../domain/models/side.dart';
import '../../domain/rules/attack_detector.dart';
import '../providers/online_match_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/xiangqi_board_view.dart';

/// Live multiplayer board: renders whatever `RoomState.fen` the server most
/// recently broadcast (see RULES_ENGINE.md's "Engine Coach" section for the
/// same fen-in/decode-for-rendering pattern - this screen is the second
/// user of it). Move animation between positions isn't implemented for
/// online play in this pass (unlike Pass & Play's slide) - the board just
/// snaps to each new server state, which is an acceptable simplification
/// given moves already round-trip over the network.
class OnlineMatchScreen extends ConsumerWidget {
  const OnlineMatchScreen({super.key});

  String _turnLabel(RoomState room, Side? mySide) {
    if (!room.result.isOngoing) {
      final winner = room.result.winner;
      final reasonLabel = switch (room.result.reason) {
        GameEndReason.checkmate => 'checkmate',
        GameEndReason.noLegalMoves => 'no legal moves',
        GameEndReason.timeout => 'timeout',
        GameEndReason.resignation => 'resignation',
        null => 'unknown reason',
      };
      final winnerLabel = winner == Side.red ? 'Red' : 'Black';
      return '$winnerLabel wins by $reasonLabel';
    }
    if (room.status == RoomStatus.waiting) return 'Waiting for an opponent to join...';
    final sideLabel = room.sideToMove == Side.red ? "Red's turn" : "Black's turn";
    return mySide == room.sideToMove ? '$sideLabel (you)' : sideLabel;
  }

  String _clockLabel(int remainingMs) {
    final totalSeconds = (remainingMs / 1000).ceil().clamp(0, 999999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onlineMatchControllerProvider);
    final controller = ref.read(onlineMatchControllerProvider.notifier);
    final room = state.room;

    return Scaffold(
      appBar: AppBar(
        title: Text(room == null ? 'Online Match' : 'Room ${room.pin}'),
        actions: [
          IconButton(
            tooltip: 'Leave room',
            onPressed: () async {
              await controller.leaveRoom();
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      body: room == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(child: _buildRoom(room, state, controller)),
    );
  }

  Widget _buildRoom(RoomState room, OnlineMatchState state, OnlineMatchController controller) {
    final decoded = FenCodec.decode(room.fen);
    final board = decoded.board;
    final redInCheck = AttackDetector.isGeneralInCheck(board, Side.red);
    final blackInCheck = AttackDetector.isGeneralInCheck(board, Side.black);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;

        final statusBar = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _turnLabel(room, state.mySide),
                  style: const TextStyle(color: XiangqiColors.parchment, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (room.clock != null) ...[
                Text('R ${_clockLabel(room.clock!.redRemainingMs)}', style: const TextStyle(color: XiangqiColors.crimson)),
                const SizedBox(width: 12),
                Text('B ${_clockLabel(room.clock!.blackRemainingMs)}', style: const TextStyle(color: XiangqiColors.parchment)),
              ],
            ],
          ),
        );

        final playersRow = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _PlayerChip(label: room.red.username, connected: room.red.connected, color: XiangqiColors.crimson),
              const SizedBox(width: 12),
              _PlayerChip(
                label: room.black?.username ?? 'waiting...',
                connected: room.black?.connected ?? false,
                color: XiangqiColors.mahogany,
              ),
            ],
          ),
        );

        final boardWidget = Padding(
          padding: const EdgeInsets.all(12),
          child: XiangqiBoardView(
            board: board,
            selected: state.selected,
            legalDestinations: state.legalDestinations,
            redInCheck: redInCheck,
            blackInCheck: blackInCheck,
            lastMove: null,
            moveSerial: room.history.length,
            onTapPoint: controller.selectPoint,
          ),
        );

        final historyPanel = Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: isWide ? double.infinity : 220,
            child: _OnlineMoveHistoryList(history: room.history),
          ),
        );

        if (isWide) {
          return Column(
            children: [
              statusBar,
              playersRow,
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 3, child: boardWidget),
                    Expanded(flex: 1, child: historyPanel),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            statusBar,
            playersRow,
            boardWidget,
            Expanded(child: historyPanel),
          ],
        );
      },
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String label;
  final bool connected;
  final Color color;

  const _PlayerChip({required this.label, required this.connected, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: connected ? XiangqiColors.gold : XiangqiColors.mahogany),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(connected ? Icons.circle : Icons.circle_outlined, size: 8, color: XiangqiColors.gold),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: XiangqiColors.parchment)),
        ],
      ),
    );
  }
}

class _OnlineMoveHistoryList extends StatelessWidget {
  final List<RoomMoveHistoryEntry> history;

  const _OnlineMoveHistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: XiangqiColors.walnut,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: XiangqiColors.gold, width: 1),
      ),
      child: history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No moves yet', style: TextStyle(color: XiangqiColors.parchment)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                final moveNumber = (index ~/ 2) + 1;
                final isRed = index.isEven; // Red moves first and alternates.
                return Container(
                  color: index.isEven ? Colors.black.withValues(alpha: 0.08) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(isRed ? '$moveNumber.' : '', style: const TextStyle(color: XiangqiColors.gold)),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRed ? XiangqiColors.crimson : XiangqiColors.mahogany,
                          border: Border.all(color: XiangqiColors.gold, width: 1),
                        ),
                      ),
                      Text(entry.notation, style: const TextStyle(color: XiangqiColors.parchment)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
