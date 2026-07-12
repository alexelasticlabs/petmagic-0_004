import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

class PetMagicPageFrame extends StatelessWidget {
  const PetMagicPageFrame({
    required this.child,
    this.padding,
    this.maxContentWidth = 920,
    this.scrollable = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxContentWidth;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final media = MediaQuery.of(context);
    final horizontal = PetMagicBreakpoints.isTablet(media.size.width)
        ? PetMagicSpacing.xxl
        : PetMagicSpacing.md;
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                horizontal,
                PetMagicSpacing.sm,
                horizontal,
                112 + media.viewPadding.bottom,
              ),
          child: child,
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: scrollable
            ? SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: content,
              )
            : content,
      ),
    );
  }
}

class PetMagicHeroCard extends StatelessWidget {
  const PetMagicHeroCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final compact = PetMagicBreakpoints.isCompact(
      MediaQuery.sizeOf(context).width,
    );

    return Semantics(
      container: true,
      header: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PetMagicRadii.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.purple.withValues(alpha: 0.22),
              colors.accent.withValues(alpha: 0.18),
              colors.surface,
            ],
          ),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: compact ? -52 : -28,
              bottom: -22,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.92,
                  child: Image.asset(
                    imageAsset,
                    width: compact ? 190 : 230,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(PetMagicSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 210 : 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.accent,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: PetMagicSpacing.xs),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: PetMagicSpacing.sm),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PetMagicActionCard extends StatelessWidget {
  const PetMagicActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.accentColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final accent = accentColor ?? colors.accent;
    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      child: ExcludeSemantics(
        child: PressableScale(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(PetMagicRadii.lg),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: PetMagicA11y.minimumTouchTarget,
            ),
            padding: const EdgeInsets.all(PetMagicSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(PetMagicRadii.lg),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(PetMagicRadii.md),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: PetMagicSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: PetMagicSpacing.xxs),
                      Text(
                        subtitle,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.textSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PetMagicSpacing.xs),
                Icon(Icons.arrow_forward_rounded, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PetMagicFlowSteps extends StatelessWidget {
  const PetMagicFlowSteps({required this.labels, super.key});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index == 0 ? colors.accent : colors.surfaceStrong,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: index == 0
                            ? colors.on(colors.accent)
                            : colors.textSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: PetMagicSpacing.xs),
                  Text(
                    labels[index],
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            if (index < labels.length - 1)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: 22,
                  child: Divider(color: colors.border, height: 1),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
