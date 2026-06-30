part of 'template_flow_sheets.dart';

class _TemplateScrollHint extends StatelessWidget {
  const _TemplateScrollHint();

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final hintLabel = text.templateDetailScrollHint;

    return IgnorePointer(
      ignoring: true,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceStrong.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: colors.textSoft,
                ),
                const SizedBox(width: 4),
                Text(
                  hintLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumUnlockCtaButton extends StatefulWidget {
  const _PremiumUnlockCtaButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_PremiumUnlockCtaButton> createState() =>
      _PremiumUnlockCtaButtonState();
}

class _PremiumUnlockCtaButtonState extends State<_PremiumUnlockCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  @override
  void deactivate() {
    _controller.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _syncAnimationState();
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleSmall;
    const ctaTextColor = Color(0xFF251102);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glowAlpha = 0.34 + (_pulse.value * 0.42);
        return Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: widget.onPressed,
              child: Ink(
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFF0A41C),
                      Color(0xFFF3C65A),
                      Color(0xFFF9E18C),
                    ],
                    stops: [0, 0.54, 1],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFF9E8B6).withValues(alpha: 0.88),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE4901F).withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(
                        0xFFF7D67A,
                      ).withValues(alpha: glowAlpha),
                      blurRadius: 22,
                      spreadRadius: 0.6,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0x3DFFF3D2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xAAFFF0C0)),
                        ),
                        child: const PremiumCrownIcon(size: 14),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle?.copyWith(
                            color: ctaTextColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.08,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _syncAnimationState() {
    if (!PerformanceGuard.shouldAnimateRepeatingEffects(context)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return;
    }

    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }
}

class _PremiumTemplateUploadButton extends StatelessWidget {
  const _PremiumTemplateUploadButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleSmall;
    const ctaTextColor = Color(0xFF251102);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFE8AA38),
                  Color(0xFFEFCB72),
                  Color(0xFFF5DE97),
                ],
                stops: [0, 0.58, 1],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFFF9E8B6).withValues(alpha: 0.82),
                width: 1.15,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD8A64B).withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0x3DFFF3D2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xAAFFF0C0)),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: ctaTextColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle?.copyWith(
                        color: ctaTextColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.08,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: colors.accent,
          size: 18,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSoft,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: done ? colors.accent : colors.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: done ? colors.textSoft : colors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    this.icon,
    this.leading,
    required this.label,
    required this.color,
  });

  final IconData? icon;
  final Widget? leading;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null)
              leading!
            else if (icon != null)
              Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.colors,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final PetMagicColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _EmptyMediaBox extends StatelessWidget {
  const _EmptyMediaBox({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.surfaceStrong,
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TemplatePreviewPlaceholder extends StatelessWidget {
  const _TemplatePreviewPlaceholder({
    required this.isVideo,
    required this.title,
    required this.subtitle,
  });

  final bool isVideo;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong.withValues(alpha: 0.96),
            colors.surfaceGlass.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo ? Icons.movie_creation_outlined : Icons.pets_rounded,
                size: 38,
                color: colors.accent,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
