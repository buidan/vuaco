import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/ai_difficulty.dart';
import '../../domain/models/game_result.dart';
import '../../domain/models/side.dart';
import '../providers/ai_opponent_providers.dart';
import '../providers/game_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/move_history_panel.dart';
import '../widgets/xiangqi_board_view.dart';

class AiMatchScreen extends ConsumerWidget {
  const AiMatchScreen({super.key});

  String _turnLabel(GameControllerState gameState, AiMatchState aiState) {
    final humanSide = aiState.humanSide;
    if (!gameState.result.isOngoing) {
      final winner = gameState.result.winner;
      final reason = gameState.result.reason == GameEndReason.checkmate ? 'checkmate' : 'no legal moves';
      final winnerLabel = winner == Side.red ? 'Red' : 'Black';
      final youWon = winner == humanSide;
      return '$winnerLabel wins by $reason${humanSide == null ? '' : (youWon ? ' - you win!' : ' - computer wins')}';
    }
    if (aiState.aiThinking) return 'Computer is thinking...';
    final sideLabel = gameState.sideToMove == Side.red ? "Red's turn" : "Black's turn";
    return gameState.sideToMove == humanSide ? '$sideLabel (you)' : sideLabel;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(aiMatchGameControllerProvider);
    final gameController = ref.read(aiMatchGameControllerProvider.notifier);
    final aiState = ref.watch(aiMatchControllerProvider);
    final aiController = ref.read(aiMatchControllerProvider.notifier);

    final humanTurn = gameState.result.isOngoing && gameState.sideToMove == aiState.humanSide && !aiState.aiThinking;

    return Scaffold(
      appBar: AppBar(
        title: Text('vs Computer (${aiState.difficulty.label})'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: gameState.history.isEmpty ? null : aiController.undoHumanMove,
            icon: const Icon(Icons.undo),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 720;

            final statusBar = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _turnLabel(gameState, aiState),
                      style: const TextStyle(color: XiangqiColors.parchment, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (aiState.aiThinking)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: XiangqiColors.gold),
                    ),
                ],
              ),
            );

            final errorBanner = aiState.aiError != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Computer could not move: ${aiState.aiError}', style: const TextStyle(color: XiangqiColors.crimson)),
                  )
                : const SizedBox.shrink();

            final board = Padding(
              padding: const EdgeInsets.all(12),
              child: XiangqiBoardView(
                board: gameState.board,
                selected: gameState.selected,
                legalDestinations: gameState.legalDestinations,
                redInCheck: gameState.redInCheck,
                blackInCheck: gameState.blackInCheck,
                lastMove: gameState.lastMove,
                moveSerial: gameState.history.length,
                onTapPoint: humanTurn ? gameController.tapPoint : (_) {},
              ),
            );

            final historyPanel = Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: isWide ? double.infinity : 220,
                child: MoveHistoryPanel(history: gameState.history),
              ),
            );

            if (isWide) {
              return Column(
                children: [
                  statusBar,
                  errorBanner,
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
                errorBanner,
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
