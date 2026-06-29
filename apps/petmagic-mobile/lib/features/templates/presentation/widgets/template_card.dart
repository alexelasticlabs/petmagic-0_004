import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_image_state.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'template_card_presentation.part.dart';

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

class TemplateCardFeaturedData {
  const TemplateCardFeaturedData({
    required this.badgeLabel,
    required this.actionLabel,
    this.countdownTarget,
    this.popularityCount,
    this.isNew = false,
    this.showPopularityTodayFallback = true,
  });

  final String badgeLabel;
  final String actionLabel;
  final DateTime? countdownTarget;
  final int? popularityCount;
  final bool isNew;
  final bool showPopularityTodayFallback;
}

class TemplateCard extends StatefulWidget {
  const TemplateCard({
    required this.template,
    required this.hasPremiumAccess,
    required this.imageCacheWidth,
    this.onPressed,
    this.showGuestPreview = false,
    this.highlightBadgeLabel,
    this.featuredData,
    this.previewControllerFactory,
    super.key,
  });

  final TemplateItem template;
  final bool hasPremiumAccess;
  final int imageCacheWidth;
  final VoidCallback? onPressed;
  final bool showGuestPreview;
  final String? highlightBadgeLabel;
  final TemplateCardFeaturedData? featuredData;
  final Future<VideoPlayerController> Function(String previewUrl)?
  previewControllerFactory;

  @override
  State<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<TemplateCard>
    with WidgetsBindingObserver {
  static const Duration _disposeDelay = Duration(milliseconds: 900);
  static const double _prewarmVisibilityFraction = 0.28;
  static const double _playVisibilityFraction = 0.58;

  VideoPlayerController? _videoController;
  Timer? _disposeTimer;
  Timer? _featuredCountdownTimer;
  bool _isPreviewActive = false;
  bool _hasPreviewSlot = false;
  bool _isPressed = false;
  bool _videoLoadFailed = false;
  bool _videoControllerInitInFlight = false;
  double _lastVisibleFraction = 0;
  int _previewRetryToken = 0;
  int _videoControllerRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncFeaturedCountdownTicker();
  }

  @override
  void didUpdateWidget(covariant TemplateCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final mediaChanged =
        oldWidget.template.templateId != widget.template.templateId ||
        oldWidget.template.mediaIdentity != widget.template.mediaIdentity;
    if (mediaChanged) {
      _isPreviewActive = false;
      _videoLoadFailed = false;
      _previewRetryToken = 0;
      _disposeTimer?.cancel();
      unawaited(_disposeVideoController());
    }

    if (oldWidget.featuredData?.countdownTarget !=
        widget.featuredData?.countdownTarget) {
      _syncFeaturedCountdownTicker();
    }
  }

