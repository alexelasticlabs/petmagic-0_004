import 'package:flutter/material.dart';

class PawSparkIcon extends StatelessWidget {
  const PawSparkIcon({super.key, this.size = 24, this.showGlow = false});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7BF287), Color(0xFF19B963)],
        ),
        border: Border.all(
          color: const Color(0xFFB6FF9F).withValues(alpha: 0.58),
          width: size * 0.08,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: const Color(0xFF2BE66C).withValues(alpha: 0.35),
                  blurRadius: size * 0.52,
                  offset: Offset(0, size * 0.14),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          Icons.pets_rounded,
          size: size * 0.58,
          color: const Color(0xFF05351F),
        ),
      ),
    );
  }
}
