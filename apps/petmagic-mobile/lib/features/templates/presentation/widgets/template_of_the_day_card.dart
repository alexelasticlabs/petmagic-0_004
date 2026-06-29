import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class TemplateOfTheDayCard extends StatelessWidget {
  const TemplateOfTheDayCard({
    required this.template,
    required this.hasPremiumAccess,
    required this.onPressed,
    super.key,
  });

  final TemplateOfTheDayItem template;
  final bool hasPremiumAccess;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final thumbnailUrl = _normalizeTemplateOfTheDayMediaUrl(
      template.thumbnailUrl,
    );
    final previewMediaUrl = _normalizeTemplateOfTheDayMediaUrl(
      template.previewMediaUrl ?? template.previewAsset?.url,
    );
    final videoPreviewUrl =
        template.isVideo &&
            previewMediaUrl != null &&
            isVideoUrl(previewMediaUrl)
        ? previewMediaUrl
        : null;
    final imageUrl =
        thumbnailUrl ?? (!template.isVideo ? previewMediaUrl : null);
    final isPremiumLocked = template.isPremium && !hasPremiumAccess;
    final visibleTags = template.tags.take(3).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 340 ? 208.0 : 232.0;
        return PetMagicInteractiveSurface(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          scaleDown: 0.985,
          child: SizedBox(
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.accent.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(
                      alpha: isLight ? 0.14 : 0.2,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
                color: colors.backgroundBottom,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null || videoPreviewUrl != null)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, mediaConstraints) {
                            final cacheWidth = _templateMediaCacheDimension(
                              mediaConstraints.maxWidth,
                              MediaQuery.devicePixelRatioOf(context),
                            );

                            if (videoPreviewUrl != null) {
                              return TemplateOfTheDayVideoPreview(
                                previewUrl: videoPreviewUrl,
                                thumbnailUrl: thumbnailUrl,
                                cacheWidth: cacheWidth,
                              );
                            }

                            if (imageUrl != null) {
                              return TemplatePreviewImage(
                                imageUrl: imageUrl,
                                cacheWidth: cacheWidth,
                                fit: BoxFit.cover,
                                placeholder:
                                    const _TemplateOfTheDayMediaFallback(),
                                errorBuilder: (_) =>
                                    const _TemplateOfTheDayMediaFallback(),
                              );
                            }

                            return const _TemplateOfTheDayMediaFallback();
                          },
                        ),
                      )
                    else
                      const _TemplateOfTheDayMediaFallback(),
                    const _TemplateOfTheDayDarkOverlay(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _TemplateOfTheDayBadge(
                                icon: Icons.auto_awesome_rounded,
                                label: template.badgeText.trim().isEmpty
                                    ? text.templateOfTheDayTitle
                                    : template.badgeText,
                              ),
                              _TemplateOfTheDayBadge(
                                icon: template.isVideo
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.image_outlined,
                                label: template.isVideo
                                    ? text.videoLabel
                                    : text.imageLabel,
                                isSubtle: true,
                              ),
                              if (template.isPremium)
                                _TemplateOfTheDayBadge(
                                  icon: Icons.workspace_premium_rounded,
                                  label: text.premiumLabel,
                                  isPremium: true,
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            template.title.trim().isEmpty
                                ? text.templateOfTheDaySubtitle
                                : template.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: constraints.maxWidth < 340
                                      ? 17
                                      : 18.5,
                                  height: 1.03,
                                  fontWeight: FontWeight.w900,
                                  shadows: const [
                                    Shadow(
                                      color: Color.fromRGBO(0, 0, 0, 0.74),
                                      blurRadius: 18,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            template.subtitle.trim().isEmpty
                                ? text.templateOfTheDaySubtitle
                                : template.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 11.2,
                                  height: 1.16,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (visibleTags.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            _TemplateOfTheDayTags(tags: visibleTags),
                          ],
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            runSpacing: 7,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (template.tokenCost > 0)
                                _TemplateOfTheDayCostChip(
                                  cost: template.tokenCost,
                                ),
                              _TemplateOfTheDayAction(
                                label: isPremiumLocked
                                    ? text.templateUnlockPremiumAction
                                    : text.templateOfTheDayTryAction,
                                isPremium: template.isPremium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
              '$cost PawSpark',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.2,
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

class TemplateOfTheDayVideoPreview extends StatefulWidget {
  const TemplateOfTheDayVideoPreview({
    super.key,
    required this.previewUrl,
    required this.thumbnailUrl,
    required this.cacheWidth,
  });

  final String previewUrl;
  final String? thumbnailUrl;
  final int? cacheWidth;

  @override
  State<TemplateOfTheDayVideoPreview> createState() =>
      _TemplateOfTheDayVideoPreviewState();
}

class _TemplateOfTheDayVideoPreviewState
    extends State<TemplateOfTheDayVideoPreview>
    with WidgetsBindingObserver {
  static const double _loadVisibilityFraction = 0.18;
  static const double _playVisibilityFraction = 0.58;

  final Key _visibilityKey = UniqueKey();
  VideoPlayerController? _controller;
  bool _controllerInitInFlight = false;
  bool _failedToLoad = false;
  bool _isVisibleEnoughToLoad = false;
  bool _shouldPlay = false;
  bool _hasPreviewSlot = false;
  int _initializeRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant TemplateOfTheDayVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewUrl != widget.previewUrl) {
      _failedToLoad = false;
      unawaited(_disposeVideoController());
      if (_isVisibleEnoughToLoad) {
        unawaited(_initialize());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isVisibleEnoughToLoad &&
          _controller == null &&
          !_controllerInitInFlight &&
          !_failedToLoad) {
        unawaited(_initialize());
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_disposeVideoController());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initializeRequestVersion++;
    _controllerInitInFlight = false;
    _releasePreviewSlot();
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final visibleFraction = info.visibleFraction;
    final shouldLoad = visibleFraction >= _loadVisibilityFraction;
    final shouldPlay = visibleFraction >= _playVisibilityFraction;
    if (shouldLoad == _isVisibleEnoughToLoad && shouldPlay == _shouldPlay) {
      return;
    }

    _isVisibleEnoughToLoad = shouldLoad;
    _shouldPlay = shouldPlay;

    if (!shouldLoad) {
      unawaited(_disposeVideoController());
      return;
    }

    if (_controller == null && !_controllerInitInFlight && !_failedToLoad) {
      unawaited(_initialize());
      return;
    }

    unawaited(_syncPlaybackState());
  }

  Future<void> _initialize() async {
    if (!_isVisibleEnoughToLoad || _controllerInitInFlight) {
      return;
    }

    final requestVersion = ++_initializeRequestVersion;
    final previewUrl = widget.previewUrl;
    final safeUri = parseSafeGenerationMediaUri(previewUrl);
    if (safeUri == null) {
      if (mounted) {
        setState(() => _failedToLoad = true);
      }
      return;
    }

    _controllerInitInFlight = true;
    if (!MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()) {
      _controllerInitInFlight = false;
      return;
    }
    _hasPreviewSlot = true;
    if (mounted) {
      setState(() => _failedToLoad = false);
    }

    VideoPlayerController? controller;
    try {
      controller = await createCachedTemplatePreviewVideoController(
        previewUrl,
        fallbackUri: safeUri,
      );
      if (!_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      await controller.setVolume(0);
      await controller.setLooping(true);
      if (!_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      await controller.initialize();
      if (!_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      _controller = controller;
      await _syncPlaybackState();
      if (!_isCurrentVideoRequest(requestVersion, previewUrl, controller)) {
        if (_controller == controller) {
          _controller = null;
        }
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      setState(() => _failedToLoad = false);
    } catch (error, stackTrace) {
      AppLogger.error(
        feature: 'templates',
        operation: 'initializeVideoController',
        message: 'Failed to initialize video controller',
        error: error,
        stackTrace: stackTrace,
      );
      await controller?.dispose();
      if (_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        _releasePreviewSlot();
        setState(() {
          if (_controller == controller) {
            _controller = null;
          }
          _failedToLoad = true;
        });
      }
    } finally {
      if (mounted && requestVersion == _initializeRequestVersion) {
        _controllerInitInFlight = false;
      }
    }
  }

  Future<void> _disposeVideoController() async {
    _initializeRequestVersion++;
    _controllerInitInFlight = false;
    _releasePreviewSlot();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.pause();
      } catch (error, stackTrace) {
        AppLogger.error(
          feature: 'templates',
          operation: 'disposeVideoController',
          message: 'Failed to pause video controller during dispose',
          error: error,
          stackTrace: stackTrace,
        );
      }
      await controller.dispose();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _releasePreviewSlot() {
    if (!_hasPreviewSlot) {
      return;
    }

    MediaLifecyclePolicy.releaseVideoPreviewSlot();
    _hasPreviewSlot = false;
  }

  Future<void> _syncPlaybackState() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      if (_shouldPlay && !controller.value.isPlaying) {
        await controller.play();
      } else if (!_shouldPlay && controller.value.isPlaying) {
        await controller.pause();
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        feature: 'templates',
        operation: 'syncPlaybackState',
        message: 'Failed to sync video playback state',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool _isCurrentVideoRequestToken(int requestVersion, String previewUrl) {
    return mounted &&
        requestVersion == _initializeRequestVersion &&
        widget.previewUrl == previewUrl;
  }

  bool _isCurrentVideoRequest(
    int requestVersion,
    String previewUrl,
    VideoPlayerController? controller,
  ) {
    return _isCurrentVideoRequestToken(requestVersion, previewUrl) &&
        _controller == controller;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _TemplateOfTheDayVideoFallback(
            thumbnailUrl: widget.thumbnailUrl,
            cacheWidth: widget.cacheWidth,
          ),
          if (!_failedToLoad &&
              controller != null &&
              controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateOfTheDayVideoFallback extends StatelessWidget {
  const _TemplateOfTheDayVideoFallback({
    required this.thumbnailUrl,
    required this.cacheWidth,
  });

  final String? thumbnailUrl;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl;
    if (url == null || url.isEmpty) {
      return const _TemplateOfTheDayMediaFallback();
    }

    return TemplatePreviewImage(
      imageUrl: url,
      cacheWidth: cacheWidth,
      fit: BoxFit.cover,
      placeholder: const _TemplateOfTheDayMediaFallback(),
      errorBuilder: (_) => const _TemplateOfTheDayMediaFallback(),
    );
  }
}

class _TemplateOfTheDayMediaFallback extends StatelessWidget {
  const _TemplateOfTheDayMediaFallback();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withValues(alpha: 0.26),
            colors.surfaceStrong.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 28),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: colors.accent.withValues(alpha: 0.72),
            size: 42,
          ),
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

String templateOfTheDayLoadErrorLabel(BuildContext context) {
  return AppLocalizations.of(context).templateOfTheDayLoadFailed;
}

String? _normalizeTemplateOfTheDayMediaUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final sanitized = Uri.encodeFull(trimmed.replaceAll('\\', '/'));
  final parsed = Uri.tryParse(sanitized);
  final String candidate;
  if (parsed?.hasScheme == true) {
    candidate = parsed.toString();
  } else if (sanitized.startsWith('//')) {
    final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    final scheme = (baseUri?.scheme.isNotEmpty ?? false)
        ? baseUri!.scheme
        : 'http';
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

int? _templateMediaCacheDimension(double logicalSize, double pixelRatio) {
  if (!logicalSize.isFinite || logicalSize <= 0) {
    return null;
  }

  return (logicalSize * pixelRatio).ceil();
}
