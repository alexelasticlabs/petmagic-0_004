part of 'template_flow_sheets.dart';

class _NetworkVideoPreview extends StatefulWidget {
  const _NetworkVideoPreview({
    required this.url,
    required this.playbackIdentity,
    this.posterUrl,
    this.posterCacheWidth,
    this.mediaVersion,
    this.isActive = true,
    this.autoplay = true,
    this.useSharedPreviewCache = false,
    this.fit = BoxFit.cover,
    this.showPlaybackControl = true,
    this.playbackControlAlignment = Alignment.bottomRight,
  });

  final String url;
  final String playbackIdentity;
  final String? posterUrl;
  final int? posterCacheWidth;
  final int? mediaVersion;
  final bool isActive;
  final bool autoplay;
  final bool useSharedPreviewCache;
  final BoxFit fit;
  final bool showPlaybackControl;
  final Alignment playbackControlAlignment;

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview>
    with WidgetsBindingObserver {
  static const double _loadVisibilityFraction = 0.18;
  static const double _playVisibilityFraction = 0.58;
  static const int _maxSlotRetryAttempts = 6;
  static const Duration _slotRetryDelay = Duration(milliseconds: 180);

  final Key _visibilityKey = UniqueKey();

  VideoPlayerController? _controller;
  _TemplateVideoPreviewControllerLease? _controllerLease;
  Future<void>? _pendingControllerDispose;
  bool _failedToLoad = false;
  bool _controllerInitInFlight = false;
  bool _isVisibleEnoughToLoad = false;
  bool _shouldPlay = false;
  bool _isAppResumed = true;
  bool _manualPaused = false;
  bool _manualStarted = false;
  bool _slotRetryScheduled = false;
  int _slotRetryAttempts = 0;
  int _initializeRequestVersion = 0;

  void _notifyControllerDisposed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isAppResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackIdentity != widget.playbackIdentity ||
        oldWidget.url != widget.url ||
        oldWidget.mediaVersion != widget.mediaVersion ||
        oldWidget.useSharedPreviewCache != widget.useSharedPreviewCache) {
      _failedToLoad = false;
      _slotRetryAttempts = 0;
      _slotRetryScheduled = false;
      if (oldWidget.playbackIdentity != widget.playbackIdentity) {
        _manualPaused = false;
        _manualStarted = false;
      }
      unawaited(_disposeVideoController());
      if (_isAppResumed && widget.isActive && _isVisibleEnoughToLoad) {
        unawaited(_initialize());
      }
      return;
    }

