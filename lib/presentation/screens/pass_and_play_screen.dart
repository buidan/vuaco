import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/engine_analysis.dart';
import '../../domain/models/game_result.dart';
import '../../domain/models/side.dart';
import '../../domain/notation/move_notation.dart';
import '../providers/engine_coach_providers.dart';
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

  /// "+0.32" / "-1.10" for a centipawn score, "Mate in N" / "Mated in N" for
  /// a forced mate - always from the perspective of whoever is to move in
  /// the analyzed position.
  String _evalLabel(EngineAnalysisLine line) {
    if (line.scoreType == EngineScoreType.mate) {
      return line.scoreValue > 0 ? 'Mate in ${line.scoreValue}' : 'Mated in ${line.scoreValue.abs()}';
    }
    final pawns = line.scoreValue / 100;
    final sign = pawns > 0 ? '+' : '';
    return '$sign${pawns.toStringAsFixed(2)}';
  }

  List<CandidateMoveArrow> _candidateArrows(GameControllerState gameState, EngineCoachState coachState) {
    if (!coachState.enabled) return const [];
    if (coachState.analyzedSide != gameState.sideToMove) return const []; // stale: still analyzing the new position
    final analysis = coachState.analysis;
    if (analysis == null) return const [];

    final arrows = <CandidateMoveArrow>[];
    for (final line in analysis.lines) {
      if (line.pvMoves.isEmpty) continue;
      final (from, to) = MoveNotation.parseUciMove(line.pvMoves.first);
      arrows.add(CandidateMoveArrow(from: from, to: to, rank: line.multiPv));
    }
    return arrows;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final coachState = ref.watch(engineCoachControllerProvider);
    final coachController = ref.read(engineCoachControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cờ Tướng - Pass & Play'),
        actions: [
          IconButton(
            tooltip: coachState.enabled ? 'Turn off Engine Coach' : 'Turn on Engine Coach',
            onPressed: coachController.toggle,
            icon: Icon(
              Icons.psychology,
              color: coachState.enabled ? XiangqiColors.gold : null,
            ),
          ),
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
                candidateMoves: _candidateArrows(state, coachState),
              ),
            );

            final statusBar = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    _turnLabel(state),
                    style: const TextStyle(
                      color: XiangqiColors.parchment,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ..._coachStatusWidgets(coachState),
                ],
              ),
            );

            final blunderBanner = coachState.blunderEvent == null
                ? const SizedBox.shrink()
                : _BlunderBanner(event: coachState.blunderEvent!);

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
                  blunderBanner,
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
                blunderBanner,
                board,
                Expanded(child: historyPanel),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _coachStatusWidgets(EngineCoachState coachState) {
    if (!coachState.enabled) return const [];
    if (coachState.error != null) {
      return const [
        Icon(Icons.cloud_off, color: XiangqiColors.crimson, size: 18),
        SizedBox(width: 4),
        Text('Coach unavailable', style: TextStyle(color: XiangqiColors.crimson, fontSize: 13)),
      ];
    }
    if (coachState.loading && coachState.analysis == null) {
      return const [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: XiangqiColors.gold),
        ),
      ];
    }
    final topLine = coachState.analysis?.lines.firstOrNull;
    if (topLine == null) return const [];
    return [
      if (coachState.loading)
        const Padding(
          padding: EdgeInsets.only(right: 6),
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: XiangqiColors.gold),
          ),
        ),
      Text(
        'Coach: ${_evalLabel(topLine)}',
        style: const TextStyle(color: XiangqiColors.gold, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ];
  }
}

class _BlunderBanner extends StatelessWidget {
  final BlunderEvent event;

  const _BlunderBanner({required this.event});

  @override
  Widget build(BuildContext context) {
    final sideLabel = event.side == Side.red ? 'Red' : 'Black';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: XiangqiColors.crimson.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: XiangqiColors.gold),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: XiangqiColors.parchment, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$sideLabel blundered - dropped about ${(event.dropCentipawns / 100).toStringAsFixed(2)} pawns of evaluation.',
              style: const TextStyle(color: XiangqiColors.parchment, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
