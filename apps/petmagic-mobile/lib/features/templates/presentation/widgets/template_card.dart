import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class TemplateCard extends StatefulWidget {
  const TemplateCard({
    required this.template,
    this.onPressed,
    this.showGuestPreview = false,
    this.previewControllerFactory,
    super.key,
  });

  final TemplateItem template;
  final VoidCallback? onPressed;
  final bool showGuestPreview;
  final Future<VideoPlayerController> Function(String previewUrl)?
  previewControllerFactory;

  @override
  State<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<TemplateCard> {
  static const Duration _disposeDelay = Duration(milliseconds: 120);
  static const double _prewarmVisibilityFraction = 0.28;
  static const double _playVisibilityFraction = 0.58;

  VideoPlayerController? _videoController;
  Timer? _disposeTimer;
  bool _isPreviewActive = false;
  bool _hasPreviewSlot = false;
  bool _isPressed = false;

  @override
  void didUpdateWidget(covariant TemplateCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.template.templateId != widget.template.templateId) {
      _isPreviewActive = false;
      _disposeTimer?.cancel();
      _disposeVideoController();
    }
  }

  @override
  void dispose() {
    _disposeTimer?.cancel();
    _videoController?.dispose();
    if (_hasPreviewSlot) {
      MediaLifecyclePolicy.releaseVideoPreviewSlot();
      _hasPreviewSlot = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final premiumBorder = widget.template.isPremium
        ? colors.gold.withValues(alpha: 0.58)
        : colors.border.withValues(alpha: 0.28);
    final premiumGlow = widget.template.isPremium
        ? colors.gold.withValues(alpha: 0.16)
        : colors.shadow;
    final cardRadius = BorderRadius.circular(24);
    final scaleDuration = PetMotion.effectiveDuration(context, PetMotion.fast);

    return AnimatedScale(
      duration: scaleDuration,
      curve: PetMotion.emphasized,
      scale: _isPressed ? 0.986 : 1,
      child: RepaintBoundary(
        child: VisibilityDetector(
          key: ValueKey('template-card-${widget.template.templateId}'),
          onVisibilityChanged: _handleVisibility,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: cardRadius,
              border: Border.all(color: premiumBorder, width: 1.15),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surfaceGlass.withValues(alpha: 0.28),
                  colors.surfaceStrong.withValues(alpha: 0.12),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: premiumGlow,
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: cardRadius,
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
                        controller: _videoController,
                      ),
                      const _TemplateShadeOverlay(),
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runSpacing: 6,
                          children: [
                            if (widget.template.effectivePromoBadge != null)
                              _PromoBadge(
                                value: widget.template.effectivePromoBadge!,
                              )
                            else
                              const SizedBox.shrink(),
                            _MediaTypeBadge(type: widget.template.templateType),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: _TemplateDetails(
                          template: widget.template,
                          showGuestPreview: widget.showGuestPreview,
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
    );
  }

  void _handleVisibility(VisibilityInfo info) {
    final isVideoTemplate =
        widget.template.isVideo && isVideoPreview(widget.template.previewAsset);
    if (!isVideoTemplate) {
      _isPreviewActive = false;
      _disposeTimer?.cancel();
      unawaited(_disposeVideoController());
      return;
    }

    final visibleFraction = info.visibleFraction;
    if (visibleFraction <= 0) {
      _isPreviewActive = false;
      _disposeTimer?.cancel();
      unawaited(_videoController?.pause());
      unawaited(_disposeVideoController());
      return;
    }

    final shouldPrewarm = visibleFraction > _prewarmVisibilityFraction;
    final shouldPlay = visibleFraction > _playVisibilityFraction;

    if (shouldPrewarm) {
      _disposeTimer?.cancel();
      unawaited(_ensureVideoController());
    } else {
      unawaited(_videoController?.pause());
      _scheduleVideoDispose();
    }

    if (_isPreviewActive == shouldPlay) {
      return;
    }

    _isPreviewActive = shouldPlay;
    if (shouldPlay) {
      unawaited(_ensureVideoController());
    } else {
      unawaited(_videoController?.pause());
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
    final controller = _videoController;
    if (controller == null) {
      if (_hasPreviewSlot) {
        MediaLifecyclePolicy.releaseVideoPreviewSlot();
        _hasPreviewSlot = false;
      }
      return;
    }

    _videoController = null;
    await controller.dispose();
    if (_hasPreviewSlot) {
      MediaLifecyclePolicy.releaseVideoPreviewSlot();
      _hasPreviewSlot = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _ensureVideoController() async {
    if (_videoController != null || widget.template.previewAsset == null) {
      if (_videoController?.value.isInitialized ?? false) {
        if (_isPreviewActive) {
          await _videoController?.play();
        } else {
          await _videoController?.pause();
        }
      }
      return;
    }

    if (!_hasPreviewSlot &&
        !MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()) {
      return;
    }
    _hasPreviewSlot = true;

    final previewUrl = widget.template.previewAsset!.url;
    final controller = widget.previewControllerFactory != null
        ? await widget.previewControllerFactory!(previewUrl)
        : await _createVideoController(previewUrl);
    _videoController = controller;
    controller.setLooping(true);
    controller.setVolume(0);

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      if (_videoController != controller) {
        await controller.dispose();
        return;
      }
      setState(() {});
      if (_isPreviewActive) {
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (_) {
      await controller.dispose();
      _isPreviewActive = false;
      if (_hasPreviewSlot) {
        MediaLifecyclePolicy.releaseVideoPreviewSlot();
        _hasPreviewSlot = false;
      }
      if (mounted) {
        setState(() => _videoController = null);
      }
    }
  }

  Future<VideoPlayerController> _createVideoController(
    String previewUrl,
  ) async {
    File? cachedFile;
    try {
      cachedFile = await TemplateMediaCache.getCachedPreviewFile(previewUrl);
      cachedFile ??= await TemplateMediaCache.fetchPreviewFile(previewUrl);
    } catch (_) {
      cachedFile = null;
    }

    if (cachedFile != null) {
      return VideoPlayerController.file(cachedFile);
    }

    return VideoPlayerController.networkUrl(Uri.parse(previewUrl));
  }
}

class _TemplateMedia extends StatelessWidget {
  const _TemplateMedia({required this.template, required this.controller});

  final TemplateItem template;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final asset = template.previewAsset;
    final thumbnailUrl = template.thumbnailUrl?.trim();
    final showVideo = controller != null && controller!.value.isInitialized;
    final assetIsVideo = asset != null && isVideoPreview(asset);
    final renderableThumbnailUrl =
        thumbnailUrl != null &&
            thumbnailUrl.isNotEmpty &&
            !isVideoUrl(thumbnailUrl)
        ? thumbnailUrl
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = _cacheDimension(constraints.maxWidth, pixelRatio);
        final cacheHeight = _cacheDimension(constraints.maxHeight, pixelRatio);

        return Stack(
          fit: StackFit.expand,
          children: [
            if (showVideo)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller!.value.size.height,
                  child: VideoPlayer(controller!),
                ),
              )
            else if (renderableThumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: renderableThumbnailUrl,
                fit: BoxFit.cover,
                cacheManager: TemplateMediaCache.thumbnailCache,
                memCacheWidth: cacheWidth,
                memCacheHeight: cacheHeight,
                maxWidthDiskCache: cacheWidth,
                maxHeightDiskCache: cacheHeight,
                placeholder: (context, url) => const _MediaPlaceholder(),
                errorWidget: (context, url, error) => const _MediaPlaceholder(),
              )
            else if (asset != null && asset.url.isNotEmpty && !assetIsVideo)
              CachedNetworkImage(
                imageUrl: asset.url,
                fit: BoxFit.cover,
                cacheManager: TemplateMediaCache.thumbnailCache,
                memCacheWidth: cacheWidth,
                memCacheHeight: cacheHeight,
                maxWidthDiskCache: cacheWidth,
                maxHeightDiskCache: cacheHeight,
                placeholder: (context, url) => const _MediaPlaceholder(),
                errorWidget: (context, url, error) => const _MediaPlaceholder(),
              )
            else
              const _MediaPlaceholder(),
          ],
        );
      },
    );
  }

  int? _cacheDimension(double logicalSize, double pixelRatio) {
    if (!logicalSize.isFinite || logicalSize <= 0) {
      return null;
    }

    return (logicalSize * pixelRatio).ceil();
  }
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

class _TemplateDetails extends StatelessWidget {
  const _TemplateDetails({
    required this.template,
    required this.showGuestPreview,
    required this.onPressed,
  });

  final TemplateItem template;
  final bool showGuestPreview;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          label: text.templateTryAction,
          onPressed: onPressed,
        ),
      ],
    );
  }
}

class _TemplateActionButton extends StatelessWidget {
  const _TemplateActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xD910C878), Color(0xCCF2C96A)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10C878).withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle?.copyWith(
                    color: const Color(0xFF082313),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF082313),
                size: 16,
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

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong,
            colors.accentSoft.withValues(alpha: 0.9),
            colors.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.pets_rounded, color: colors.accent, size: 42),
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
    final tone = switch (value.toLowerCase()) {
      'popular' => colors.purple,
      'trending' => colors.gold,
      'funny' => const Color(0xFFEC4899),
      _ => colors.accent,
    };

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
          value.toUpperCase(),
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
            const Icon(
              Icons.hexagon_outlined,
              size: 10,
              color: Color(0xFFF2C96A),
            ),
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
