import 'package:flutter/material.dart';

const String _kPremiumCrownAsset = 'assets/rewards/premium-crown.png';

class PremiumCrownIcon extends StatelessWidget {
  const PremiumCrownIcon({super.key, this.size = 16, this.opacity = 1});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0, 1),
      child: Image.asset(
        _kPremiumCrownAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
