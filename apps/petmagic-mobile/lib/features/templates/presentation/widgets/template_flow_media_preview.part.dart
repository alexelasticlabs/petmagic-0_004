part of 'template_flow_sheets.dart';

class TemplateMediaFrame extends StatelessWidget {
  const TemplateMediaFrame({
    required this.template,
    this.expand = false,
    this.isActive = true,
    this.autoplay = true,
    super.key,
  });

  final TemplateItem template;
  final bool expand;
  final bool isActive;
  final bool autoplay;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final asset = template.previewAsset;
    final safeAssetUrl = parseSafeGenerationMediaUri(asset?.url)?.toString();
    final safeDetailPreviewUrl = parseSafeGenerationMediaUri(
      template.detailPreviewUrl,
    )?.toString();
    final safeThumbnailUrl = parseSafeGenerationMediaUri(
      template.thumbnailUrl,
    )?.toString();
    final ratio = template.isVideo ? 9 / 16 : 3 / 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth = _templatePreviewCacheDimension(
          constraints.maxWidth,
          MediaQuery.devicePixelRatioOf(context),
        );
        final preferredMediaUrl = expand
            ? safeDetailPreviewUrl ?? safeAssetUrl
            : safeAssetUrl;
        final usesDetailMedia =
            expand &&
            safeDetailPreviewUrl != null &&
            preferredMediaUrl == safeDetailPreviewUrl;
        final preferredMediaIsVideo = usesDetailMedia
            ? template.detailPreviewIsVideo
            : preferredMediaUrl != null && preferredMediaUrl == safeAssetUrl
            ? isVideoPreview(asset)
            : isVideoUrl(preferredMediaUrl);
        final imageUrl = usesDetailMedia && !preferredMediaIsVideo
            ? safeDetailPreviewUrl
            : safeThumbnailUrl != null && !isVideoUrl(safeThumbnailUrl)
            ? safeThumbnailUrl
            : preferredMediaUrl != null && !preferredMediaIsVideo
            ? preferredMediaUrl
            : null;

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
            playbackIdentity: template.templateId,
            posterUrl: imageUrl,
            posterCacheWidth: cacheWidth,
            mediaVersion: template.mediaVersion,
            isActive: isActive,
            autoplay: autoplay,
            useSharedPreviewCache: true,
            fit: expand ? BoxFit.contain : BoxFit.cover,
            showPlaybackControl: true,
            playbackControlAlignment: expand
                ? Alignment.centerRight
                : Alignment.bottomRight,
          );
        } else if (imageUrl != null) {
          final usesDetailCache = expand && imageUrl == safeDetailPreviewUrl;
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
                  fit: BoxFit.contain,
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
            fit: expand ? BoxFit.contain : BoxFit.cover,
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
          if (!expand) {
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
