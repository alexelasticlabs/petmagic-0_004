import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_media.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

typedef TemplatePreviewControllerFactory =
    Future<VideoPlayerController> Function(String previewUrl);

class TemplateCardPlaybackCoordinator {
  TemplateCardPlaybackCoordinator({
    required TemplateItem template,
    required TemplateFeedPlaybackManager? playbackManager,
    required TemplatePreviewControllerFactory? previewControllerFactory,
    required VoidCallback onChanged,
  }) : _template = template,
       _playbackManager = playbackManager,
       _previewControllerFactory = previewControllerFactory,
       _onChanged = onChanged {
    _playbackManager?.addListener(_handlePlaybackManagerChanged);
  }

  static const Duration _disposeDelay = Duration(milliseconds: 400);

  TemplateItem _template;
  TemplateFeedPlaybackManager? _playbackManager;
  TemplatePreviewControllerFactory? _previewControllerFactory;
  final VoidCallback _onChanged;
  late final String _playbackCardId = 'template-card-${identityHashCode(this)}';

  VideoPlayerController? _videoController;
  Timer? _disposeTimer;
  bool _isPreviewActive = false;
  bool _disposed = false;
  bool _videoLoadFailed = false;
  bool _videoControllerInitInFlight = false;
  double _lastVisibleFraction = 0;
  int _previewRetryToken = 0;
  int _videoControllerRequestVersion = 0;

  VideoPlayerController? get videoController => _videoController;
  bool get videoLoadFailed => _videoLoadFailed;
  int get previewRetryToken => _previewRetryToken;

  void update({
    required TemplateItem template,
    required TemplateFeedPlaybackManager? playbackManager,
    required TemplatePreviewControllerFactory? previewControllerFactory,
  }) {
    if (_disposed) {
      return;
    }

    final mediaChanged =
        _template.templateId != template.templateId ||
        _template.mediaIdentity != template.mediaIdentity;
    final managerChanged = !identical(_playbackManager, playbackManager);

    if (mediaChanged) {
      _playbackManager?.unregisterCard(_playbackCardId);
      _isPreviewActive = false;
      _videoLoadFailed = false;
      _previewRetryToken = 0;
      _disposeTimer?.cancel();
      unawaited(_disposeVideoController());
    }

    if (managerChanged) {
      _playbackManager?.removeListener(_handlePlaybackManagerChanged);
      _playbackManager?.unregisterCard(_playbackCardId);
      playbackManager?.addListener(_handlePlaybackManagerChanged);
    }

    _template = template;
    _playbackManager = playbackManager;
    _previewControllerFactory = previewControllerFactory;
  }

  void handleVisibility(VisibilityInfo info) {
    if (_disposed) {
      return;
    }

    final isVideoTemplate = hasTemplateVideoPreview(_template);
    if (!isVideoTemplate) {
      _playbackManager?.unregisterCard(_playbackCardId);
      _isPreviewActive = false;
      _disposeTimer?.cancel();
      unawaited(_disposeVideoController());
      return;
    }

    final visibleFraction = info.visibleFraction;
    _lastVisibleFraction = visibleFraction;
    if (visibleFraction <= 0) {
      _playbackManager?.unregisterCard(_playbackCardId);
      _isPreviewActive = false;
      _disposeTimer?.cancel();
      unawaited(_syncPlaybackState());
      unawaited(_disposeVideoController());
      return;
    }

    if (_videoLoadFailed) {
      // A rebuild can emit the same visibility again. Do not turn that into
      // an unbounded automatic retry loop; recovery is explicit via Retry.
      _playbackManager?.unregisterCard(_playbackCardId);
      return;
    }

    _updateCardVisibility(visibleFraction);
    _syncWithPlaybackManager();
  }

  void suspendForAppBackground() {
    _playbackManager?.unregisterCard(_playbackCardId);
    _isPreviewActive = false;
    _disposeTimer?.cancel();
    unawaited(_disposeVideoController());
  }

  void resumeVisiblePreviewAfterAppResume({required bool tickerEnabled}) {
    if (_disposed ||
        !tickerEnabled ||
        _lastVisibleFraction <=
            TemplateFeedPlaybackManager.videoEligibilityVisibilityFraction) {
      return;
    }

    _disposeTimer?.cancel();
    _updateCardVisibility(_lastVisibleFraction);
    _syncWithPlaybackManager();
  }

  void retryPreviewLoad() {
    if (_disposed) {
      return;
    }

    _disposeTimer?.cancel();
    _videoControllerRequestVersion++;
    _videoControllerInitInFlight = false;
    _isPreviewActive = false;
    _videoLoadFailed = false;
    _previewRetryToken += 1;
    _notifyChanged();
    unawaited(_retryPreviewLoad());
  }

  Future<void> _retryPreviewLoad() async {
    await _disposeVideoController();
    if (_disposed || _lastVisibleFraction <= 0) {
      return;
    }

    _updateCardVisibility(_lastVisibleFraction);
    _syncWithPlaybackManager();
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _disposeTimer?.cancel();
    _playbackManager?.removeListener(_handlePlaybackManagerChanged);
    _playbackManager?.unregisterCard(_playbackCardId);
    _videoControllerRequestVersion++;
    _videoControllerInitInFlight = false;
    final controller = _videoController;
    _videoController = null;
    unawaited(controller?.dispose());
  }

  void _updateCardVisibility(double visibleFraction) {
    _playbackManager?.updateCardVisibility(
      cardId: _playbackCardId,
      templateId: _template.templateId,
      isVideoTemplate: hasTemplateVideoPreview(_template),
      hasAnimatedPreview:
          normalizeTemplateMediaUrl(_template.animatedPreviewUrl) != null,
      visibleFraction: visibleFraction,
      thumbnailUrl: _template.thumbnailUrl,
      animatedPreviewUrl: _template.animatedPreviewUrl,
      feedLoopLowUrl: _template.feedLoopLowUrl,
      feedLoopMediumUrl: _template.feedLoopMediumUrl,
      fallbackPreviewUrl: _template.previewAsset?.url,
      mediaVersion: _template.mediaVersion,
    );
  }