  @override
  void dispose() {
    _disposeTimer?.cancel();
    _featuredCountdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _videoControllerRequestVersion++;
    _videoControllerInitInFlight = false;
    final controller = _videoController;
    _videoController = null;
    unawaited(controller?.dispose());
    if (_hasPreviewSlot) {
      MediaLifecyclePolicy.releaseVideoPreviewSlot();
      _hasPreviewSlot = false;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _resumeVisiblePreviewAfterAppResume();
      return;
    }

    _suspendPreviewForAppBackground();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isFeatured = widget.featuredData != null;
    final premiumBorder = isFeatured
        ? const Color(0xFFF0D48A).withValues(alpha: 0.94)
        : widget.template.isPremium
        ? const Color(0xFFE6B75D).withValues(alpha: 0.9)
        : colors.border.withValues(alpha: isLight ? 0.62 : 0.28);
    final premiumGlow = isFeatured
        ? const Color(0xFF1EE6A0).withValues(alpha: 0.3)
        : widget.template.isPremium
        ? const Color(0xFFF0C875).withValues(alpha: 0.34)
        : colors.shadow;
    final cardRadius = BorderRadius.circular(24);
    final scaleDuration = PetMotion.effectiveDuration(context, PetMotion.fast);

    return AnimatedScale(
      duration: scaleDuration,
      curve: PetMotion.emphasized,
      scale: _isPressed ? 0.986 : 1,
      child: RepaintBoundary(
        child: VisibilityDetector(
          key: ValueKey(
            'template-card-${widget.template.templateId}'
            '-${widget.template.mediaIdentity}',
          ),
          onVisibilityChanged: _handleVisibility,
          child: DecoratedBox(
            decoration: isFeatured || widget.template.isPremium
                ? BoxDecoration(
                    borderRadius: cardRadius,
                    gradient: isFeatured
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A241C),
                              Color(0xFF0E1814),
                              Color(0xFF3B2A0B),
                            ],
                            stops: [0, 0.52, 1],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFF6E8C0),
                              Color(0xFFE6BB64),
                              Color(0xFFC1851E),
                            ],
                            stops: [0, 0.56, 1],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: premiumGlow.withValues(
                          alpha: isFeatured ? 0.22 : 0.14,
                        ),
                        blurRadius: isFeatured ? 18 : 10,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  )
                : const BoxDecoration(),
            child: Padding(
              padding: isFeatured || widget.template.isPremium
                  ? const EdgeInsets.all(1.2)
                  : EdgeInsets.zero,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: isFeatured || widget.template.isPremium
                      ? BorderRadius.circular(22.85)
                      : cardRadius,
                  border: Border.all(color: premiumBorder, width: 1.15),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isFeatured
                          ? const Color(0x3320D490)
                          : widget.template.isPremium
                          ? const Color(0x5A664412)
                          : colors.surfaceGlass.withValues(
                              alpha: isLight ? 0.58 : 0.28,
                            ),
                      isFeatured
                          ? const Color(0x3B241707)
                          : widget.template.isPremium
                          ? const Color(0x2E2B1A08)
                          : colors.surfaceStrong.withValues(
                              alpha: isLight ? 0.28 : 0.12,
                            ),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isFeatured
                          ? premiumGlow.withValues(alpha: 0.24)
                          : widget.template.isPremium
                          ? premiumGlow.withValues(alpha: 0.15)
                          : premiumGlow,
                      blurRadius: isFeatured
                          ? 20
                          : widget.template.isPremium
                          ? 12
                          : 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: isFeatured || widget.template.isPremium
                      ? BorderRadius.circular(22.85)
                      : cardRadius,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onPressed,
                      onHighlightChanged: (value) {
                        if (_isPressed == value) {
                          return;
                        }
                        setState(() => _isPressed = value);
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _TemplateMedia(
                            template: widget.template,
                            imageCacheWidth: widget.imageCacheWidth,
                            controller: _videoController,
                            videoLoadFailed: _videoLoadFailed,
                            previewRetryToken: _previewRetryToken,
                            onRetry: _retryPreviewLoad,
                          ),
                          const _TemplateShadeOverlay(),
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: _TemplateHeaderBadges(
                              highlightBadgeLabel:
                                  widget.featuredData?.badgeLabel ??
                                  widget.highlightBadgeLabel,
                              promoBadgeValue:
                                  widget.featuredData?.isNew == true
                                  ? 'NEW'
                                  : widget.template.effectivePromoBadge,
                              type: widget.template.templateType,
                              isFeatured: isFeatured,
                            ),
                          ),
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: _TemplateDetails(
                              template: widget.template,
                              hasPremiumAccess: widget.hasPremiumAccess,
                              showGuestPreview: widget.showGuestPreview,
                              featuredData: widget.featuredData,
                              onPressed: widget.onPressed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _syncFeaturedCountdownTicker() {
    _featuredCountdownTimer?.cancel();
    final target = widget.featuredData?.countdownTarget?.toUtc();
    if (target == null) {
      return;
    }

    final remaining = target.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      return;
    }

    final interval = remaining <= const Duration(hours: 1)
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);
    _featuredCountdownTimer = Timer.periodic(interval, (_) {
      if (!mounted) {
        return;
      }

      final nextRemaining = target.difference(DateTime.now().toUtc());
      if (nextRemaining <= Duration.zero) {
        _featuredCountdownTimer?.cancel();
      }
      setState(() {});
    });
  }

  void _handleVisibility(VisibilityInfo info) {
    if (!mounted) {
      return;
    }

    final isVideoTemplate =
        widget.template.isVideo && isVideoPreview(widget.template.previewAsset);
    if (!isVideoTemplate) {
      _isPreviewActive = false;
      _disposeTimer?.cancel();
      unawaited(_disposeVideoController());
      return;
    }

    final visibleFraction = info.visibleFraction;
    _lastVisibleFraction = visibleFraction;
    if (visibleFraction <= 0) {
      _isPreviewActive = false;
      _disposeTimer?.cancel();
      if (!TickerMode.valuesOf(context).enabled) {
        unawaited(_syncPlaybackState());
        return;
      }
      unawaited(_syncPlaybackState());
      unawaited(_disposeVideoController());
      return;
    }

    final shouldPrewarm = visibleFraction > _prewarmVisibilityFraction;
    final shouldPlay = visibleFraction > _playVisibilityFraction;

    if (shouldPrewarm) {
      _disposeTimer?.cancel();
      unawaited(_ensureVideoController());
    } else {
      unawaited(_syncPlaybackState());
      _scheduleVideoDispose();
    }

    if (_isPreviewActive == shouldPlay) {
      return;
    }

    _isPreviewActive = shouldPlay;
    if (shouldPlay) {
      unawaited(_ensureVideoController());
    } else {
      unawaited(_syncPlaybackState());
    }
  }

  void _suspendPreviewForAppBackground() {
    _isPreviewActive = false;
    _disposeTimer?.cancel();
    unawaited(_disposeVideoController());
  }

  void _resumeVisiblePreviewAfterAppResume() {
    if (!TickerMode.valuesOf(context).enabled ||
        _lastVisibleFraction <= _prewarmVisibilityFraction) {
      return;
    }

    _disposeTimer?.cancel();
    _isPreviewActive = _lastVisibleFraction > _playVisibilityFraction;
    unawaited(_ensureVideoController());
  }

  Future<void> _syncPlaybackState() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      if (_isPreviewActive) {
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (_) {
      // Controller might be disposed during async lifecycle transitions.
    }
  }

  void _scheduleVideoDispose() {
    _disposeTimer?.cancel();
    _disposeTimer = Timer(_disposeDelay, () {
      unawaited(_disposeVideoController());
    });
  }

  Future<void> _disposeVideoController() async {
    _disposeTimer?.cancel();
    _videoControllerRequestVersion++;
    _videoControllerInitInFlight = false;
    final controller = _videoController;
    if (controller == null) {
      if (_hasPreviewSlot) {
        MediaLifecyclePolicy.releaseVideoPreviewSlot();
        _hasPreviewSlot = false;
      }
      return;
    }

    if (_hasPreviewSlot) {
      MediaLifecyclePolicy.releaseVideoPreviewSlot();
      _hasPreviewSlot = false;
    }
    _videoController = null;
    try {
      await controller.dispose();
    } catch (_) {
      // Native video disposal can race with platform lifecycle changes.
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _ensureVideoController() async {
    if (_videoController != null || widget.template.previewAsset == null) {
      await _syncPlaybackState();
      return;
    }

    if (_videoControllerInitInFlight) {
      return;
    }

    final templateId = widget.template.templateId;
    final previewUrl = _normalizeTemplateMediaUrl(
      widget.template.previewAsset!.url,
    );
    if (previewUrl == null) {
      if (mounted) {
        setState(() {
          _videoLoadFailed = true;
        });
      }
      return;
    }

    if (!_hasPreviewSlot &&
        !MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()) {
      return;
    }
    _hasPreviewSlot = true;

    final requestVersion = ++_videoControllerRequestVersion;
    _videoControllerInitInFlight = true;
    VideoPlayerController? controller;

    try {
      controller = widget.previewControllerFactory != null
          ? await widget.previewControllerFactory!(previewUrl)
          : await _createVideoController(previewUrl);
      if (!_isCurrentVideoControllerRequest(
        requestVersion: requestVersion,
        templateId: templateId,
        previewUrl: previewUrl,
      )) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!_isCurrentVideoControllerRequest(
        requestVersion: requestVersion,
        templateId: templateId,
        previewUrl: previewUrl,
      )) {
        await controller.dispose();
        return;
      }

      await controller.initialize();
      if (!_isCurrentVideoControllerRequest(
        requestVersion: requestVersion,
        templateId: templateId,
        previewUrl: previewUrl,
      )) {
        await controller.dispose();
        return;
      }
      _videoController = controller;
      setState(() {});
      _videoLoadFailed = false;
      await _syncPlaybackState();
    } catch (_) {
      await controller?.dispose();
      if (_isCurrentVideoControllerRequest(
        requestVersion: requestVersion,
        templateId: templateId,
        previewUrl: previewUrl,
      )) {
        _videoController = null;
        _isPreviewActive = false;
        if (_hasPreviewSlot) {
          MediaLifecyclePolicy.releaseVideoPreviewSlot();
          _hasPreviewSlot = false;
        }
        setState(() {
          _videoLoadFailed = true;
        });
      }
    } finally {
      if (requestVersion == _videoControllerRequestVersion) {
        _videoControllerInitInFlight = false;
      }
    }
  }

  void _retryPreviewLoad() {
    _disposeTimer?.cancel();
    _videoControllerRequestVersion++;
    _videoControllerInitInFlight = false;
    _isPreviewActive = false;
    _videoLoadFailed = false;
    _previewRetryToken += 1;
    setState(() {});
    unawaited(_disposeVideoController());
    unawaited(_ensureVideoController());
  }

  Future<VideoPlayerController> _createVideoController(
    String previewUrl,
  ) async {
    return createTemplatePreviewVideoController(previewUrl);
  }

  bool _isCurrentVideoControllerRequest({
    required int requestVersion,
    required String templateId,
    required String previewUrl,
  }) {
    if (!mounted ||
        requestVersion != _videoControllerRequestVersion ||
        widget.template.templateId != templateId) {
      return false;
    }

    final currentPreviewUrl = _normalizeTemplateMediaUrl(
      widget.template.previewAsset?.url,
    );
    return currentPreviewUrl == previewUrl;
  }
}

@visibleForTesting
Future<VideoPlayerController> createTemplatePreviewVideoController(
  String previewUrl,
) async {
  return createCachedTemplatePreviewVideoController(previewUrl);
}

class _TemplateMedia extends StatelessWidget {
  const _TemplateMedia({
    required this.template,
    required this.imageCacheWidth,
    required this.controller,
    required this.videoLoadFailed,
    required this.previewRetryToken,
    required this.onRetry,
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
            cacheWidth: imageCacheWidth,
            onRetry: onRetry,
            isVideoTemplate: assetIsVideo,
          )
        else if (videoLoadFailed)
          _MediaErrorPlaceholder(
            isVideo: template.isVideo,
            onRetry: canRetry ? onRetry : null,
          )
        else
          const _MediaSkeletonPlaceholder(),
      ],
    );
  }
}

({String? imageUrl, bool assetIsVideo}) _resolveTemplateImagePreview(
  TemplateItem template,
) {
  final asset = template.previewAsset;
  final thumbnailUrl = _normalizeTemplateMediaUrl(template.thumbnailUrl);
  final assetUrl = _normalizeTemplateMediaUrl(asset?.url);
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

class _TemplateImageWithFallback extends StatefulWidget {
  const _TemplateImageWithFallback({
    super.key,
    required this.imageUrl,
    required this.cacheWidth,
    required this.onRetry,
    required this.isVideoTemplate,
  });

  final String imageUrl;
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
    _imageFileFuture = TemplateMediaCache.fetchThumbnailFile(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant _TemplateImageWithFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageFileFuture = TemplateMediaCache.fetchThumbnailFile(widget.imageUrl);
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
              const _MediaSkeletonPlaceholder(),
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
    return _MediaErrorPlaceholder(
      isVideo: widget.isVideoTemplate,
      onRetry: _retryImageLoad,
    );
  }

  void _retryImageLoad() {
    unawaited(TemplateMediaCache.removeThumbnailFile(widget.imageUrl));
    widget.onRetry();
  }
}

String? _normalizeTemplateMediaUrl(String? rawUrl) {
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
