import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/lifecycle/app_lifecycle_signal.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_media.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_playback_coordinator.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

export 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_media.dart'
    show
        resolveTemplateCardImageUrlForTesting,
        templateCardImageCacheWidthForLogicalWidth;
export 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_playback_coordinator.dart'
    show createTemplatePreviewVideoController;

part 'template_card_badges.part.dart';
part 'template_card_presentation.part.dart';

class TemplateCardFeaturedData {
  const TemplateCardFeaturedData({
    required this.badgeLabel,
    required this.actionLabel,
    this.countdownTarget,
    this.popularityCount,
    this.isNew = false,
    this.showPopularityTodayFallback = false,
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
    this.playbackManager,
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
  final TemplateFeedPlaybackManager? playbackManager;
  final Future<VideoPlayerController> Function(String previewUrl)?
  previewControllerFactory;

  @override
  State<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<TemplateCard> {
  late final TemplateCardPlaybackCoordinator _playback;
  Timer? _featuredCountdownTimer;
  bool _isPressed = false;
  bool _disposed = false;
  late final VoidCallback _appLifecycleListener = _handleAppLifecycleChanged;

  @override
  void initState() {
    super.initState();
    _playback = TemplateCardPlaybackCoordinator(
      template: widget.template,
      playbackManager: widget.playbackManager,
      previewControllerFactory: widget.previewControllerFactory,
      onChanged: _handlePlaybackChanged,
    );
    AppLifecycleSignal.instance.addListener(_appLifecycleListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFeaturedCountdownTicker();
  }

  @override
  void didUpdateWidget(covariant TemplateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playback.update(
      template: widget.template,
      playbackManager: widget.playbackManager,
      previewControllerFactory: widget.previewControllerFactory,
    );

    if (oldWidget.featuredData?.countdownTarget !=
        widget.featuredData?.countdownTarget) {
      _syncFeaturedCountdownTicker();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _featuredCountdownTimer?.cancel();
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

    final state = AppLifecycleSignal.instance.state;
    if (state == AppLifecycleState.resumed) {
      _syncFeaturedCountdownTicker();
      _playback.resumeVisiblePreviewAfterAppResume(
        tickerEnabled: TickerMode.valuesOf(context).enabled,
      );
      return;
    }

    _featuredCountdownTimer?.cancel();
    _playback.suspendForAppBackground();
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
          onVisibilityChanged: _playback.handleVisibility,
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
                          TemplateCardMedia(
                            template: widget.template,
                            imageCacheWidth: widget.imageCacheWidth,
                            controller: _playback.videoController,
                            videoLoadFailed: _playback.videoLoadFailed,
                            previewRetryToken: _playback.previewRetryToken,
                            onRetry: _playback.retryPreviewLoad,
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
    if (target == null || !_shouldRunFeaturedCountdownTicker) {
      return;
    }

    final remaining = target.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      return;
    }

    final delay = remaining <= const Duration(hours: 1)
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);
    _featuredCountdownTimer = Timer(delay, () {
      if (!mounted || !_shouldRunFeaturedCountdownTicker) {
        _featuredCountdownTimer = null;
        return;
      }

      final nextRemaining = target.difference(DateTime.now().toUtc());
      setState(() {});
      _featuredCountdownTimer = null;
      if (nextRemaining > Duration.zero) {
        _syncFeaturedCountdownTicker();
      }
    });
  }

  bool get _shouldRunFeaturedCountdownTicker =>
      !_disposed &&
      AppLifecycleSignal.instance.state == AppLifecycleState.resumed &&
      TickerMode.valuesOf(context).enabled;
}
