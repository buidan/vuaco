import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/screens/pass_and_play_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: VuacoApp()));
}

class VuacoApp extends StatelessWidget {
  const VuacoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cờ Tướng Master',
      theme: buildAppTheme(),
      home: const PassAndPlayScreen(),
    );
  }
}
