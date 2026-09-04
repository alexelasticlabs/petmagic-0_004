import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_media.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';

class TemplateDiscoveryMedia extends StatelessWidget {
  const TemplateDiscoveryMedia({
    required this.category,
    required this.paletteIndex,
    this.template,
    this.cacheWidth,
    super.key,
  });

  final String category;
  final int paletteIndex;
  final TemplateItem? template;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveTemplateDiscoveryImageUrl(template);
    final fallback = _DiscoveryMediaFallback(
      category: category,
      paletteIndex: paletteIndex,
    );
    if (imageUrl == null) {
      return fallback;
    }

    return TemplatePreviewImage(
      imageUrl: imageUrl,
      mediaVersion: template?.mediaVersion,
      cacheWidth: cacheWidth,
      placeholder: const TemplateMediaSkeletonPlaceholder(),
      errorBuilder: (_) => fallback,
    );
  }
}

String? resolveTemplateDiscoveryImageUrl(TemplateItem? template) {
  if (template == null) {
    return null;
  }

  final thumbnail = normalizeTemplateMediaUrl(template.thumbnailUrl);
  if (thumbnail != null && !isVideoUrl(thumbnail)) {
    return thumbnail;
  }

  final preview = template.previewAsset;
  final previewUrl = normalizeTemplateMediaUrl(preview?.url);
  if (previewUrl == null || isVideoPreview(preview) || isVideoUrl(previewUrl)) {
    return null;
  }
  return previewUrl;
}

class _DiscoveryMediaFallback extends StatelessWidget {
  const _DiscoveryMediaFallback({
    required this.category,
    required this.paletteIndex,
  });

  final String category;
  final int paletteIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final palette = <Color>[
      colors.accent,
      colors.purple,
      colors.blue,
      colors.gold,
    ];
    final accent = palette[paletteIndex.abs() % palette.length];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.56), colors.surface),
            Color.alphaBlend(
              colors.accent.withValues(alpha: 0.18),
              colors.surfaceStrong,
            ),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -32,
            right: -18,
            child: _GlowOrb(color: accent, size: 132),
          ),
          Positioned(
            left: -28,
            bottom: -42,
            child: _GlowOrb(color: colors.accent, size: 154),
          ),
          Center(
            child: Icon(
              Icons.pets_rounded,
              size: 54,
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(34, -28),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 24,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
    );
  }
}
