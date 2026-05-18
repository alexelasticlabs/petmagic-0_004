import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class TemplateCard extends StatefulWidget {
  const TemplateCard({
    required this.template,
    this.onPressed,
    this.showGuestPreview = false,
    super.key,
  });

  final TemplateItem template;
  final VoidCallback? onPressed;
  final bool showGuestPreview;

  @override
  State<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<TemplateCard> {
  VideoPlayerController? _videoController;
  bool _isVisible = false;

  @override
  void dispose() {
    _videoController?.dispose();
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

    return RepaintBoundary(
      child: VisibilityDetector(
        key: ValueKey('template-card-${widget.template.templateId}'),
        onVisibilityChanged: _handleVisibility,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: premiumBorder, width: 1.15),
            boxShadow: [
              BoxShadow(
                color: premiumGlow,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
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
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: widget.template.effectivePromoBadge != null
                                  ? _PromoBadge(
                                      value: widget.template.effectivePromoBadge!,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(width: 6),
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
    );
  }

  void _handleVisibility(VisibilityInfo info) {
    final shouldPlay =
        info.visibleFraction > 0.58 &&
        widget.template.isVideo &&
        isVideoPreview(widget.template.previewAsset);
    final nextVisible = info.visibleFraction > 0.05;

    if (_isVisible != nextVisible && mounted) {
      setState(() => _isVisible = nextVisible);
    } else {
      _isVisible = nextVisible;
    }

    if (shouldPlay) {
      _ensureVideoController();
    } else {
      _disposeVideoController();
    }
  }

  Future<void> _disposeVideoController() async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    _videoController = null;
    await controller.dispose();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _ensureVideoController() async {
    if (_videoController != null || widget.template.previewAsset == null) {
      if (_videoController?.value.isInitialized ?? false) {
        await _videoController?.play();
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.template.previewAsset!.url),
    );
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
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _videoController = null);
      }
    }
  }
}

class _TemplateMedia extends StatelessWidget {
  const _TemplateMedia({required this.template, required this.controller});

  final TemplateItem template;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final asset = template.previewAsset;
    final showVideo = controller != null && controller!.value.isInitialized;
    final assetIsVideo = asset != null && isVideoPreview(asset);

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
        else if (asset != null && asset.url.isNotEmpty && !assetIsVideo)
          CachedNetworkImage(
            imageUrl: asset.url,
            fit: BoxFit.cover,
            placeholder: (context, url) => const _MediaPlaceholder(),
            errorWidget: (context, url, error) => const _MediaPlaceholder(),
          )
        else
          const _MediaPlaceholder(),
      ],
    );
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
    final tags = template.tags.take(3).toList(growable: false);
    final musicDescription = template.musicDescription?.trim();
    final showMusicDescription =
        template.isVideo &&
        musicDescription != null &&
        musicDescription.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _TokenChip(cost: template.tokenCost),
            if (showGuestPreview) ...[
              const SizedBox(width: 6),
              _TemplateStatusChip(label: text.templateGuestPreview),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          template.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            height: 1.02,
            letterSpacing: -0.02,
            shadows: [
              Shadow(
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
          const SizedBox(height: 5),
          SizedBox(
            height: 22,
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
        const SizedBox(height: 5),
        Row(
          children: [
            if (template.isVideo) ...[
              Text(
                formatDuration(template.referenceVideoDurationSeconds),
                style: const TextStyle(
                  color: Color.fromRGBO(228, 238, 251, 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              const _MetaDot(),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                template.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color.fromRGBO(228, 238, 251, 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (template.isPremium) ...[
              const SizedBox(width: 6),
              _AccessTag(label: text.premiumLabel),
            ],
          ],
        ),
        const SizedBox(height: 8),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 17,
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
        color: colors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: colors.accent,
            fontSize: 10,
            fontWeight: FontWeight.w900,
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(color: tone.withValues(alpha: 0.2), blurRadius: 10),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          value.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
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
    final label = type == TemplateType.video ? 'VIDEO' : 'IMAGE';
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(8, 11, 18, 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(17, 26, 39, 0.54),
        borderRadius: BorderRadius.circular(10),
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
            const Icon(Icons.pets_rounded, color: Color(0xFFF1CB73), size: 15),
            const SizedBox(width: 5),
            Text(
              '$cost',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(10, 18, 31, 0.34),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color.fromRGBO(125, 211, 252, 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          '#$label',
          style: const TextStyle(
            color: Color.fromRGBO(183, 227, 255, 0.94),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
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
    return Row(
      children: [
        const Icon(
          Icons.music_note_rounded,
          size: 13,
          color: Color.fromRGBO(255, 219, 135, 0.96),
        ),
        const SizedBox(width: 4),
        const Text(
          'Music:',
          style: TextStyle(
            color: Color.fromRGBO(255, 219, 135, 0.96),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color.fromRGBO(247, 233, 198, 0.92),
              fontSize: 10.5,
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
              style: const TextStyle(
                color: Color(0xFFFFE89E),
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.03,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
