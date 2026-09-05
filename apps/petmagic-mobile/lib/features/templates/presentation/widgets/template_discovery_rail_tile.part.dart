part of 'template_discovery_rail.dart';

class _DiscoveryTemplateTile extends StatelessWidget {
  const _DiscoveryTemplateTile({
    required this.template,
    required this.category,
    required this.paletteIndex,
    required this.previewHeight,
    required this.titleStyle,
    required this.playbackManager,
    required this.previewControllerFactory,
    required this.onPressed,
  });

  final TemplateItem template;
  final String category;
  final int paletteIndex;
  final double previewHeight;
  final TextStyle titleStyle;
  final TemplateFeedPlaybackManager playbackManager;
  final TemplatePreviewControllerFactory? previewControllerFactory;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final collection = DiscoveryCollectionStyle.of(context, category);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (148 * pixelRatio).clamp(280, 640).round();
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
              child: Container(
                key: ValueKey('discovery-frame-${template.templateId}'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PetMagicRadii.md),
                  boxShadow: template.isPremium
                      ? [
                          BoxShadow(
                            color: colors.gold.withValues(alpha: 0.14),
                            blurRadius: 14,
                            spreadRadius: -3,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : const [],
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PetMagicRadii.md),
                  border: Border.all(
                    color: template.isPremium
                        ? colors.gold.withValues(alpha: 0.85)
                        : collection.accent.withValues(alpha: 0.3),
                    width: template.isPremium ? 1.5 : 0.7,
                  ),
                ),
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
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: _TemplateAccessLine(template: template),
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
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Tooltip(
                message: template.title,
                excludeFromSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    template.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
