import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_image_state.dart';
import 'package:video_player/video_player.dart';

const int _minTemplateCardImageCacheWidth = 320;
const int _defaultTemplateCardImageCacheWidth = 720;
const int _maxTemplateCardImageCacheWidth = 1080;

int templateCardImageCacheWidthForLogicalWidth(
  double logicalSize,
  double pixelRatio,
) {
  if (!logicalSize.isFinite ||
      logicalSize <= 0 ||
      !pixelRatio.isFinite ||
      pixelRatio <= 0) {
    return _defaultTemplateCardImageCacheWidth;
  }

  return (logicalSize * pixelRatio)
      .clamp(_minTemplateCardImageCacheWidth, _maxTemplateCardImageCacheWidth)
      .round();
}

class TemplateCardMedia extends StatelessWidget {
  const TemplateCardMedia({
    required this.template,
    required this.imageCacheWidth,
    required this.controller,
    required this.videoLoadFailed,
    required this.previewRetryToken,
    required this.onRetry,
    super.key,
  });

  final TemplateItem template;
  final int imageCacheWidth;
  final VideoPlayerController? controller;
  final bool videoLoadFailed;
  final int previewRetryToken;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final showVideo = controller != null && controller!.value.isInitialized;
    final imagePreview = _resolveTemplateImagePreview(template);
    final imageUrl = imagePreview.imageUrl;
    final assetIsVideo = imagePreview.assetIsVideo;
    final canRetry = imageUrl != null || assetIsVideo;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showVideo)
          AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.size.width,
                height: controller!.value.size.height,
                child: VideoPlayer(controller!),
              ),
            ),
          )
        else if (imageUrl != null)
          _TemplateImageWithFallback(
            key: ValueKey(
              'template-image-${template.templateId}'
              '-${template.mediaIdentity}'
              '-$previewRetryToken',
            ),
            imageUrl: imageUrl,
            mediaVersion: template.mediaVersion,
            cacheWidth: imageCacheWidth,
            onRetry: onRetry,
            isVideoTemplate: assetIsVideo,
          )
        else if (videoLoadFailed)
          TemplateMediaErrorPlaceholder(
            isVideo: template.isVideo,
            onRetry: canRetry ? onRetry : null,
          )
        else
          const TemplateMediaSkeletonPlaceholder(),
      ],
    );
  }
}

({String? imageUrl, bool assetIsVideo}) _resolveTemplateImagePreview(
  TemplateItem template,
) {
  final asset = template.previewAsset;
  final thumbnailUrl = normalizeTemplateMediaUrl(template.thumbnailUrl);
  final assetUrl = normalizeTemplateMediaUrl(asset?.url);
  final assetIsVideo = asset != null && isVideoPreview(asset);
  final renderableThumbnailUrl =
      thumbnailUrl != null && !isVideoUrl(thumbnailUrl) ? thumbnailUrl : null;
  final fallbackImageUrl = assetUrl != null && !assetIsVideo ? assetUrl : null;

  return (
    imageUrl: renderableThumbnailUrl ?? fallbackImageUrl,
    assetIsVideo: assetIsVideo,
  );
}

@visibleForTesting
String? resolveTemplateCardImageUrlForTesting(TemplateItem template) {
  return _resolveTemplateImagePreview(template).imageUrl;
}

bool hasTemplateVideoPreview(TemplateItem template) {
  return template.isVideo &&
      (normalizeTemplateMediaUrl(template.feedLoopLowUrl) != null ||
          normalizeTemplateMediaUrl(template.feedLoopMediumUrl) != null ||
          isVideoPreview(template.previewAsset));
}

class _TemplateImageWithFallback extends StatefulWidget {
  const _TemplateImageWithFallback({
    required this.imageUrl,
    required this.mediaVersion,
    required this.cacheWidth,
    required this.onRetry,
    required this.isVideoTemplate,
    super.key,
  });

  final String imageUrl;
  final int? mediaVersion;
  final int cacheWidth;
  final VoidCallback onRetry;
  final bool isVideoTemplate;

  @override
  State<_TemplateImageWithFallback> createState() =>
      _TemplateImageWithFallbackState();
}

class _TemplateImageWithFallbackState
    extends State<_TemplateImageWithFallback> {
  late Future<File> _imageFileFuture;

  @override
  void initState() {
    super.initState();
    _imageFileFuture = TemplateMediaCache.fetchThumbnailFile(
      widget.imageUrl,
      mediaVersion: widget.mediaVersion,
    );
  }

  @override
  void didUpdateWidget(covariant _TemplateImageWithFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.mediaVersion != widget.mediaVersion) {
      _imageFileFuture = TemplateMediaCache.fetchThumbnailFile(
        widget.imageUrl,
        mediaVersion: widget.mediaVersion,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _imageFileFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null && snapshot.hasError) {
          return _buildImageErrorPlaceholder();
        }

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const TemplateMediaSkeletonPlaceholder(),
              if (file != null)
                Image.file(
                  file,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  cacheWidth: widget.cacheWidth,
                  filterQuality: FilterQuality.medium,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        final isReady = wasSynchronouslyLoaded || frame != null;
                        return AnimatedOpacity(
                          opacity: isReady ? 1 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: child,
                        );
                      },
                  errorBuilder: (context, error, stackTrace) =>
                      _buildImageErrorPlaceholder(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageErrorPlaceholder() {
    return TemplateMediaErrorPlaceholder(
      isVideo: widget.isVideoTemplate,
      onRetry: _retryImageLoad,
    );
  }

  void _retryImageLoad() {
    unawaited(
      TemplateMediaCache.removeThumbnailFile(
        widget.imageUrl,
        mediaVersion: widget.mediaVersion,
      ),
    );
    widget.onRetry();
  }
}

class TemplateMediaSkeletonPlaceholder extends StatelessWidget {
  const TemplateMediaSkeletonPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const PetMagicImageSkeleton();
}

class TemplateMediaErrorPlaceholder extends StatelessWidget {
  const TemplateMediaErrorPlaceholder({
    required this.isVideo,
    this.onRetry,
    super.key,
  });

  final bool isVideo;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong.withValues(alpha: 0.92),
            colors.surface.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final detailsReserve = constraints.maxHeight < 250 ? 118.0 : 132.0;
          final mediaHeight = (constraints.maxHeight - detailsReserve).clamp(
            76.0,
            constraints.maxHeight,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: mediaHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVideo
                            ? Icons.videocam_off_rounded
                            : Icons.broken_image_outlined,
                        color: colors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        text.templateFlowPreviewUnavailable,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.textSoft,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (onRetry != null) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: Text(
                            text.retryAction,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String? normalizeTemplateMediaUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final sanitized = _sanitizeTemplateMediaUrl(trimmed);
  String candidate;

  final parsed = Uri.tryParse(sanitized);
  if (parsed?.hasScheme == true) {
    candidate = parsed.toString();
  } else if (sanitized.startsWith('//')) {
    final base = Uri.tryParse(AppConfig.apiBaseUrl);
    final scheme = (base?.scheme.isNotEmpty ?? false) ? base!.scheme : 'http';
    candidate = '$scheme:$sanitized';
  } else {
    final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    if (baseUri == null) {
      return null;
    }

    final relativePath = sanitized.startsWith('/') ? sanitized : '/$sanitized';
    candidate = baseUri.resolve(relativePath).toString();
  }

  return parseSafeGenerationMediaUri(candidate)?.toString();
}

String _sanitizeTemplateMediaUrl(String rawUrl) {
  final normalizedSlashes = rawUrl.replaceAll('\\', '/');
  return Uri.encodeFull(normalizedSlashes);
}
