part of 'template_flow_sheets.dart';

class _NetworkVideoPreview extends StatefulWidget {
  const _NetworkVideoPreview({
    required this.url,
    required this.playbackIdentity,
    this.fallbackUrls = const [],
    this.posterUrl,
    this.posterCacheWidth,
    this.mediaVersion,
    this.isActive = true,
    this.autoplay = true,
    this.muted = true,
    this.onMutedChanged,
    this.immersiveControls = false,
    this.prepareWhileVisible = false,
    this.prepareOffscreen = false,
    this.playWhenActive = false,
    this.allowDetailUpgrade = true,
    this.playbackRegistry,
    this.useSharedPreviewCache = false,
    this.fit = BoxFit.cover,
    this.showPlaybackControl = true,
    this.playbackControlAlignment = Alignment.bottomRight,
    this.placeholder,
    this.controllerFactory,
  });

  final String url;
  final String playbackIdentity;
  final List<String> fallbackUrls;
  final String? posterUrl;
  final int? posterCacheWidth;
  final int? mediaVersion;
  final bool isActive;
  final bool autoplay;
  final bool muted;
  final ValueChanged<bool>? onMutedChanged;
  final bool immersiveControls;
  final bool prepareWhileVisible;
  final bool prepareOffscreen;
  final bool playWhenActive;
  final bool allowDetailUpgrade;
  final TemplatePreviewPlaybackRegistry? playbackRegistry;
  final bool useSharedPreviewCache;
  final BoxFit fit;
  final bool showPlaybackControl;
  final Alignment playbackControlAlignment;
  final Widget? placeholder;
  final Future<VideoPlayerController> Function(String)? controllerFactory;

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview>
    with WidgetsBindingObserver {
  static const double _loadVisibilityFraction = 0.18;
  static const double _playVisibilityFraction = 0.58;
  static const int _maxRejectedSources = 3;

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
  bool _waitingForSlot = false;
  bool _waitingForDetailSlot = false;
  late final VoidCallback _slotReleaseListener = _resumeAfterSlotRelease;
  final Set<String> _rejectedSourceUrls = {};
  int _initializeRequestVersion = 0;
  int _playbackSyncVersion = 0;
  String? _sourceUrl;
  int _upgradeVersion = 0;
  bool _upgradeInFlight = false;
  _TemplateVideoPreviewControllerLease? _upgradeLease;
  VideoPlayerController? _handoverController;
  int _handoverVersion = 0;
  bool get _canPrepare =>
      widget.isActive || widget.prepareWhileVisible || widget.prepareOffscreen;
  bool get _canLoad =>
      _isAppResumed &&
      _canPrepare &&
      (_isVisibleEnoughToLoad ||
          widget.prepareOffscreen ||
          widget.playWhenActive && widget.isActive);

  void _refreshVideoPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setVideoPreviewState(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isAppResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          (widget.prepareOffscreen ||
              widget.playWhenActive && widget.isActive)) {
        unawaited(_initialize());
      }
    });
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackIdentity != widget.playbackIdentity ||
        oldWidget.mediaVersion != widget.mediaVersion ||
        oldWidget.playbackRegistry != widget.playbackRegistry) {
      oldWidget.playbackRegistry?._withdraw(
        oldWidget.playbackIdentity,
        oldWidget.mediaVersion,
        _controller,
      );
    }
    if (oldWidget.playbackIdentity != widget.playbackIdentity ||
        oldWidget.mediaVersion != widget.mediaVersion) {
      _rejectedSourceUrls.clear();
    }
    if (!widget.allowDetailUpgrade && oldWidget.allowDetailUpgrade) {
      unawaited(_cancelUpgrade());
    }
    if (oldWidget.url != widget.url &&
        oldWidget.playbackIdentity == widget.playbackIdentity &&
        oldWidget.mediaVersion == widget.mediaVersion &&
        oldWidget.useSharedPreviewCache == widget.useSharedPreviewCache &&
        _controller?.value.isInitialized == true) {
      // Detail hydration must not remove an already playing feed derivative.
      _initializeRequestVersion++;
      _controllerInitInFlight = false;
      if (widget.isActive && !oldWidget.isActive) {
        _manualPaused = false;
        _manualStarted = false;
      }
      if (!_canLoad) {
        unawaited(_disposeVideoController());
      } else {
        unawaited(_syncPlaybackState());
        unawaited(_cancelUpgrade().then((_) => _upgradeToDetail()));
      }
      return;
    }
    if (oldWidget.playbackIdentity != widget.playbackIdentity ||
        oldWidget.url != widget.url ||
        oldWidget.mediaVersion != widget.mediaVersion ||
        oldWidget.useSharedPreviewCache != widget.useSharedPreviewCache) {
      _failedToLoad = false;
      if (oldWidget.playbackIdentity != widget.playbackIdentity) {
        _manualPaused = false;
        _manualStarted = false;
      }
      unawaited(_disposeVideoController());
      if (_canLoad) {
        unawaited(_initialize());
      }
      return;
    }

    if (oldWidget.isActive != widget.isActive) {
      if (!widget.isActive) unawaited(_cancelUpgrade());
      if (widget.isActive) {
        _manualPaused = false;
        _manualStarted = false;
      }
      if (!_canPrepare) {
        unawaited(_disposeVideoController());
      } else if (_controller == null && _canLoad) {
        unawaited(_initialize());
      } else {
        unawaited(_syncPlaybackState());
      }
    }
    if (oldWidget.autoplay != widget.autoplay ||
        oldWidget.muted != widget.muted ||
        oldWidget.playWhenActive != widget.playWhenActive) {
      unawaited(_syncPlaybackState());
    }
    if (!_canLoad) {
      unawaited(_disposeVideoController());
    } else if (_controller == null && !_failedToLoad) {
      unawaited(_initialize());
    } else if (widget.isActive) {
      unawaited(_upgradeToDetail());
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
      if (_canLoad &&
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
    final shouldLoad =
        visibleFraction >=
        (widget.prepareWhileVisible ? 0.01 : _loadVisibilityFraction);
    final shouldPlay = visibleFraction >= _playVisibilityFraction;
    if (shouldLoad == _isVisibleEnoughToLoad && shouldPlay == _shouldPlay) {
      return;
    }

    _isVisibleEnoughToLoad = shouldLoad;
    _shouldPlay = shouldPlay;

    if (!shouldLoad && !widget.prepareOffscreen) {
      unawaited(_disposeVideoController());
      return;
    }

    if (_canLoad &&
        _controller == null &&
        !_controllerInitInFlight &&
        !_failedToLoad) {
      unawaited(_initialize());
      return;
    }

    unawaited(_syncPlaybackState());
    if (shouldLoad) unawaited(_upgradeToDetail());
  }

  void _retryInitialization() {
    if (!_canLoad) {
      return;
    }
    setState(() => _failedToLoad = false);
    _rejectedSourceUrls.clear();
    unawaited(_initialize());
  }

  Future<void> _syncPlaybackState() async {
    final syncVersion = ++_playbackSyncVersion;
    final controller = _controller;
    if (controller == null ||
        identical(controller, _handoverController) ||
        !controller.value.isInitialized) {
      return;
    }

    final shouldPlay =
        _isAppResumed &&
        widget.isActive &&
        (widget.playWhenActive || _shouldPlay) &&
        (_manualStarted || (widget.autoplay && !_manualPaused));
    try {
      await controller.setVolume(widget.muted || !widget.isActive ? 0 : 1);
      if (!mounted ||
          syncVersion != _playbackSyncVersion ||
          !identical(controller, _controller) ||
          !_isAppResumed) {
        return;
      }
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
  Widget build(BuildContext context) => _buildVideoPreview(context);
}
