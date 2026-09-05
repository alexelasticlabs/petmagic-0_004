import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_playback_coordinator.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_media.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

class TemplateDiscoveryRail extends StatelessWidget {
  const TemplateDiscoveryRail({
    required this.section,
    required this.sectionIndex,
    required this.moreLabel,
    required this.onMorePressed,
    required this.onTemplatePressed,
    required this.playbackManager,
    this.previewControllerFactory,
    super.key,
  });

  final TemplateDiscoverySection section;
  final int sectionIndex;
  final String moreLabel;
  final VoidCallback onMorePressed;
  final ValueChanged<TemplateItem> onTemplatePressed;
  final TemplateFeedPlaybackManager playbackManager;
  final TemplatePreviewControllerFactory? previewControllerFactory;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final tileWidth = compact ? 118.0 : 132.0;
    final previewHeight = tileWidth * 1.5;
    final textScaler = MediaQuery.textScalerOf(context);
    final footerHeight = math.max(
      52,
      13 + textScaler.scale(11.5) * 2.1 + textScaler.scale(10) * 1.2,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PetMagicSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      section.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  button: true,
                  label: '$moreLabel: ${section.category}',
                  onTap: onMorePressed,
                  child: ExcludeSemantics(
                    child: TextButton(
                      key: ValueKey('discovery-more-${section.category}'),
                      onPressed: onMorePressed,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(moreLabel),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PetMagicSpacing.xs),
          SizedBox(
            height: previewHeight + footerHeight,
            child: ListView.separated(
              key: ValueKey('discovery-rail-${section.category}'),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: PetMagicSpacing.sm,
              ),
              itemCount: section.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final template = section.items[index];
                return SizedBox(
                  width: tileWidth,
                  child: _DiscoveryTemplateTile(
                    template: template,
                    category: section.category,
                    paletteIndex: sectionIndex + index,
                    previewHeight: previewHeight,
                    playbackManager: playbackManager,
                    previewControllerFactory: previewControllerFactory,
                    onPressed: () => onTemplatePressed(template),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryTemplateTile extends StatelessWidget {
  const _DiscoveryTemplateTile({
    required this.template,
    required this.category,
    required this.paletteIndex,
    required this.previewHeight,
    required this.playbackManager,
    required this.previewControllerFactory,
    required this.onPressed,
  });

  final TemplateItem template;
  final String category;
  final int paletteIndex;
  final double previewHeight;
  final TemplateFeedPlaybackManager playbackManager;
  final TemplatePreviewControllerFactory? previewControllerFactory;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (132 * pixelRatio).clamp(280, 640).round();
    final accessLabel = _templateAccessLabel(text, template);
    final mediaLabel = template.isVideo ? text.videoLabel : text.imageLabel;
    final durationLabel = _templateDurationLabel(template);
    final semanticMediaLabel = durationLabel == null
        ? mediaLabel
        : '$mediaLabel, $durationLabel';

    return Semantics(
      container: true,
      button: true,
      label: '${template.title}, $semanticMediaLabel, $accessLabel',
      onTap: onPressed,
      explicitChildNodes: true,
      child: PetMagicInteractiveSurface(
        onTap: onPressed,
        haptic: PressableScaleHaptic.selection,
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(PetMagicRadii.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: previewHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PetMagicRadii.md),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TemplateDiscoveryMedia(
                      category: category,
                      paletteIndex: paletteIndex,
                      template: template,
                      cacheWidth: cacheWidth,
                      playbackManager: playbackManager,
                      previewControllerFactory: previewControllerFactory,
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.28),
                            ],
                            stops: const [0.62, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      top: 7,
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: _MediaTypeBadge(
                            isVideo: template.isVideo,
                            durationLabel: durationLabel,
                          ),
                        ),
                      ),
                    ),
                    if (template.isPremium)
                      Positioned(
                        right: 7,
                        top: 7,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: _PremiumBadge(label: text.premiumLabel),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            ExcludeSemantics(
              child: Text(
                template.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.textStrong,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 3),
            ExcludeSemantics(child: _TemplateAccessLine(template: template)),
          ],
        ),
      ),
    );
  }
}

class _MediaTypeBadge extends StatelessWidget {
  const _MediaTypeBadge({required this.isVideo, required this.durationLabel});

  final bool isVideo;
  final String? durationLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.56),
          shape: BoxShape.circle,
          border: Border.all(color: colors.gold.withValues(alpha: 0.72)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            Icons.workspace_premium_rounded,
            color: colors.gold,
            size: 13,
          ),
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
    final hasTokenCost = template.tokenCost > 0;
    final label = hasTokenCost
        ? '${template.tokenCost} ${text.walletBalanceUnit}'
        : template.isPremium
        ? text.premiumLabel
        : text.freeLabel;

    return Row(
      children: [
        if (hasTokenCost) ...[
          const PawSparkIcon(size: 13),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: template.isPremium ? colors.gold : colors.textSoft,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
