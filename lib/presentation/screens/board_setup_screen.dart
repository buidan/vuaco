import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/side.dart';
import '../providers/board_editor_providers.dart';
import '../providers/game_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/board_editor_view.dart';
import '../widgets/piece_palette.dart';
import 'pass_and_play_screen.dart';

/// Phase 5's board-import flow: paste a FEN and/or hand-edit the position
/// with a piece palette, then start a Pass & Play game from it. Camera/
/// Cloud Vision board scanning is deliberately not part of this pass - see
/// docs/ARCHITECTURE.md's Phase 5 entry and RULES_ENGINE.md.
class BoardSetupScreen extends ConsumerStatefulWidget {
  const BoardSetupScreen({super.key});

  @override
  ConsumerState<BoardSetupScreen> createState() => _BoardSetupScreenState();
}

class _BoardSetupScreenState extends ConsumerState<BoardSetupScreen> {
  final _fenController = TextEditingController();

  @override
  void dispose() {
    _fenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(boardEditorControllerProvider);
    final controller = ref.read(boardEditorControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Position')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 720;

            final fenRow = Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fenController,
                          decoration: const InputDecoration(hintText: 'Paste a FEN string'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => controller.loadFen(_fenController.text.trim()),
                        child: const Text('Load'),
                      ),
                    ],
                  ),
                  if (state.fenError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(state.fenError!, style: const TextStyle(color: XiangqiColors.crimson)),
                    ),
                ],
              ),
            );

            final quickActions = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(onPressed: controller.resetToStandard, child: const Text('Standard position')),
                  OutlinedButton(onPressed: controller.clearBoard, child: const Text('Clear board')),
                ],
              ),
            );

            final sideToggle = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text('Side to move: ', style: TextStyle(color: XiangqiColors.parchment)),
                  ChoiceChip(
                    label: const Text('Red'),
                    selected: state.sideToMove == Side.red,
                    onSelected: (_) => controller.setSideToMove(Side.red),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Black'),
                    selected: state.sideToMove == Side.black,
                    onSelected: (_) => controller.setSideToMove(Side.black),
                  ),
                ],
              ),
            );

            final board = Padding(
              padding: const EdgeInsets.all(12),
              child: BoardEditorView(board: state.board, onTapPoint: controller.tapBoardPoint),
            );

            final palette = Padding(
              padding: const EdgeInsets.all(12),
              child: PiecePalette(
                selectedPiece: state.selectedPaletteItem,
                eraserSelected: state.eraserSelected,
                onSelectPiece: controller.selectPaletteItem,
                onSelectEraser: controller.selectEraser,
              ),
            );

            final playButton = Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () => _tryPlay(context),
                child: const Text('Play from this position'),
              ),
            );

            final content = [fenRow, quickActions, sideToggle];

            if (isWide) {
              return Column(
                children: [
                  ...content,
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: board),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: Column(children: [palette, playButton]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [...content, board, palette, playButton],
              ),
            );
          },
        ),
      ),
    );
  }

  void _tryPlay(BuildContext context) {
    final controller = ref.read(boardEditorControllerProvider.notifier);
    final error = controller.checkPlayability();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final state = ref.read(boardEditorControllerProvider);
    ref.read(gameControllerProvider.notifier).startFromPosition(state.board, state.sideToMove);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PassAndPlayScreen()));
  }
}
