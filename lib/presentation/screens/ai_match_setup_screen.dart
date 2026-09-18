import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/ai_difficulty.dart';
import '../../domain/models/side.dart';
import '../providers/ai_opponent_providers.dart';
import '../theme/app_theme.dart';
import 'ai_match_screen.dart';

/// Pick a side and a difficulty, then start a game against the backend's
/// Pikafish (the same engine the Engine Coach uses for suggestions, here
/// actually playing a side instead of just advising).
class AiMatchSetupScreen extends ConsumerStatefulWidget {
  const AiMatchSetupScreen({super.key});

  @override
  ConsumerState<AiMatchSetupScreen> createState() => _AiMatchSetupScreenState();
}

class _AiMatchSetupScreenState extends ConsumerState<AiMatchSetupScreen> {
  Side _humanSide = Side.red;
  AiDifficulty _difficulty = AiDifficulty.medium;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play vs Computer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Play as', style: TextStyle(color: XiangqiColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Red (moves first)'),
                      selected: _humanSide == Side.red,
                      onSelected: (_) => setState(() => _humanSide = Side.red),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Black'),
                      selected: _humanSide == Side.black,
                      onSelected: (_) => setState(() => _humanSide = Side.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Difficulty', style: TextStyle(color: XiangqiColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  for (final difficulty in AiDifficulty.values)
                    ChoiceChip(
                      label: Text(difficulty.label),
                      selected: _difficulty == difficulty,
                      onSelected: (_) => setState(() => _difficulty = difficulty),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ref.read(aiMatchControllerProvider.notifier).startGame(
                        humanSide: _humanSide,
                        difficulty: _difficulty,
                      );
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiMatchScreen()));
                },
                child: const Text('Start game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
