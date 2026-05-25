import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';

class TemplatesSkeleton extends StatelessWidget {
  const TemplatesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset),
      sliver: SliverGrid.builder(
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.66,
        ),
        itemBuilder: (context, index) => _SkeletonCard(colors: colors),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.colors});

  final PetMagicColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _SkeletonBlock(colors: colors, radius: 14),
            ),
            const SizedBox(height: 12),
            _SkeletonLine(colors: colors, widthFactor: 0.78),
            const SizedBox(height: 8),
            _SkeletonLine(colors: colors, widthFactor: 0.96),
            const SizedBox(height: 8),
            _SkeletonLine(colors: colors, widthFactor: 0.58),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.colors, this.radius = 8});

  final PetMagicColors colors;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: colors.border.withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.colors, required this.widthFactor});

  final PetMagicColors colors;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 12,
        child: _SkeletonBlock(colors: colors, radius: 8),
      ),
    );
  }
}
