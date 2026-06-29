part of 'template_flow_sheets.dart';

class _AdaptiveTemplateMediaFrame extends StatelessWidget {
  const _AdaptiveTemplateMediaFrame({required this.template});

  final TemplateItem template;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final asset = template.previewAsset;
    final safeAssetUrl = parseSafeGenerationMediaUri(asset?.url)?.toString();
    final safeThumbnailUrl = parseSafeGenerationMediaUri(
      template.thumbnailUrl,
    )?.toString();
    final ratio = template.isVideo ? 9 / 16 : 3 / 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth = _templatePreviewCacheDimension(
          constraints.maxWidth,
          MediaQuery.devicePixelRatioOf(context),
        );
        final assetIsVideo = isVideoPreview(asset);
        final imageUrl =
            safeThumbnailUrl != null && !isVideoUrl(safeThumbnailUrl)
            ? safeThumbnailUrl
            : safeAssetUrl != null && !assetIsVideo
            ? safeAssetUrl
            : null;

        Widget media;
        if (asset == null && imageUrl == null) {
          media = _TemplatePreviewPlaceholder(
            isVideo: template.isVideo,
            title: _templatePreviewMissingTitle(text),
            subtitle: _templatePreviewMissingSubtitle(
              text,
              isVideo: template.isVideo,
            ),
          );
        } else if (template.isVideo && assetIsVideo && safeAssetUrl != null) {
          media = _NetworkVideoPreview(
            url: safeAssetUrl,
            useSharedPreviewCache: true,
          );
        } else if (imageUrl != null) {
          media = TemplatePreviewImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            cacheWidth: cacheWidth,
            placeholder: _EmptyMediaBox(label: text.templateFlowLoadingPreview),
            errorBuilder: (_) => _TemplatePreviewPlaceholder(
              isVideo: template.isVideo,
              title: _templatePreviewMissingTitle(text),
              subtitle: _templatePreviewMissingSubtitle(
                text,
                isVideo: template.isVideo,
              ),
            ),
          );
        } else {
          media = _TemplatePreviewPlaceholder(
            isVideo: template.isVideo,
            title: _templatePreviewMissingTitle(text),
            subtitle: _templatePreviewMissingSubtitle(
              text,
              isVideo: template.isVideo,
            ),
          );
        }

        return AspectRatio(
          aspectRatio: ratio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: media,
          ),
        );
      },
    );
  }
}

int _templatePreviewCacheDimension(double logicalWidth, double pixelRatio) {
  if (!logicalWidth.isFinite || logicalWidth <= 0) {
    return 1080;
  }

  return (logicalWidth * pixelRatio).clamp(320, 1440).round();
}

class _NetworkVideoPreview extends StatefulWidget {
  const _NetworkVideoPreview({
    required this.url,
    this.useSharedPreviewCache = false,
  });

  final String url;
  final bool useSharedPreviewCache;

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview>
    with WidgetsBindingObserver {
  static const double _loadVisibilityFraction = 0.18;
  static const double _playVisibilityFraction = 0.58;

  final Key _visibilityKey = UniqueKey();

  VideoPlayerController? _controller;
  bool _failedToLoad = false;
  bool _controllerInitInFlight = false;
  bool _isVisibleEnoughToLoad = false;
  bool _shouldPlay = false;
  bool _manualPaused = false;
  bool _hasPreviewSlot = false;
  int _initializeRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.useSharedPreviewCache != widget.useSharedPreviewCache) {
      final previous = _controller;
      _controller = null;
      _controllerInitInFlight = false;
      _failedToLoad = false;
      _manualPaused = false;
      _initializeRequestVersion++;
      _releasePreviewSlot();
      unawaited(previous?.dispose());
      if (_isVisibleEnoughToLoad) {
        unawaited(_initialize());
      }
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

    VideoPlayerController? controller;
    try {
      if (!MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()) {
        _controllerInitInFlight = false;
        return;
      }
      _hasPreviewSlot = true;

      controller = await _createVideoController(url, safeUri);
      if (!_isCurrentVideoRequestToken(requestVersion, url)) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.initialize();
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await controller.dispose();
        return;
      }

      await _syncPlaybackState();
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await controller.dispose();
        return;
      }
      setState(() {
        _failedToLoad = false;
      });
    } catch (_) {
      await controller?.dispose();
      if (_isCurrentVideoRequest(requestVersion, url, controller)) {
        _releasePreviewSlot();
        setState(() {
          _controller = null;
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
      fallbackUri: safeUri,
    );
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
      } catch (_) {
        // Disposal remains best-effort if the platform controller is already gone.
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

    final shouldPlay = _shouldPlay && !_manualPaused;
    try {
      if (shouldPlay && !controller.value.isPlaying) {
        await controller.play();
      } else if (!shouldPlay && controller.value.isPlaying) {
        await controller.pause();
      }
    } catch (_) {
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
    Widget child;
    if (_failedToLoad) {
      child = _TemplatePreviewPlaceholder(
        isVideo: true,
        title: _templatePreviewMissingTitle(text),
        subtitle: _templatePreviewMissingSubtitle(text, isVideo: true),
      );
    } else if (controller == null || !controller.value.isInitialized) {
      child = _EmptyMediaBox(label: text.templateFlowLoadingVideo);
    } else {
      child = Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: IconButton.filledTonal(
                onPressed: () async {
                  if (controller.value.isPlaying) {
                    _manualPaused = true;
                    await controller.pause();
                  } else {
                    _manualPaused = false;
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
      );
    }

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: child,
    );
  }
}
