import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class TemplateCard extends StatefulWidget {
  const TemplateCard({required this.template, super.key});

  final TemplateItem template;

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

    return VisibilityDetector(
      key: ValueKey('template-card-${widget.template.templateId}'),
      onVisibilityChanged: _handleVisibility,
      child: AnimatedScale(
        scale: _isVisible ? 1 : 0.992,
        duration: const Duration(milliseconds: 180),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _TemplateMedia(
                  template: widget.template,
                  controller: _videoController,
                ),
                const _TemplateShadeOverlay(),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.template.effectivePromoBadge != null)
                        _PromoBadge(value: widget.template.effectivePromoBadge!)
                      else
                        const Spacer(),
                      const SizedBox(width: 8),
                      _MediaTypeBadge(type: widget.template.templateType),
                    ],
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: _TemplateDetails(template: widget.template),
                ),
              ],
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
    _isVisible = info.visibleFraction > 0.05;
    if (!mounted) return;
    setState(() {});

    if (shouldPlay) {
      _ensureVideoController();
    } else {
      _videoController?.pause();
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
      setState(() {});
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _videoController = null);
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
    final colors = context.petMagicColors;

    return IgnorePointer(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surfaceGlass.withValues(alpha: 0.02),
                  colors.surfaceGlass.withValues(alpha: 0.08),
                  colors.surfaceGlass.withValues(alpha: 0.2),
                  colors.surfaceGlass.withValues(alpha: 0.42),
                  Colors.black.withValues(alpha: 0.38),
                  Colors.black.withValues(alpha: 0.58),
                ],
                stops: const [0, 0.16, 0.38, 0.62, 0.84, 1],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _TemplateDetails extends StatelessWidget {
  const _TemplateDetails({required this.template});

  final TemplateItem template;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final tags = template.tags.take(4).toList(growable: false);
    final showPremiumTag = template.isPremium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [_TokenChip(cost: template.tokenCost)]),
        const SizedBox(height: 7),
        Text(
          template.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            height: 0.98,
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
        const SizedBox(height: 4),
        Text(
          template.shortDescription,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color.fromRGBO(236, 244, 255, 0.9),
            fontSize: 11,
            height: 1.28,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(
                color: Color.fromRGBO(3, 7, 15, 0.48),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
        if (template.musicDescription?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 6),
          _MusicDescription(text: template.musicDescription!.trim()),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 5),
          SizedBox(
            height: 24,
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
        const SizedBox(height: 6),
        Row(
          children: [
            if (template.isVideo) ...[
              Text(
                formatDuration(template.referenceVideoDurationSeconds),
                style: const TextStyle(
                  color: Color.fromRGBO(228, 238, 251, 0.9),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const _MetaDot(),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                template.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color.fromRGBO(228, 238, 251, 0.9),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showPremiumTag) ...[
              const SizedBox(width: 8),
              _AccessTag(label: text.premiumLabel, premium: true),
            ],
          ],
        ),
      ],
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(color: tone.withValues(alpha: 0.24), blurRadius: 12),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          value.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
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
    final text = AppLocalizations.of(context);
    final label = type == TemplateType.video
        ? text.videoLabel
        : text.imageLabel;
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
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
        color: const Color.fromRGBO(15, 24, 37, 0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets_rounded, color: Color(0xFF73DD8C), size: 16),
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

class _MusicDescription extends StatelessWidget {
  const _MusicDescription({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color.fromRGBO(251, 191, 36, 0.2)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(251, 191, 36, 0.18),
                Color.fromRGBO(217, 119, 6, 0.1),
              ],
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.music_note_rounded,
              color: Color(0xFFFFE49D),
              size: 12,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color.fromRGBO(223, 233, 246, 0.88),
              fontSize: 11,
              height: 1.42,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromRGBO(125, 211, 252, 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '#$label',
          style: const TextStyle(
            color: Color.fromRGBO(183, 227, 255, 0.94),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
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
  const _AccessTag({required this.label, required this.premium});

  final String label;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final borderColor = premium
        ? const Color.fromRGBO(245, 208, 101, 0.5)
        : const Color.fromRGBO(74, 222, 128, 0.45);
    final background = premium
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(133, 77, 14, 0.58),
              Color.fromRGBO(63, 43, 12, 0.38),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(22, 101, 52, 0.58),
              Color.fromRGBO(8, 43, 29, 0.38),
            ],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: borderColor.withValues(alpha: 0.35), blurRadius: 14),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hexagon_outlined,
              size: 11,
              color: premium
                  ? const Color(0xFFF2C96A)
                  : const Color(0xFF6AE394),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: premium
                    ? const Color(0xFFFFE89E)
                    : const Color(0xFFA8FFC8),
                fontSize: 11,
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
