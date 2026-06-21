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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (highlightBadgeLabel != null &&
                  highlightBadgeLabel!.isNotEmpty)
                _HighlightBadge(
                  label: highlightBadgeLabel!,
                  isFeatured: isFeatured,
                ),
              if (trimmedPromo != null && trimmedPromo.isNotEmpty)
                _PromoBadge(value: trimmedPromo),
            ],
          ),
        ),
        const SizedBox(width: 6),
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
    final musicDescription = template.musicDescription?.trim();
    final showMusicDescription =
        template.isVideo &&
        musicDescription != null &&
        musicDescription.isNotEmpty;
    final isPremiumLocked = template.isPremium && !hasPremiumAccess;
    final isFeatured = featuredData != null;
    final actionLabel = isPremiumLocked
        ? text.templateUnlockPremiumAction
        : featuredData?.actionLabel ?? text.templateTryAction;
    final featuredCountdownLabel = isFeatured
        ? _formatFeaturedCountdown(featuredData!.countdownTarget)
        : null;
    final featuredPopularityLabel = isFeatured
        ? _formatFeaturedPopularity(
            context,
            featuredData!.popularityCount,
            showTodayFallback: featuredData!.showPopularityTodayFallback,
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFeatured)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (featuredCountdownLabel != null)
                _TemplateFeaturedMetaChip(
                  icon: Icons.timer_outlined,
                  label: featuredCountdownLabel,
                  accent: const Color(0xFF22D394),
                ),
              if (featuredPopularityLabel != null)
                _TemplateFeaturedMetaChip(
                  icon: Icons.pets_rounded,
                  label: featuredPopularityLabel,
                  accent: const Color(0xFFF5D679),
                ),
            ],
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _TokenChip(cost: template.tokenCost),
              if (showGuestPreview)
                _TemplateStatusChip(label: text.templateGuestPreview),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          template.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle?.copyWith(
            color: Colors.white,
            fontSize: 13.4,
            fontWeight: FontWeight.w700,
            height: 1.04,
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
        if (showMusicDescription) ...[
          const SizedBox(height: 4),
          _MusicDescription(text: musicDescription),
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
        const SizedBox(height: 4),
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
              constraints: const BoxConstraints(maxWidth: 92),
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
          ],
        ),
        const SizedBox(height: 6),
        _TemplateActionButton(
          label: actionLabel,
          isPremiumLockCta: isPremiumLocked,
          isPremiumTemplateCta: template.isPremium || isFeatured,
          onPressed: onPressed,
        ),
      ],
    );
  }
}

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
                fontSize: 9.6,
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

class _TemplateActionButton extends StatelessWidget {
  const _TemplateActionButton({
    required this.label,
    required this.onPressed,
    this.isPremiumLockCta = false,
    this.isPremiumTemplateCta = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPremiumLockCta;
  final bool isPremiumTemplateCta;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    const premiumTextColor = Color(0xFF251102);
    final usePremiumStyle = isPremiumLockCta || isPremiumTemplateCta;
    final useSoftPremiumStyle = isPremiumTemplateCta && !isPremiumLockCta;
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
              : useSoftPremiumStyle
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
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xD910C878), Color(0xCCF2C96A)],
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
              color:
                  (isPremiumLockCta
                          ? const Color(0xFFE4901F)
                          : useSoftPremiumStyle
                          ? const Color(0xFFD8A64B)
                          : const Color(0xFF10C878))
                      .withValues(alpha: 0.24),
              blurRadius: useSoftPremiumStyle ? 10 : 14,
              offset: Offset(0, useSoftPremiumStyle ? 6 : 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle?.copyWith(
                    color: usePremiumStyle
                        ? premiumTextColor
                        : const Color(0xFF082313),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
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
                        color: usePremiumStyle
                            ? premiumTextColor
                            : const Color(0xFF082313),
                        size: usePremiumStyle ? 13.5 : 16,
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
            fontSize: 9.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MediaSkeletonPlaceholder extends StatelessWidget {
  const _MediaSkeletonPlaceholder();

  @override
  Widget build(BuildContext context) => const PetMagicImageSkeleton();
}

class _MediaErrorPlaceholder extends StatelessWidget {
  const _MediaErrorPlaceholder({required this.isVideo, this.onRetry});

  final bool isVideo;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isRu = _isRu(context);

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
                        isRu ? 'Превью недоступно' : 'Preview unavailable',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.textSoft,
                              fontSize: 11.6,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (onRetry != null) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: Text(
                            isRu ? 'Повторить' : text.retryAction,
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

  static bool _isRu(BuildContext context) =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
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
            color: Colors.white,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 11,
              color: Color(0xFF052317),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF052317),
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
                fontSize: 12.2,
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
            color: Color.fromRGBO(183, 227, 255, 0.94),
            fontSize: 9.2,
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
              fontSize: 9.6,
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
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFF46B0FF),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _AccessTag extends StatelessWidget {
  const _AccessTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall;
    const borderColor = Color.fromRGBO(245, 208, 101, 0.5);
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
                color: Color(0xFFFFE89E),
                fontSize: 9.2,
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
  if (popularityCount == null || popularityCount <= 0) {
    if (!showTodayFallback) {
      return null;
    }

    return Localizations.localeOf(context).languageCode.toLowerCase() == 'ru'
        ? 'Сегодня'
        : 'Today';
  }

  if (popularityCount < 1000) {
    return popularityCount.toString();
  }

  if (popularityCount < 10000) {
    final compact = popularityCount / 1000;
    return '${compact.toStringAsFixed(1).replaceFirst('.0', '')}k';
  }

  return '${(popularityCount / 1000).round()}k';
}
