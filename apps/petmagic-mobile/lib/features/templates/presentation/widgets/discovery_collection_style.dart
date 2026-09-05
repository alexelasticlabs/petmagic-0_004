import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

/// A collection keeps its accent when the catalog is reordered or filtered.
/// Category is the stable identifier available in the public discovery contract.
int discoveryCollectionIndex(String category) {
  var value = 0;
  for (final rune in category.trim().toLowerCase().runes) {
    value = (value * 31 + rune) % 4;
  }
  return value;
}

class DiscoveryCollectionStyle {
  const DiscoveryCollectionStyle({required this.accent, required this.ink});

  final Color accent;
  final Color ink;

  factory DiscoveryCollectionStyle.of(BuildContext context, String category) {
    final colors = context.petMagicColors;
    final palette = [colors.accent, colors.purple, colors.blue, colors.gold];
    final accent = palette[discoveryCollectionIndex(category)];
    return DiscoveryCollectionStyle(
      accent: accent,
      ink: Theme.of(context).brightness == Brightness.light
          ? Color.lerp(accent, colors.textStrong, 0.48)!
          : Color.lerp(accent, colors.textStrong, 0.2)!,
    );
  }
}

class DiscoveryCollectionMark extends StatelessWidget {
  const DiscoveryCollectionMark({required this.category, super.key});
  final String category;

  @override
  Widget build(BuildContext context) {
    final style = DiscoveryCollectionStyle.of(context, category);
    return ExcludeSemantics(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: style.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: style.accent.withValues(alpha: 0.2)),
        ),
        child: Icon(Icons.auto_awesome_rounded, color: style.ink, size: 16),
      ),
    );
  }
}
