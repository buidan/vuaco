import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/game_result.dart';
import '../../domain/models/side.dart';
import '../providers/game_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/move_history_panel.dart';
import '../widgets/xiangqi_board_view.dart';

class PassAndPlayScreen extends ConsumerWidget {
  const PassAndPlayScreen({super.key});

  String _turnLabel(GameControllerState state) {
    if (!state.result.isOngoing) {
      final winner = state.result.winner;
      final reason = state.result.reason == GameEndReason.checkmate ? 'checkmate' : 'no legal moves';
      final winnerLabel = winner == Side.red ? 'Red' : 'Black';
      return '$winnerLabel wins by $reason';
    }
    final sideLabel = state.sideToMove == Side.red ? "Red's turn" : "Black's turn";
    final inCheck = state.sideToMove == Side.red ? state.redInCheck : state.blackInCheck;
    return inCheck ? '$sideLabel - Check!' : sideLabel;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cờ Tướng - Pass & Play'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: state.history.isEmpty ? null : controller.undo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'New game',
            onPressed: controller.newGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 720;
            final board = Padding(
              padding: const EdgeInsets.all(12),
              child: XiangqiBoardView(
                board: state.board,
                selected: state.selected,
                legalDestinations: state.legalDestinations,
                redInCheck: state.redInCheck,
                blackInCheck: state.blackInCheck,
                lastMove: state.lastMove,
                moveSerial: state.history.length,
                onTapPoint: controller.tapPoint,
              ),
            );

            final statusBar = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _turnLabel(state),
                style: const TextStyle(
                  color: XiangqiColors.parchment,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );

            final historyPanel = Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: isWide ? double.infinity : 220,
                child: MoveHistoryPanel(history: state.history),
              ),
            );

            if (isWide) {
              return Column(
                children: [
                  statusBar,
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: board),
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
                board,
                Expanded(child: historyPanel),
              ],
            );
          },
        ),
      ),
    );
  }
}