    if (oldWidget.isActive != widget.isActive) {
      if (!widget.isActive) {
        unawaited(_disposeVideoController());
      } else if (_isAppResumed && _isVisibleEnoughToLoad) {
        unawaited(_initialize());
      }
    }
    if (oldWidget.autoplay != widget.autoplay) {
      unawaited(_syncPlaybackState());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeVideoController(notifyWhenComplete: false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppResumed = true;
      if (_isVisibleEnoughToLoad &&
          widget.isActive &&
          _controller == null &&
          !_controllerInitInFlight &&
          !_failedToLoad) {
        unawaited(_initialize());
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _isAppResumed = false;
      unawaited(_disposeVideoController());
    }
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final visibleFraction = info.visibleFraction;
    final shouldLoad = visibleFraction >= _loadVisibilityFraction;
    final shouldPlay = visibleFraction >= _playVisibilityFraction;
    if (shouldLoad == _isVisibleEnoughToLoad && shouldPlay == _shouldPlay) {
      return;
    }

    _isVisibleEnoughToLoad = shouldLoad;
    _shouldPlay = shouldPlay;

    if (!shouldLoad) {
      unawaited(_disposeVideoController());
      return;
    }

    if (_isAppResumed &&
        widget.isActive &&
        _controller == null &&
        !_controllerInitInFlight &&
        !_failedToLoad) {
      unawaited(_initialize());
      return;
    }

    unawaited(_syncPlaybackState());
  }

  Future<void> _initialize() async {
    if (!_isAppResumed ||
        !widget.isActive ||
        !_isVisibleEnoughToLoad ||
        _controllerInitInFlight) {
      return;
    }

    final requestVersion = ++_initializeRequestVersion;
    final url = widget.url;
    _controllerInitInFlight = true;
    if (mounted) {
      setState(() => _failedToLoad = false);
    }

    final safeUri = parseSafeGenerationMediaUri(url);
    if (safeUri == null) {
      if (mounted) {
        setState(() {
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
    try {
      lease = _TemplateVideoPreviewControllerLease.tryAcquire(
        useSharedPreviewCache: widget.useSharedPreviewCache,
      );
      if (lease == null) {
        _controllerInitInFlight = false;
        _scheduleSlotRetry(requestVersion);
        return;
      }
      _slotRetryAttempts = 0;
      _slotRetryScheduled = false;

      controller = await _createVideoController(url, safeUri);
      lease.attach(controller);
      if (!_isCurrentVideoRequestToken(requestVersion, url)) {
        await lease.dispose();
        return;
      }

      _controller = controller;
      _controllerLease = lease;
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

      await controller.initialize();
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await lease.dispose();
        return;
      }

      await _syncPlaybackState();
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await lease.dispose();
        return;
      }
      setState(() {
        _failedToLoad = false;
      });
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
      final ownsCurrentController = identical(_controllerLease, lease);
      if (ownsCurrentController) {
        _controller = null;
        _controllerLease = null;
      }
      if (lease != null) {
        await (ownsCurrentController
            ? _trackControllerDispose(lease, pauseFirst: true)
            : lease.dispose());
      }
      if (isCurrentRequest &&
          _isCurrentVideoRequestToken(requestVersion, url)) {
        setState(() {
          _failedToLoad = true;
        });
      }
    } finally {
      if (mounted && requestVersion == _initializeRequestVersion) {
        _controllerInitInFlight = false;
      }
    }
  }

  Future<VideoPlayerController> _createVideoController(
    String url,
    Uri safeUri,
  ) async {
    if (!widget.useSharedPreviewCache) {
      return VideoPlayerController.networkUrl(safeUri);
    }

    return createCachedTemplatePreviewVideoController(
      url,
      mediaVersion: widget.mediaVersion,
      fallbackUri: safeUri,
    );
  }

  void _scheduleSlotRetry(int requestVersion) {
    if (_slotRetryScheduled || !mounted) {
      return;
    }
    if (_slotRetryAttempts >= _maxSlotRetryAttempts) {
      setState(() => _failedToLoad = true);
      return;
    }

    _slotRetryAttempts++;
    _slotRetryScheduled = true;
    Future<void>.delayed(_slotRetryDelay).then((_) {
      _slotRetryScheduled = false;
      if (!_isCurrentVideoRequestToken(requestVersion, widget.url) ||
          !_isAppResumed ||
          !widget.isActive ||
          !_isVisibleEnoughToLoad ||
          _controller != null ||
          _failedToLoad) {
        return;
      }
      unawaited(_initialize());
    });
  }

  void _retryInitialization() {
    if (!_isAppResumed || !widget.isActive || !_isVisibleEnoughToLoad) {
      return;
    }
    setState(() => _failedToLoad = false);
    _slotRetryAttempts = 0;
    _slotRetryScheduled = false;
    unawaited(_initialize());
  }

  Future<void> _syncPlaybackState() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final shouldPlay =
        _isAppResumed &&
        widget.isActive &&
        _shouldPlay &&
        (_manualStarted || (widget.autoplay && !_manualPaused));
    try {
      if (shouldPlay && !controller.value.isPlaying) {
        await controller.play();
      } else if (!shouldPlay && controller.value.isPlaying) {
        await controller.pause();
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.FlowMediaPreview',
        operation: 'sync_playback_state',
        message: 'Template flow preview playback sync failed.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'shouldPlay': shouldPlay,
          'manualPaused': _manualPaused,
          'useSharedPreviewCache': widget.useSharedPreviewCache,
        },
      );
      return;
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool _isCurrentVideoRequestToken(int requestVersion, String url) {
    return mounted &&
        requestVersion == _initializeRequestVersion &&
        widget.url == url;
  }

  bool _isCurrentVideoRequest(
    int requestVersion,
    String url,
    VideoPlayerController? controller,
  ) {
    return _isCurrentVideoRequestToken(requestVersion, url) &&
        _controller == controller;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final text = AppLocalizations.of(context);
    final posterUrl = widget.posterUrl;
    final hasPoster = posterUrl != null;
    final isInitialized =
        widget.isActive && (controller?.value.isInitialized ?? false);
    final poster = hasPoster
        ? TemplatePreviewImage(
            imageUrl: posterUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            cacheWidth: widget.posterCacheWidth,
            mediaVersion: widget.mediaVersion,
            placeholder: _EmptyMediaBox(label: text.templateFlowLoadingPreview),
            errorBuilder: (_) => _TemplatePreviewPlaceholder(
              isVideo: true,
              title: _templatePreviewMissingTitle(text),
              subtitle: _templatePreviewMissingSubtitle(text, isVideo: true),
            ),
          )
        : _EmptyMediaBox(label: text.templateFlowLoadingVideo);

    final child = Stack(
      fit: StackFit.expand,
      children: [
        poster,
        if (_failedToLoad && !hasPoster)
          _TemplatePreviewPlaceholder(
            isVideo: true,
            title: _templatePreviewMissingTitle(text),
            subtitle: _templatePreviewMissingSubtitle(text, isVideo: true),
          ),
        if (widget.isActive && !_failedToLoad && !isInitialized)
          Center(
            child: Semantics(
              label: text.templateFlowLoadingVideo,
              child: const CircularProgressIndicator.adaptive(),
            ),
          ),
        if (widget.isActive && _failedToLoad)
          Center(
            child: IconButton.filledTonal(
              tooltip: text.retryAction,
              onPressed: _retryInitialization,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        if (isInitialized) ...[
          FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: controller!.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          if (widget.showPlaybackControl)
            Align(
              alignment: widget.playbackControlAlignment,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: IconButton.filledTonal(
                  tooltip: controller.value.isPlaying
                      ? text.mediaPauseAction
                      : text.mediaPlayAction,
                  onPressed: () async {
                    if (controller.value.isPlaying) {
                      _manualPaused = true;
                      _manualStarted = false;
                      await controller.pause();
                    } else {
                      _manualPaused = false;
                      _manualStarted = true;
                      if (_shouldPlay) {
                        await controller.play();
                      }
                    }
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  icon: Icon(
                    controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ),
            ),
        ],
      ],
    );

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: child,
    );
  }
}
