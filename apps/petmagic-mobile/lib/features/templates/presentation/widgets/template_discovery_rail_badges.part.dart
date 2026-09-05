part of 'template_discovery_rail.dart';

class _MediaTypeBadge extends StatelessWidget {
  const _MediaTypeBadge({required this.isVideo, required this.durationLabel});

  final bool isVideo;
  final String? durationLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(PetMagicRadii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isVideo && durationLabel != null ? 6 : 5,
          vertical: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVideo ? Icons.play_arrow_rounded : Icons.image_outlined,
              color: Colors.white,
              size: 13,
            ),
            if (isVideo && durationLabel != null) ...[
              const SizedBox(width: 3),
              Text(
                durationLabel!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.gold, Color.lerp(colors.gold, Colors.white, 0.35)!],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 14,
              color: Color(0xFF30240F),
            ),
            if (MediaQuery.textScalerOf(context).scale(10) <= 12) ...[
              const SizedBox(width: 3),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF30240F),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TemplateAccessLine extends StatelessWidget {
  const _TemplateAccessLine({required this.template});
  final TemplateItem template;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final hasCost = template.tokenCost > 0;
    if (template.isPremium && !hasCost) return const SizedBox.shrink();
    final accent = template.isPremium ? colors.gold : colors.accent;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final priceInk = template.isPremium ? colors.goldInk : colors.textStrong;
    return Container(
      key: ValueKey('discovery-price-${template.templateId}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isLight ? colors.surface : const Color(0xE610171B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasCost) ...[
            const PawSparkIcon(size: 14),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              hasCost ? '${template.tokenCost}' : text.freeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isLight
                    ? priceInk
                    : (template.isPremium ? colors.gold : Colors.white),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _templateAccessLabel(AppLocalizations text, TemplateItem template) {
  final labels = <String>[
    if (template.isPremium) text.premiumLabel,
    if (template.tokenCost > 0)
      '${template.tokenCost} ${text.walletBalanceUnit}'
    else if (!template.isPremium)
      text.freeLabel,
  ];
  return labels.join(', ');
}

String? _templateDurationLabel(TemplateItem template) {
  if (!template.isVideo) {
    return null;
  }

  final durationMs = template.durationMs;
  final seconds = durationMs != null && durationMs > 0
      ? (durationMs / Duration.millisecondsPerSecond).ceil()
      : template.referenceVideoDurationSeconds?.ceil();
  if (seconds == null || seconds <= 0) {
    return null;
  }

  final minutes = seconds ~/ Duration.secondsPerMinute;
  final remainingSeconds = seconds % Duration.secondsPerMinute;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}
