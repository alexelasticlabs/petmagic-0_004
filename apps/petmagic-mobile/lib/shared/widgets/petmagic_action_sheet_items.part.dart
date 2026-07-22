part of 'petmagic_action_sheet.dart';

class PetMagicActionSheetItem extends StatefulWidget {
  const PetMagicActionSheetItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<PetMagicActionSheetItem> createState() =>
      _PetMagicActionSheetItemState();
}

class _PetMagicActionSheetItemState extends State<PetMagicActionSheetItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final enabled = widget.enabled;
    final reduceMotion = PetMotion.reduceMotion(context);
    final duration = PetMotion.effectiveDuration(context, PetMotion.fast);
    final cardBorderRadius = BorderRadius.circular(24);

    final baseFill = colors.surfaceGlass.withValues(
      alpha: enabled ? 0.78 : 0.44,
    );
    final pressedFill = colors.surfaceStrong.withValues(
      alpha: enabled ? 0.92 : 0.44,
    );
    final borderColor = colors.border.withValues(alpha: enabled ? 0.84 : 0.46);
    final chevronColor = colors.textSoft.withValues(
      alpha: enabled ? 0.82 : 0.34,
    );
    final secondaryFill = enabled
        ? (_pressed
              ? colors.surfaceStrong.withValues(alpha: 0.84)
              : colors.surface.withValues(alpha: 0.72))
        : colors.surface.withValues(alpha: 0.36);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed && enabled && !reduceMotion ? 0.978 : 1,
        duration: duration,
        curve: PetMotion.emphasized,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: cardBorderRadius,
            onTap: enabled
                ? () {
                    PetMagicHaptics.light();
                    widget.onTap();
                  }
                : null,
            onHighlightChanged: (value) {
              if (_pressed == value) {
                return;
              }

              setState(() {
                _pressed = value;
              });
            },
            child: AnimatedContainer(
              duration: duration,
              curve: PetMotion.emphasized,
              constraints: const BoxConstraints(minHeight: 96),
              decoration: BoxDecoration(
                borderRadius: cardBorderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [(_pressed ? pressedFill : baseFill), secondaryFill],
                ),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: enabled ? 0.24 : 0.1,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: enabled ? 1 : 0.5,
                      child: PetMagicActionIconContainer(
                        icon: widget.icon,
                        highlighted: _pressed && enabled,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colors.textStrong.withValues(
                                    alpha: enabled ? 1 : 0.5,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.textSoft.withValues(
                                    alpha: enabled ? 1 : 0.5,
                                  ),
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: chevronColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PetMagicActionIconContainer extends StatelessWidget {
  const PetMagicActionIconContainer({
    super.key,
    required this.icon,
    this.highlighted = false,
  });

  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor =
        Color.lerp(colors.accent, colors.gold, 0.18) ?? colors.accent;

    return AnimatedContainer(
      duration: PetMotion.effectiveDuration(context, PetMotion.fast),
      curve: PetMotion.emphasized,
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, highlightColor],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: highlighted ? 0.28 : 0.16),
            blurRadius: highlighted ? 22 : 14,
            spreadRadius: highlighted ? 2 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 30, color: colorScheme.onPrimary),
    );
  }
}
