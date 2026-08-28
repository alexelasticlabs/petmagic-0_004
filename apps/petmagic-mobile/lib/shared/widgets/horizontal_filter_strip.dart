import 'package:flutter/material.dart';

/// Keeps horizontally scrollable filters from ending in abruptly clipped chips.
class HorizontalFilterStrip extends StatelessWidget {
  const HorizontalFilterStrip({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0, 0.035, 0.965, 1],
      ).createShader(bounds),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        clipBehavior: Clip.none,
        child: child,
      ),
    );
  }
}
