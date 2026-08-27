part of 'template_card.dart';

class _TemplateFeaturedMetaChip extends StatelessWidget {
  const _TemplateFeaturedMetaChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(8, 12, 20, 0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.44)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: textStyle?.copyWith(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBadge extends StatelessWidget {
  const _PromoBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final normalized = value.toLowerCase();
    final tone = switch (normalized) {
      'popular' => colors.purple,
      'trending' => colors.gold,
      'funny' => const Color(0xFFEC4899),
      'new' => const Color(0xFFFF7A1A),
      _ => colors.accent,
    };
    final foreground = colors.on(tone);
    final text = normalized == 'new' ? 'NEW' : value.toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(color: tone.withValues(alpha: 0.2), blurRadius: 10),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HighlightBadge extends StatelessWidget {
  const _HighlightBadge({required this.label, this.isFeatured = false});

  final String label;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final foreground = colors.on(isFeatured ? colors.gold : colors.accent);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isFeatured
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF1BE9A5), Color(0xFFF0D072)],
              )
            : null,
        color: isFeatured
            ? null
            : const Color(0xFF12D784).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color:
                (isFeatured ? const Color(0xFFF0D072) : const Color(0xFF12D784))
                    .withValues(alpha: 0.28),
            blurRadius: isFeatured ? 16 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ConstrainedBox(
        // A featured badge shares the narrow card header with the media type.
        // Without a finite width, Row lays out long localized labels at their
        // intrinsic width and can overflow the 188 px catalogue card.
        constraints: const BoxConstraints(maxWidth: 146),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 11, color: foreground),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaTypeBadge extends StatelessWidget {
  const _MediaTypeBadge({required this.type});

  final TemplateType type;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final label = type == TemplateType.video
        ? text.videoLabel.toUpperCase()
        : text.imageLabel.toUpperCase();
    final icon = type == TemplateType.video
        ? Icons.play_circle_outline_rounded
        : Icons.image_outlined;
    return _MediaKindBadge(icon: icon, label: label);
  }
}

class _MediaKindBadge extends StatelessWidget {
  const _MediaKindBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(8, 11, 18, 0.42),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 3),
            Text(
              label,
              style: textStyle?.copyWith(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({required this.cost});

  final int cost;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(17, 26, 39, 0.62),
            Color.fromRGBO(53, 41, 12, 0.52),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromRGBO(255, 216, 123, 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PawSparkIcon(size: 15),
            const SizedBox(width: 5),
            Text(
              '$cost',
              style: textStyle?.copyWith(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(10, 18, 31, 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromRGBO(125, 211, 252, 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          '#$label',
          style: textStyle?.copyWith(
            color: const Color.fromRGBO(183, 227, 255, 0.94),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _MusicDescription extends StatelessWidget {
  const _MusicDescription({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(
          Icons.music_note_rounded,
          size: 13,
          color: Color.fromRGBO(255, 219, 135, 0.96),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 104),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle?.copyWith(
              color: const Color.fromRGBO(247, 233, 198, 0.92),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: colors.blue, shape: BoxShape.circle),
    );
  }
}

class _AccessTag extends StatelessWidget {
  const _AccessTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final textStyle = Theme.of(context).textTheme.labelSmall;
    final borderColor = colors.gold.withValues(alpha: 0.5);
    const background = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.fromRGBO(133, 77, 14, 0.58),
        Color.fromRGBO(63, 43, 12, 0.38),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 10),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PremiumCrownIcon(size: 11),
            const SizedBox(width: 3),
            Text(
              label,
              style: textStyle?.copyWith(
                color: colors.gold,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.03,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _formatFeaturedCountdown(DateTime? target) {
  if (target == null) {
    return null;
  }

  final remaining = target.toUtc().difference(DateTime.now().toUtc());
  if (remaining <= Duration.zero) {
    return null;
  }

  if (remaining < const Duration(hours: 1)) {
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  final totalHours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '$totalHours:$minutes';
}

String? _formatFeaturedPopularity(
  BuildContext context,
  int? popularityCount, {
  required bool showTodayFallback,
}) {
  final text = AppLocalizations.of(context);
  if (popularityCount == null || popularityCount <= 0) {
    if (!showTodayFallback) {
      return null;
    }

    return text.supportChatTodayLabel;
  }

  final localeTag = Localizations.localeOf(context).toLanguageTag();
  if (popularityCount < 1000) {
    return NumberFormat.decimalPattern(localeTag).format(popularityCount);
  }

  return NumberFormat.compact(locale: localeTag).format(popularityCount);
}
