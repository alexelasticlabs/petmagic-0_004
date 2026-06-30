part of 'template_of_the_day_card.dart';

class _TemplateOfTheDayDarkOverlay extends StatelessWidget {
  const _TemplateOfTheDayDarkOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.2),
              Colors.black.withValues(alpha: 0.08),
              Colors.black.withValues(alpha: 0.58),
              Colors.black.withValues(alpha: 0.9),
            ],
            stops: const [0, 0.34, 0.72, 1],
          ),
        ),
      ),
    );
  }
}

class _TemplateOfTheDayTags extends StatelessWidget {
  const _TemplateOfTheDayTags({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              for (var index = 0; index < tags.length; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                _TemplateOfTheDayTag(label: tags[index]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateOfTheDayTag extends StatelessWidget {
  const _TemplateOfTheDayTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          '#$label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _TemplateOfTheDayCostChip extends StatelessWidget {
  const _TemplateOfTheDayCostChip({required this.cost});

  final int cost;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PawSparkIcon(size: 13),
            const SizedBox(width: 5),
            Text(
              '$cost ${text.walletBalanceUnit}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateOfTheDayBadge extends StatelessWidget {
  const _TemplateOfTheDayBadge({
    required this.icon,
    required this.label,
    this.isSubtle = false,
    this.isPremium = false,
  });

  final IconData icon;
  final String label;
  final bool isSubtle;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final background = isPremium
        ? const Color(0xFFEFC35C).withValues(alpha: 0.9)
        : isSubtle
        ? colors.surfaceStrong.withValues(alpha: 0.72)
        : colors.accent.withValues(alpha: 0.9);
    final foreground = isPremium || !isSubtle
        ? const Color(0xFF062316)
        : colors.textStrong;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.48)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateOfTheDayAction extends StatelessWidget {
  const _TemplateOfTheDayAction({required this.label, required this.isPremium});

  final String label;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final textColor = isPremium ? const Color(0xFF251102) : Colors.white;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isPremium ? const Color(0xFFEFC35C) : colors.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward_rounded, size: 13, color: textColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

