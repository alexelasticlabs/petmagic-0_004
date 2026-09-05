part of 'template_flow_sheets.dart';

class TemplateMediaFrame extends StatelessWidget {
  const TemplateMediaFrame({
    required this.template,
    this.expand = false,
    this.isActive = true,
    this.prepareOffscreen = false,
    this.playWhenActive = false,
    this.allowDetailUpgrade = true,
    this.playbackRegistry,
    this.autoplay = true,
    this.immersive = false,
    this.preferLowResolution = true,
    this.muted = true,
    this.onMutedChanged,
    this.controllerFactory,
    super.key,
  });

  final TemplateItem template;
  final bool expand;
  final bool isActive;
  final bool prepareOffscreen;

  /// The pager already knows the visible selection; bypass detector batching.
  final bool playWhenActive;
  final bool allowDetailUpgrade;
  final TemplatePreviewPlaybackRegistry? playbackRegistry;
  final bool autoplay;
  final bool immersive;
  final bool preferLowResolution;
  final bool muted;
  final ValueChanged<bool>? onMutedChanged;
  final Future<VideoPlayerController> Function(String)? controllerFactory;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final selection = TemplatePreviewMediaSelection(
      template,
      expand: expand,
      preferLowResolution: preferLowResolution,
    );
    final safeThumbnailUrl = selection.thumbnailUrl;
    final ratio = template.isVideo ? 9 / 16 : 3 / 4;
    final mediaFit = expand && !immersive ? BoxFit.contain : BoxFit.cover;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth = _templatePreviewCacheDimension(
          constraints.maxWidth,
          MediaQuery.devicePixelRatioOf(context),
        );
        final preferredMediaUrl = selection.mediaUrl;
        final preferredMediaIsVideo = selection.isVideo;
        final imageUrl = selection.imageUrl;

