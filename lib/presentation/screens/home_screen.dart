import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'online_lobby_screen.dart';
import 'pass_and_play_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cờ Tướng Master',
                  style: TextStyle(
                    color: XiangqiColors.gold,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PassAndPlayScreen()),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Text('Pass & Play'),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnlineLobbyScreen()),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Text('Play Online'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
