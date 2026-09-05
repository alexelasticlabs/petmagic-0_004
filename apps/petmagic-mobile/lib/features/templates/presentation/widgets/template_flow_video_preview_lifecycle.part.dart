part of 'template_flow_sheets.dart';

extension _NetworkVideoPreviewLifecycle on _NetworkVideoPreviewState {
  Future<void> _disposeVideoController({bool notifyWhenComplete = true}) {
    _initializeRequestVersion++;
    _controllerInitInFlight = false;
    _slotRetryScheduled = false;
    _slotRetryAttempts = 0;
    final controller = _controller;
    final lease = _controllerLease;
    _controller = null;
    _controllerLease = null;

    if (controller == null && lease == null) {
      return Future<void>.value();
    }

    assert(lease == null || identical(lease.controller, controller));
    final disposeFuture = lease != null
        ? _trackControllerDispose(
            lease,
            pauseFirst: true,
            notifyWhenComplete: notifyWhenComplete,
          )
        : _disposeUnleasedController(controller!);
    return disposeFuture;
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
          _notifyControllerDisposed();
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
}

final class _TemplateVideoPreviewControllerLease {
  _TemplateVideoPreviewControllerLease._({required this.useSharedPreviewCache});

  static _TemplateVideoPreviewControllerLease? tryAcquire({
    required bool useSharedPreviewCache,
  }) {
    if (!MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()) {
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
