import 'package:flutter/material.dart';

/// Keeps filter chips horizontally scrollable without changing their alignment.
class HorizontalFilterStrip extends StatelessWidget {
  const HorizontalFilterStrip({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: child,
    );
  }
}