        Widget media;
        if (preferredMediaUrl == null && imageUrl == null) {
          media = _TemplatePreviewPlaceholder(
            isVideo: template.isVideo,
            title: _templatePreviewMissingTitle(text),
            subtitle: _templatePreviewMissingSubtitle(
              text,
              isVideo: template.isVideo,
            ),
          );
        } else if (preferredMediaIsVideo && preferredMediaUrl != null) {
          media = _NetworkVideoPreview(
            url: preferredMediaUrl,
            fallbackUrls: selection.videoFallbackUrls,
            playbackIdentity: template.templateId,
            posterUrl: imageUrl,
            posterCacheWidth: cacheWidth,
            mediaVersion: template.mediaVersion,
            isActive: isActive,
            autoplay: autoplay,
            muted: muted,
            onMutedChanged: onMutedChanged,
            immersiveControls: immersive,
            prepareWhileVisible: immersive,
            prepareOffscreen: prepareOffscreen,
            playWhenActive: playWhenActive,
            allowDetailUpgrade: allowDetailUpgrade,
            playbackRegistry: playbackRegistry,
            controllerFactory: controllerFactory,
            useSharedPreviewCache: true,
            fit: mediaFit,
            showPlaybackControl: true,
            playbackControlAlignment: expand
                ? Alignment.centerRight
                : Alignment.bottomRight,
          );
        } else if (imageUrl != null) {
          final usesDetailCache = selection.usesDetailImageCache;
          final sharpFallbackUrl =
              expand &&
                  safeThumbnailUrl != null &&
                  safeThumbnailUrl != imageUrl &&
                  !isVideoUrl(safeThumbnailUrl)
              ? safeThumbnailUrl
              : null;
          final expandedForegroundFallback = sharpFallbackUrl == null
              ? KeyedSubtree(
                  key: const ValueKey(
                    'template-preview-foreground-placeholder',
                  ),
                  child: _TemplatePreviewPlaceholder(
                    isVideo: template.isVideo,
                    title: _templatePreviewMissingTitle(text),
                    subtitle: _templatePreviewMissingSubtitle(
                      text,
                      isVideo: template.isVideo,
                    ),
                  ),
                )
              : TemplatePreviewImage(
                  key: const ValueKey('template-preview-foreground-fallback'),
                  imageUrl: sharpFallbackUrl,
                  fit: mediaFit,
                  alignment: Alignment.center,
                  cacheWidth: cacheWidth,
                  mediaVersion: template.mediaVersion,
                  preserveOldImageOnUrlChange: true,
                  placeholder: const SizedBox.shrink(),
                  errorBuilder: (_) => _TemplatePreviewPlaceholder(
                    isVideo: template.isVideo,
                    title: _templatePreviewMissingTitle(text),
                    subtitle: _templatePreviewMissingSubtitle(
                      text,
                      isVideo: template.isVideo,
                    ),
                  ),
                );
          final foreground = TemplatePreviewImage(
            imageUrl: imageUrl,
            fit: mediaFit,
            alignment: Alignment.center,
            cacheWidth: cacheWidth,
            mediaVersion: template.mediaVersion,
            preserveOldImageOnUrlChange: expand,
            fileLoader: usesDetailCache
                ? TemplateMediaCache.fetchPreviewFile
                : null,
            fileRemover: usesDetailCache
                ? TemplateMediaCache.removePreviewFile
                : null,
            placeholder: expand
                ? const SizedBox.shrink()
                : _EmptyMediaBox(label: text.templateFlowLoadingPreview),
            errorBuilder: expand
                ? (_) => expandedForegroundFallback
                : (_) => _TemplatePreviewPlaceholder(
                    isVideo: template.isVideo,
                    title: _templatePreviewMissingTitle(text),
                    subtitle: _templatePreviewMissingSubtitle(
                      text,
                      isVideo: template.isVideo,
                    ),
                  ),
          );
          if (!expand || immersive) {
            media = foreground;
          } else {
            final backdropUrl = safeThumbnailUrl ?? imageUrl;
            final backdropUsesDetailCache =
                usesDetailCache && backdropUrl == imageUrl;
            final backdropCacheWidth = (cacheWidth * 0.55)
                .round()
                .clamp(320, 800)
                .toInt();
            media = Stack(
              fit: StackFit.expand,
              children: [
                _TemplatePreviewBlurredBackdrop(
                  child: TemplatePreviewImage(
                    imageUrl: backdropUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    cacheWidth: backdropCacheWidth,
                    filterQuality: FilterQuality.low,
                    mediaVersion: template.mediaVersion,
                    preserveOldImageOnUrlChange: true,
                    fileLoader: backdropUsesDetailCache
                        ? TemplateMediaCache.fetchPreviewFile
                        : null,
                    fileRemover: backdropUsesDetailCache
                        ? TemplateMediaCache.removePreviewFile
                        : null,
                    placeholder: _EmptyMediaBox(
                      label: text.templateFlowLoadingPreview,
                    ),
                    errorBuilder: (_) => _TemplatePreviewPlaceholder(
                      isVideo: template.isVideo,
                      title: _templatePreviewMissingTitle(text),
                      subtitle: _templatePreviewMissingSubtitle(
                        text,
                        isVideo: template.isVideo,
                      ),
                    ),
                  ),
                ),
                ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
                foreground,
              ],
            );
          }
        } else {
          media = _TemplatePreviewPlaceholder(
            isVideo: template.isVideo,
            title: _templatePreviewMissingTitle(text),
            subtitle: _templatePreviewMissingSubtitle(
              text,
              isVideo: template.isVideo,
            ),
          );
        }

        final clippedMedia = ClipRRect(
          borderRadius: BorderRadius.circular(expand ? 0 : 22),
          child: media,
        );
        if (expand) {
          return SizedBox.expand(child: clippedMedia);
        }

        return AspectRatio(aspectRatio: ratio, child: clippedMedia);
      },
    );
  }
}

class _TemplatePreviewBlurredBackdrop extends StatelessWidget {
  const _TemplatePreviewBlurredBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRect(
        child: Transform.scale(
          scale: 1.06,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: child,
          ),
        ),
      ),
    );
  }
}

int _templatePreviewCacheDimension(double logicalWidth, double pixelRatio) {
  if (!logicalWidth.isFinite || logicalWidth <= 0) {
    return 1080;
  }

  return (logicalWidth * pixelRatio).clamp(320, 1440).round();
}
