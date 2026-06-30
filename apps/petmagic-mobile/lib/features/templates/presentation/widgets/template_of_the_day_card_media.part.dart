part of 'template_of_the_day_card.dart';

class TemplateOfTheDayVideoPreview extends StatefulWidget {
  const TemplateOfTheDayVideoPreview({
    super.key,
    required this.previewUrl,
    required this.thumbnailUrl,
    required this.cacheWidth,
  });

  final String previewUrl;
  final String? thumbnailUrl;
  final int? cacheWidth;

  @override
  State<TemplateOfTheDayVideoPreview> createState() =>
      _TemplateOfTheDayVideoPreviewState();
}

class _TemplateOfTheDayVideoPreviewState
    extends State<TemplateOfTheDayVideoPreview>
    with WidgetsBindingObserver {
  static const double _loadVisibilityFraction = 0.18;
  static const double _playVisibilityFraction = 0.58;

  final Key _visibilityKey = UniqueKey();
  VideoPlayerController? _controller;
  bool _controllerInitInFlight = false;
  bool _failedToLoad = false;
  bool _isVisibleEnoughToLoad = false;
  bool _shouldPlay = false;
  bool _hasPreviewSlot = false;
  int _initializeRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant TemplateOfTheDayVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewUrl != widget.previewUrl) {
      _failedToLoad = false;
      unawaited(_disposeVideoController());
      if (_isVisibleEnoughToLoad) {
        unawaited(_initialize());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isVisibleEnoughToLoad &&
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
      unawaited(_disposeVideoController());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initializeRequestVersion++;
    _controllerInitInFlight = false;
    _releasePreviewSlot();
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
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

    if (_controller == null && !_controllerInitInFlight && !_failedToLoad) {
      unawaited(_initialize());
      return;
    }

    unawaited(_syncPlaybackState());
  }

  Future<void> _initialize() async {
    if (!_isVisibleEnoughToLoad || _controllerInitInFlight) {
      return;
    }

    final requestVersion = ++_initializeRequestVersion;
    final previewUrl = widget.previewUrl;
    final safeUri = parseSafeGenerationMediaUri(previewUrl);
    if (safeUri == null) {
      if (mounted) {
        setState(() => _failedToLoad = true);
      }
      return;
    }

    _controllerInitInFlight = true;
    if (!MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()) {
      _controllerInitInFlight = false;
      return;
    }
    _hasPreviewSlot = true;
    if (mounted) {
      setState(() => _failedToLoad = false);
    }

    VideoPlayerController? controller;
    try {
      controller = await createCachedTemplatePreviewVideoController(
        previewUrl,
        fallbackUri: safeUri,
      );
      if (!_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      await controller.setVolume(0);
      await controller.setLooping(true);
      if (!_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      await controller.initialize();
      if (!_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      _controller = controller;
      await _syncPlaybackState();
      if (!_isCurrentVideoRequest(requestVersion, previewUrl, controller)) {
        if (_controller == controller) {
          _controller = null;
        }
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      setState(() => _failedToLoad = false);
    } catch (error, stackTrace) {
      AppLogger.error(
        feature: 'templates',
        operation: 'initializeVideoController',
        message: 'Failed to initialize video controller',
        error: error,
        stackTrace: stackTrace,
      );
      await controller?.dispose();
      if (_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        _releasePreviewSlot();
        setState(() {
          if (_controller == controller) {
            _controller = null;
          }
          _failedToLoad = true;
        });
      }
    } finally {
      if (mounted && requestVersion == _initializeRequestVersion) {
        _controllerInitInFlight = false;
      }
    }
  }

  Future<void> _disposeVideoController() async {
    _initializeRequestVersion++;
    _controllerInitInFlight = false;
    _releasePreviewSlot();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.pause();
      } catch (error, stackTrace) {
        AppLogger.error(
          feature: 'templates',
          operation: 'disposeVideoController',
          message: 'Failed to pause video controller during dispose',
          error: error,
          stackTrace: stackTrace,
        );
      }
      await controller.dispose();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _releasePreviewSlot() {
    if (!_hasPreviewSlot) {
      return;
    }

    MediaLifecyclePolicy.releaseVideoPreviewSlot();
    _hasPreviewSlot = false;
  }

  Future<void> _syncPlaybackState() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      if (_shouldPlay && !controller.value.isPlaying) {
        await controller.play();
      } else if (!_shouldPlay && controller.value.isPlaying) {
        await controller.pause();
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        feature: 'templates',
        operation: 'syncPlaybackState',
        message: 'Failed to sync video playback state',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool _isCurrentVideoRequestToken(int requestVersion, String previewUrl) {
    return mounted &&
        requestVersion == _initializeRequestVersion &&
        widget.previewUrl == previewUrl;
  }

  bool _isCurrentVideoRequest(
    int requestVersion,
    String previewUrl,
    VideoPlayerController? controller,
  ) {
    return _isCurrentVideoRequestToken(requestVersion, previewUrl) &&
        _controller == controller;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _TemplateOfTheDayVideoFallback(
            thumbnailUrl: widget.thumbnailUrl,
            cacheWidth: widget.cacheWidth,
          ),
          if (!_failedToLoad &&
              controller != null &&
              controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateOfTheDayVideoFallback extends StatelessWidget {
  const _TemplateOfTheDayVideoFallback({
    required this.thumbnailUrl,
    required this.cacheWidth,
  });

  final String? thumbnailUrl;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl;
    if (url == null || url.isEmpty) {
      return const _TemplateOfTheDayMediaFallback();
    }

    return TemplatePreviewImage(
      imageUrl: url,
      cacheWidth: cacheWidth,
      fit: BoxFit.cover,
      placeholder: const _TemplateOfTheDayMediaFallback(),
      errorBuilder: (_) => const _TemplateOfTheDayMediaFallback(),
    );
  }
}

class _TemplateOfTheDayMediaFallback extends StatelessWidget {
  const _TemplateOfTheDayMediaFallback();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withValues(alpha: 0.26),
            colors.surfaceStrong.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 28),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: colors.accent.withValues(alpha: 0.72),
            size: 42,
          ),
        ),
      ),
    );
  }
}
