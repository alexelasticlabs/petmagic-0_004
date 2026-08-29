part of 'template_card.dart';

class _TemplateShadeOverlay extends StatelessWidget {
  const _TemplateShadeOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.08),
              Colors.black.withValues(alpha: 0.32),
              Colors.black.withValues(alpha: 0.68),
              Colors.black.withValues(alpha: 0.94),
            ],
            stops: const [0, 0.34, 0.56, 0.8, 1],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TemplateHeaderBadges extends StatelessWidget {
  const _TemplateHeaderBadges({
    required this.type,
    this.highlightBadgeLabel,
    this.promoBadgeValue,
    this.isFeatured = false,
  });

  final TemplateType type;
  final String? highlightBadgeLabel;
  final String? promoBadgeValue;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    final trimmedPromo = promoBadgeValue?.trim();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (highlightBadgeLabel != null && highlightBadgeLabel!.isNotEmpty)
          _HighlightBadge(label: highlightBadgeLabel!, isFeatured: isFeatured),
        if (trimmedPromo != null && trimmedPromo.isNotEmpty)
          _PromoBadge(value: trimmedPromo),
        _MediaTypeBadge(type: type),
      ],
    );
  }
}

class _TemplateDetails extends StatelessWidget {
  const _TemplateDetails({
    required this.template,
    required this.hasPremiumAccess,
    required this.showGuestPreview,
    this.featuredData,
    required this.onPressed,
  });

  final TemplateItem template;
  final bool hasPremiumAccess;
  final bool showGuestPreview;
  final TemplateCardFeaturedData? featuredData;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final metaStyle = Theme.of(context).textTheme.labelMedium;
    final tags = template.tags.take(2).toList(growable: false);
    final isPremiumLocked = template.isPremium && !hasPremiumAccess;
    final isFeatured = featuredData != null;
    final actionLabel = isPremiumLocked
        ? text.templateUnlockPremiumAction
        : text.templateTryAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          template.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle?.copyWith(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.08,
            letterSpacing: -0.12,
            shadows: [
              const Shadow(
                color: Color.fromRGBO(3, 7, 15, 0.62),
                blurRadius: 20,
                offset: Offset(0, 7),
              ),
            ],
          ),
        ),
        if (template.shortDescription.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            template.shortDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 10.5,
              height: 1.16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 21,
            child: ClipRect(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    for (var index = 0; index < tags.length; index++) ...[
                      if (index > 0) const SizedBox(width: 6),
                      _TagChip(label: tags[index]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (template.isVideo) ...[
              Text(
                formatDuration(template.referenceVideoDurationSeconds),
                style: metaStyle?.copyWith(
                  color: Color.fromRGBO(228, 238, 251, 0.9),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const _MetaDot(),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 78),
              child: Text(
                template.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metaStyle?.copyWith(
                  color: const Color.fromRGBO(228, 238, 251, 0.9),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (template.isPremium) _AccessTag(label: text.premiumLabel),
            _TokenChip(cost: template.tokenCost),
          ],
        ),
        if (showGuestPreview) ...[
          const SizedBox(height: 4),
          _TemplateStatusChip(label: text.templateGuestPreview),
        ],
        const SizedBox(height: 8),
        TemplateCardCta(
          label: actionLabel,
          isPremiumLockCta: isPremiumLocked,
          isPremiumTemplateCta: template.isPremium || isFeatured,
          onPressed: onPressed,
        ),
      ],
    );
  }
}

class TemplateCardCta extends StatelessWidget {
  const TemplateCardCta({
    required this.label,
    required this.onPressed,
    this.isPremiumLockCta = false,
    this.isPremiumTemplateCta = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPremiumLockCta;
  final bool isPremiumTemplateCta;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    final colors = context.petMagicColors;
    final usePremiumStyle = isPremiumLockCta || isPremiumTemplateCta;
    final foregroundColor = usePremiumStyle
        ? colors.on(
            isPremiumLockCta
                ? const Color(0xFFF3C65A)
                : const Color(0xFFEFCB72),
          )
        : colors.on(colors.accent);
    return PetMagicInteractiveSurface(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      scaleDown: 0.975,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isPremiumLockCta
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFF0A41C),
                    Color(0xFFF3C65A),
                    Color(0xFFF9E18C),
                  ],
                  stops: [0, 0.54, 1],
                )
              : isPremiumTemplateCta
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFE8AA38),
                    Color(0xFFEFCB72),
                    Color(0xFFF5DE97),
                  ],
                  stops: [0, 0.58, 1],
                )
              : const LinearGradient(
                  colors: [Color(0xFF168A62), Color(0xFF15956A)],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: usePremiumStyle
                ? const Color(0xFFF9E8B6).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.14),
            width: usePremiumStyle ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints.tightFor(height: 52),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textStyle?.copyWith(
                    color: foregroundColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
              ),
              Positioned(
                right: 14,
                child: Container(
                  width: usePremiumStyle ? 22 : null,
                  height: usePremiumStyle ? 22 : null,
                  decoration: usePremiumStyle
                      ? BoxDecoration(
                          color: const Color(0x3DFFF3D2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xAAFFF0C0)),
                        )
                      : null,
                  child: isPremiumLockCta
                      ? const PremiumCrownIcon(size: 13.5)
                      : Icon(
                          Icons.arrow_forward_rounded,
                          color: foregroundColor,
                          size: usePremiumStyle ? 13.5 : 16,
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

class _TemplateStatusChip extends StatelessWidget {
  const _TemplateStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.accent.withValues(alpha: 0.18),
            colors.gold.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
