part of 'template_flow_sheets.dart';

extension _NetworkVideoPreviewLifecycle on _NetworkVideoPreviewState {
  Future<void> _disposeVideoController({bool notifyWhenComplete = true}) {
    _initializeRequestVersion++;
    _controllerInitInFlight = false;
    _cancelSlotWait();
    final upgradeDispose = _cancelUpgrade();
    final controller = _controller;
    final lease = _controllerLease;
    widget.playbackRegistry?._withdraw(
      widget.playbackIdentity,
      widget.mediaVersion,
      controller,
    );
    _controller = null;
    _controllerLease = null;
    _sourceUrl = null;

    if (controller == null && lease == null) {
      return upgradeDispose;
    }

    assert(lease == null || identical(lease.controller, controller));
    final disposeFuture = lease != null
        ? _trackControllerDispose(
            lease,
            pauseFirst: true,
            notifyWhenComplete: notifyWhenComplete,
          )
        : _disposeUnleasedController(controller!);
    return Future.wait([disposeFuture, upgradeDispose]);
  }

  Future<void> _trackControllerDispose(
    _TemplateVideoPreviewControllerLease lease, {
    required bool pauseFirst,
    bool notifyWhenComplete = false,
  }) {
    final disposeFuture = lease.dispose(pauseFirst: pauseFirst);
    _pendingControllerDispose = disposeFuture;
    unawaited(
      disposeFuture.whenComplete(() {
        if (identical(_pendingControllerDispose, disposeFuture)) {
          _pendingControllerDispose = null;
        }
      }),
    );
    if (notifyWhenComplete) {
      unawaited(
        disposeFuture.whenComplete(() {
          _refreshVideoPreview();
        }),
      );
    }
    return disposeFuture;
  }

  Future<void> _disposeUnleasedController(
    VideoPlayerController controller,
  ) async {
    try {
      await controller.dispose();
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.FlowMediaPreview',
        operation: 'dispose_unleased_video_preview',
        message: 'Unleased template flow preview disposal failed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _waitForSlot({bool detail = false}) {
    if (!mounted || !_canLoad || (detail && !widget.isActive)) return;
    _waitingForSlot = true;
    _waitingForDetailSlot = detail;
    MediaLifecyclePolicy.addVideoPreviewSlotListener(_slotReleaseListener);
    // A previous lease can finish disposal between the failed acquire and here.
    scheduleMicrotask(_resumeAfterSlotRelease);
  }

  void _cancelSlotWait({bool detailOnly = false}) {
    if (detailOnly && !_waitingForDetailSlot) return;
    MediaLifecyclePolicy.removeVideoPreviewSlotListener(_slotReleaseListener);
    _waitingForSlot = false;
    _waitingForDetailSlot = false;
  }

  void _resumeAfterSlotRelease() {
    if (!_waitingForSlot) return;
    if (!mounted || !_canLoad || (_waitingForDetailSlot && !widget.isActive)) {
      _cancelSlotWait();
      return;
    }
    if (!MediaLifecyclePolicy.hasVideoPreviewSlot(
      reserveForActive: !widget.isActive && widget.playbackRegistry == null,
    )) {
      return;
    }
    if (_waitingForDetailSlot && _upgradeInFlight) return;
    final detail = _waitingForDetailSlot;
    _cancelSlotWait();
    if (detail) {
      unawaited(_upgradeToDetail());
    } else if (_controller == null &&
        !_controllerInitInFlight &&
        !_failedToLoad) {
      unawaited(_initialize());
    }
  }

  Future<bool> _rejectCachedSource(
    String sourceUrl, {
    required int? mediaVersion,
  }) async {
    if (_rejectedSourceUrls.length >=
            _NetworkVideoPreviewState._maxRejectedSources ||
        !_rejectedSourceUrls.add(sourceUrl)) {
      return false;
    }
    try {
      await TemplateMediaCache.removePreviewFile(
        sourceUrl,
        mediaVersion: mediaVersion,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.FlowMediaPreview',
        operation: 'remove_unplayable_cached_source',
        message: 'Unplayable cached preview could not be removed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return true;
  }
}

final class _TemplateVideoPreviewControllerLease {
  _TemplateVideoPreviewControllerLease._({required this.useSharedPreviewCache});

  static _TemplateVideoPreviewControllerLease? tryAcquire({
    required bool useSharedPreviewCache,
    bool reserveForActive = false,
  }) {
    if (!MediaLifecyclePolicy.hasVideoPreviewSlot(
          reserveForActive: reserveForActive,
        ) ||
        !MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()) {
      return null;
    }

    return _TemplateVideoPreviewControllerLease._(
      useSharedPreviewCache: useSharedPreviewCache,
    );
  }

  final bool useSharedPreviewCache;

  VideoPlayerController? _controller;
  Future<void>? _disposeFuture;
  bool _slotReleased = false;

  VideoPlayerController? get controller => _controller;

  void attach(VideoPlayerController controller) {
    if (_controller != null || _disposeFuture != null) {
      throw StateError('template_video_preview_lease_already_used');
    }
    _controller = controller;
  }

  Future<void> dispose({bool pauseFirst = false}) {
    final existing = _disposeFuture;
    if (existing != null) {
      return existing;
    }

    final disposeFuture = _dispose(pauseFirst: pauseFirst);
    _disposeFuture = disposeFuture;
    return disposeFuture;
  }

  Future<void> _dispose({required bool pauseFirst}) async {
    final controller = _controller;
    try {
      if (pauseFirst && controller != null) {
        try {
          await controller.pause();
        } catch (error, stackTrace) {
          AppLogger.warn(
            feature: 'Templates.FlowMediaPreview',
            operation: 'pause_before_dispose',
            message: 'Template flow preview pause failed before disposal.',
            error: error,
            stackTrace: stackTrace,
            context: {'useSharedPreviewCache': useSharedPreviewCache},
          );
        }
      }

      if (controller != null) {
        try {
          await controller.dispose();
        } catch (error, stackTrace) {
          AppLogger.warn(
            feature: 'Templates.FlowMediaPreview',
            operation: 'dispose_video_preview',
            message: 'Template flow preview controller disposal failed.',
            error: error,
            stackTrace: stackTrace,
            context: {'useSharedPreviewCache': useSharedPreviewCache},
          );
        }
      }
    } finally {
      if (!_slotReleased) {
        _slotReleased = true;
        MediaLifecyclePolicy.releaseVideoPreviewSlot();
      }
    }
  }
}