  void _handlePlaybackManagerChanged() {
    if (!_disposed) {
      _syncWithPlaybackManager();
    }
  }

  void _syncWithPlaybackManager() {
    if (_disposed) {
      return;
    }

    final manager = _playbackManager;
    final snapshot = manager?.snapshotFor(_playbackCardId);
    final shouldPlay =
        snapshot?.displayLevel == TemplateFeedDisplayLevel.videoPreview;
    if (shouldPlay) {
      _disposeTimer?.cancel();
      _isPreviewActive = true;
      unawaited(_ensureVideoController());
      return;
    }

    _isPreviewActive = false;
    unawaited(_syncPlaybackState());
    if (_lastVisibleFraction <= 0 ||
        (manager != null && snapshot?.hasVideoControllerSlot != true)) {
      unawaited(_disposeVideoController());
    } else {
      _scheduleVideoDispose();
    }
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
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.TemplateCard',
        operation: 'sync_playback_state',
        message: 'Template card preview playback sync failed.',
        error: error,
        stackTrace: stackTrace,
        context: {'isPreviewActive': _isPreviewActive},
      );
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
      return;
    }

    _videoController = null;
    try {
      await controller.dispose();
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.TemplateCard',
        operation: 'dispose_video_controller',
        message: 'Template card preview controller disposal failed.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'hasPlaybackGrant':
              _playbackManager
                  ?.snapshotFor(_playbackCardId)
                  .hasVideoControllerSlot ??
              false,
        },
      );
    }
    _notifyChanged();
  }

  Future<void> _ensureVideoController() async {
    if (_disposed) {
      return;
    }

    final snapshot = _playbackManager?.snapshotFor(_playbackCardId);
    if (snapshot?.displayLevel != TemplateFeedDisplayLevel.videoPreview) {
      await _syncPlaybackState();
      return;
    }
    if (_videoController != null) {
      await _syncPlaybackState();
      return;
    }
    if (_videoControllerInitInFlight) {
      return;
    }

    final templateId = _template.templateId;
    final previewUrl = normalizeTemplateMediaUrl(
      snapshot?.videoPreviewUrl ?? _template.previewAsset?.url,
    );
    if (previewUrl == null) {
      _markVideoLoadFailed();
      return;
    }

    final requestVersion = ++_videoControllerRequestVersion;
    _videoControllerInitInFlight = true;
    VideoPlayerController? controller;
    try {
      controller = _previewControllerFactory != null
          ? await _previewControllerFactory!(previewUrl)
          : await createTemplatePreviewVideoController(
              previewUrl,
              mediaVersion: snapshot?.mediaVersion,
            );
      if (!_isCurrentRequest(requestVersion, templateId, previewUrl)) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!_isCurrentRequest(requestVersion, templateId, previewUrl)) {
        await controller.dispose();
        return;
      }

      await controller.initialize();
      if (!_isCurrentRequest(requestVersion, templateId, previewUrl)) {
        await controller.dispose();
        return;
      }

      _videoController = controller;
      _videoLoadFailed = false;
      _notifyChanged();
      await _syncPlaybackState();
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.TemplateCard',
        operation: 'ensure_video_controller',
        message: 'Template card preview controller failed to initialize.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'hasPreviewControllerFactory': _previewControllerFactory != null,
          'isVideoTemplate': _template.isVideo,
        },
      );
      await controller?.dispose();
      if (_isCurrentRequest(requestVersion, templateId, previewUrl)) {
        _videoController = null;
        AppLogger.debug(
          feature: 'Templates.TemplateCard',
          operation: 'video_playback_fallback_to_thumbnail',
          message: 'Template card fell back to thumbnail after video failure.',
          context: {
            'templateId': _template.templateId,
            'hasThumbnail':
                normalizeTemplateMediaUrl(_template.thumbnailUrl) != null,
          },
        );
        _markVideoLoadFailed();
      }
    } finally {
      if (requestVersion == _videoControllerRequestVersion) {
        _videoControllerInitInFlight = false;
      }
    }
  }

  bool _isCurrentRequest(
    int requestVersion,
    String templateId,
    String previewUrl,
  ) {
    if (_disposed ||
        requestVersion != _videoControllerRequestVersion ||
        _template.templateId != templateId ||
        _playbackManager?.snapshotFor(_playbackCardId).displayLevel !=
            TemplateFeedDisplayLevel.videoPreview) {
      return false;
    }

    final snapshot = _playbackManager?.snapshotFor(_playbackCardId);
    final currentPreviewUrl = normalizeTemplateMediaUrl(
      snapshot?.videoPreviewUrl ?? _template.previewAsset?.url,
    );
    return currentPreviewUrl == previewUrl;
  }

  void _markVideoLoadFailed() {
    _isPreviewActive = false;
    _videoLoadFailed = true;
    // A failed controller must not occupy the constrained cellular/Wi-Fi
    // budget. Keep the card out of arbitration until the user retries or its
    // visibility changes.
    _playbackManager?.unregisterCard(_playbackCardId);
    _notifyChanged();
  }

  void _notifyChanged() {
    if (!_disposed) {
      _onChanged();
    }
  }
}

@visibleForTesting
Future<VideoPlayerController> createTemplatePreviewVideoController(
  String previewUrl, {
  int? mediaVersion,
}) {
  return createCachedTemplatePreviewVideoController(
    previewUrl,
    mediaVersion: mediaVersion,
  );
}
