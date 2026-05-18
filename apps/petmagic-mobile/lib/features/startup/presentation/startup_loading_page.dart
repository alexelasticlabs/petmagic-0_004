import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';

class StartupLoadingPage extends StatelessWidget {
  const StartupLoadingPage({super.key});

  static const routePath = '/startup';

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: const SafeArea(child: MagicLoadingScreen()),
      ),
    );
  }
}