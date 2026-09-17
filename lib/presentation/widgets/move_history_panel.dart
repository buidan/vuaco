import 'package:flutter/material.dart';

import '../../domain/models/move_history_entry.dart';
import '../../domain/models/side.dart';
import '../theme/app_theme.dart';

class MoveHistoryPanel extends StatelessWidget {
  final List<MoveHistoryEntry> history;

  const MoveHistoryPanel({super.key, required this.history});

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
                final isRed = entry.move.movedPiece.side == Side.red;
                return Container(
                  color: index.isEven ? Colors.black.withValues(alpha: 0.08) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          isRed ? '$moveNumber.' : '',
                          style: const TextStyle(color: XiangqiColors.gold),
                        ),
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
