import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/lifecycle/app_lifecycle_signal.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_media.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_playback_coordinator.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_image_state.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class TemplateDiscoveryMedia extends StatefulWidget {
  const TemplateDiscoveryMedia({
    required this.category,
    required this.paletteIndex,
    this.template,
    this.cacheWidth,
    this.playbackManager,
    this.previewControllerFactory,
    super.key,
  });

  final String category;
  final int paletteIndex;
  final TemplateItem? template;
  final int? cacheWidth;
  final TemplateFeedPlaybackManager? playbackManager;
  final TemplatePreviewControllerFactory? previewControllerFactory;

  @override
  State<TemplateDiscoveryMedia> createState() => _TemplateDiscoveryMediaState();
}

class _TemplateDiscoveryMediaState extends State<TemplateDiscoveryMedia> {
  late final TemplateCardPlaybackCoordinator _playback;
  late final VoidCallback _appLifecycleListener = _handleAppLifecycleChanged;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _playback = TemplateCardPlaybackCoordinator(
      template: widget.template ?? _fallbackTemplate,
      playbackManager: widget.playbackManager,
      previewControllerFactory: widget.previewControllerFactory,
      onChanged: _handlePlaybackChanged,
    );
    AppLifecycleSignal.instance.addListener(_appLifecycleListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (!tickerEnabled) {
      _playback.suspendForAppBackground();
      return;
    }

    _playback.resumeVisiblePreviewAfterAppResume(tickerEnabled: tickerEnabled);
  }

  @override
  void didUpdateWidget(covariant TemplateDiscoveryMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playback.update(
      template: widget.template ?? _fallbackTemplate,
      playbackManager: widget.playbackManager,
      previewControllerFactory: widget.previewControllerFactory,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    AppLifecycleSignal.instance.removeListener(_appLifecycleListener);
    _playback.dispose();
    super.dispose();
  }

  void _handlePlaybackChanged() {
    if (mounted && !_disposed) {
      setState(() {});
    }
  }

  void _handleAppLifecycleChanged() {
    if (!mounted || _disposed) {
      return;
    }

    if (AppLifecycleSignal.instance.state == AppLifecycleState.resumed) {
      _playback.resumeVisiblePreviewAfterAppResume(
        tickerEnabled: TickerMode.valuesOf(context).enabled,
      );
      return;
    }

    _playback.suspendForAppBackground();
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final imageUrl = resolveTemplateDiscoveryImageUrl(template);
    final fallback = _DiscoveryMediaFallback(
      category: widget.category,
      paletteIndex: widget.paletteIndex,
    );
    final controller = _playback.videoController;
    final showVideo = controller != null && controller.value.isInitialized;
    final videoLoadFailed = _playback.videoLoadFailed;
    final media = Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl == null)
          fallback
        else
          TemplatePreviewImage(
            imageUrl: imageUrl,
            mediaVersion: template?.mediaVersion,
            cacheWidth: widget.cacheWidth,
            placeholder: const TemplateMediaSkeletonPlaceholder(),
            errorBuilder: (_) => fallback,
          ),
        if (showVideo)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        if (videoLoadFailed)
          PetMagicImageError(
            title: AppLocalizations.of(context).templateFlowPreviewUnavailable,
            retryLabel: AppLocalizations.of(context).retryAction,
            onRetry: _playback.retryPreviewLoad,
            icon: Icons.videocam_off_rounded,
          ),
      ],
    );
    if (widget.playbackManager == null ||
        !hasTemplateVideoPreview(template ?? _fallbackTemplate)) {
      return media;
    }

    return RepaintBoundary(
      child: VisibilityDetector(
        key: ValueKey(
          'template-discovery-media-${template?.templateId ?? widget.category}'
          '-${template?.mediaIdentity ?? widget.paletteIndex}',
        ),
        onVisibilityChanged: _playback.handleVisibility,
        child: media,
      ),
    );
  }
}

const _fallbackTemplate = TemplateItem(
  templateId: 'discovery-media-fallback',
  templateType: TemplateType.image,
  title: '',
  shortDescription: '',
  petPhotoRequirements: <String>[],
  category: '',
  tags: <String>[],
  isPremium: false,
  tokenCost: 0,
);

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
