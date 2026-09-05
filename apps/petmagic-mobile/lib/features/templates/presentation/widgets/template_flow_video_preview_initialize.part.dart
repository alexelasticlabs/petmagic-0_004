part of 'template_flow_sheets.dart';

extension _NetworkVideoPreviewInitialize on _NetworkVideoPreviewState {
  Future<void> _initialize() async {
    if (!_canLoad || _controllerInitInFlight || _controller != null) {
      return;
    }
    if (_waitingForSlot &&
        !MediaLifecyclePolicy.hasVideoPreviewSlot(
          reserveForActive: !widget.isActive,
        )) {
      return;
    }

    final requestVersion = ++_initializeRequestVersion;
    final url = widget.url;
    final mediaVersion = widget.mediaVersion;
    _cancelSlotWait();
    _controllerInitInFlight = true;
    if (mounted) {
      _setVideoPreviewState(() => _failedToLoad = false);
    }

    final safeUri = parseSafeGenerationMediaUri(url);
    if (safeUri == null) {
      if (mounted) {
        _setVideoPreviewState(() {
          _controllerInitInFlight = false;
          _failedToLoad = true;
        });
      }
      return;
    }

    final pendingDispose = _pendingControllerDispose;
    if (pendingDispose != null) {
      await pendingDispose;
      if (!_isCurrentVideoRequestToken(requestVersion, url)) {
        return;
      }
    }

    VideoPlayerController? controller;
    _TemplateVideoPreviewControllerLease? lease;
    String? preparedSourceUrl;
    var nativeDecodeFailed = false;
    var retryAfterDecodeFailure = false;
    try {
      // Downloading a cached file does not allocate a native decoder. Reserve
      // the decoder only once that download has completed for this request.
      final prepared = await _prepareInitialController(url, safeUri);
      if (prepared == null) {
        if (_isCurrentVideoRequestToken(requestVersion, url) &&
            widget.isActive &&
            _rejectedSourceUrls.isNotEmpty) {
          _setVideoPreviewState(() => _failedToLoad = true);
        }
        return;
      }
      controller = prepared.controller;
      preparedSourceUrl = prepared.url;
      if (!_isCurrentVideoRequestToken(requestVersion, url)) {
        await _disposeUnleasedController(controller);
        return;
      }

      lease = _TemplateVideoPreviewControllerLease.tryAcquire(
        useSharedPreviewCache: widget.useSharedPreviewCache,
        reserveForActive: !widget.isActive,
      );
      if (lease == null) {
        await _disposeUnleasedController(controller);
        if (_isCurrentVideoRequestToken(requestVersion, url)) {
          _controllerInitInFlight = false;
          _waitForSlot();
        }
        return;
      }
      lease.attach(controller);
      if (!_isCurrentVideoRequestToken(requestVersion, url)) {
        await lease.dispose();
        return;
      }

      _controller = controller;
      _controllerLease = lease;
      _sourceUrl = prepared.url;
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await lease.dispose();
        return;
      }

      await controller.setVolume(0);
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await lease.dispose();
        return;
      }

      await controller.setLooping(true);
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await lease.dispose();
        return;
      }

      try {
        await controller.initialize();
      } catch (_) {
        nativeDecodeFailed =
            widget.useSharedPreviewCache &&
            controller.dataSourceType == DataSourceType.file &&
            controller.value.hasError;
        rethrow;
      }
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await lease.dispose();
        return;
      }

      await _syncPlaybackState();
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await lease.dispose();
        return;
      }
      _refreshVideoPreview();
      widget.playbackRegistry?._publish(
        widget.playbackIdentity,
        widget.mediaVersion,
        controller,
      );
      unawaited(_upgradeToDetail());
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.FlowMediaPreview',
        operation: 'initialize_video_preview',
        message: 'Template flow media preview failed to initialize.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'useSharedPreviewCache': widget.useSharedPreviewCache,
          'shouldAutoplay': _shouldPlay,
        },
      );
      final isCurrentRequest = _isCurrentVideoRequest(
        requestVersion,
        url,
        controller,
      );
      final ownsCurrentController =
          lease != null && identical(_controllerLease, lease);
      if (ownsCurrentController) {
        _controller = null;
        _controllerLease = null;
      }
      if (lease != null) {
        await (ownsCurrentController
            ? _trackControllerDispose(lease, pauseFirst: true)
            : lease.dispose());
      } else if (controller != null) {
        await _disposeUnleasedController(controller);
      }
      if (isCurrentRequest &&
          _isCurrentVideoRequestToken(requestVersion, url)) {
        if (nativeDecodeFailed && preparedSourceUrl != null) {
          retryAfterDecodeFailure = await _rejectCachedSource(
            preparedSourceUrl,
            mediaVersion: mediaVersion,
          );
        }
        if (_isCurrentVideoRequestToken(requestVersion, url) &&
            !retryAfterDecodeFailure) {
          _setVideoPreviewState(() => _failedToLoad = true);
        }
      }
    } finally {
      if (mounted && requestVersion == _initializeRequestVersion) {
        _controllerInitInFlight = false;
        if (retryAfterDecodeFailure && _canLoad) unawaited(_initialize());
      }
    }
  }

  Future<VideoPlayerController> _createVideoController(
    String url,
    Uri safeUri,
  ) async {
    final factory = widget.controllerFactory;
    if (factory != null) return factory(url);
    if (!widget.useSharedPreviewCache) {
      return VideoPlayerController.networkUrl(safeUri);
    }

    return createCachedTemplatePreviewVideoController(
      url,
      mediaVersion: widget.mediaVersion,
      fallbackUri: safeUri,
    );
  }

  Future<({VideoPlayerController controller, String url})?>
  _prepareInitialController(String url, Uri safeUri) async {
    // Only speculative neighbours are cache-only. An explicitly selected page
    // must not wait for the batched visibility callback to start its download.
    final cachedOnly =
        !widget.isActive && !_isVisibleEnoughToLoad && widget.prepareOffscreen;
    if (widget.controllerFactory != null) {
      final initialUrl = <String>{...widget.fallbackUrls, url}
          .where((candidate) => !_rejectedSourceUrls.contains(candidate))
          .firstOrNull;
      if (initialUrl == null) return null;
      return (
        controller: await widget.controllerFactory!(initialUrl),
        url: initialUrl,
      );
    }
    if (widget.useSharedPreviewCache &&
        (widget.fallbackUrls.isNotEmpty ||
            cachedOnly ||
            _rejectedSourceUrls.isNotEmpty)) {
      final source = await resolveTemplatePreviewVideoSource(
        url,
        fallbackUrls: widget.fallbackUrls,
        mediaVersion: widget.mediaVersion,
        cachedOnly: cachedOnly,
        excludedUrls: Set<String>.of(_rejectedSourceUrls),
      );
      if (source == null) return null;
      return (
        controller: VideoPlayerController.file(source.file),
        url: source.url,
      );
    }
    return (controller: await _createVideoController(url, safeUri), url: url);
  }
}
