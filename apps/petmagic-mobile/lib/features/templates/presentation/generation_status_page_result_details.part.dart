part of 'generation_status_page.dart';

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 4),
            initiallyExpanded: false,
            iconColor: colors.textSoft,
            collapsedIconColor: colors.textMuted,
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.$1,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.$2,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.textStrong,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineVideoPreview extends StatefulWidget {
  const _InlineVideoPreview({
    required this.url,
    required this.localFilePath,
    this.onAspectRatioResolved,
    this.onReady,
  });

  final String url;
  final String? localFilePath;
  final ValueChanged<double>? onAspectRatioResolved;
  final VoidCallback? onReady;

  @override
  State<_InlineVideoPreview> createState() => _InlineVideoPreviewState();
}

class _InlineVideoPreviewState extends State<_InlineVideoPreview> {
  VideoPlayerController? _controller;
  bool _failedToLoad = false;
  bool _hasPreviewSlot = false;
  int _initializeRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _tryInitialize();
  }

  @override
  void didUpdateWidget(covariant _InlineVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.localFilePath != widget.localFilePath) {
      final previous = _controller;
      _controller = null;
      _failedToLoad = false;
      _releasePreviewSlot();
      unawaited(previous?.dispose());
      _tryInitialize();
    }
  }

  @override
  void dispose() {
    _initializeRequestVersion++;
    _releasePreviewSlot();
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  void _tryInitialize() {
    final requestVersion = ++_initializeRequestVersion;
    final url = widget.url;
    _hasPreviewSlot = MediaLifecyclePolicy.tryAcquireVideoPreviewSlot();
    if (!_hasPreviewSlot) {
      _failedToLoad = false;
      return;
    }
    unawaited(_initialize(requestVersion, url));
  }

  void _releasePreviewSlot() {
    if (!_hasPreviewSlot) {
      return;
    }
    _hasPreviewSlot = false;
    MediaLifecyclePolicy.releaseVideoPreviewSlot();
  }

  Future<void> _initialize(int requestVersion, String url) async {
    setState(() => _failedToLoad = false);
    final localFile = _localMediaFile(widget.localFilePath);
    if (localFile == null) {
      final safeUri = parseSafeGenerationMediaUri(url);
      if (safeUri == null) {
        _releasePreviewSlot();
        if (mounted && requestVersion == _initializeRequestVersion) {
          setState(() {
            _controller = null;
            _failedToLoad = true;
          });
        }
        return;
      }

      final controller = VideoPlayerController.networkUrl(safeUri);
      _controller = controller;
      await _initializeController(requestVersion, url, controller);
      return;
    }

    final controller = VideoPlayerController.file(localFile);
    _controller = controller;
    await _initializeController(requestVersion, url, controller);
  }

  Future<void> _initializeController(
    int requestVersion,
    String url,
    VideoPlayerController controller,
  ) async {
    if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
      await controller.dispose();
      return;
    }

    try {
      await controller.setLooping(true);
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await controller.dispose();
        return;
      }

      await controller.setVolume(0);
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await controller.dispose();
        return;
      }

      await controller.initialize();
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await controller.dispose();
        return;
      }

      final size = controller.value.size;
      if (size.width > 0 && size.height > 0) {
        widget.onAspectRatioResolved?.call(size.width / size.height);
      }

      await controller.play();
      if (!_isCurrentVideoRequest(requestVersion, url, controller)) {
        await controller.dispose();
        return;
      }
      setState(() {});
      widget.onReady?.call();
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationStatusResultSections',
        operation: 'initialize_video_preview',
        message: 'Result section video preview failed to initialize.',
        error: error,
        stackTrace: stackTrace,
        context: {'usesLocalFile': widget.localFilePath != null},
      );
      await controller.dispose();
      if (_isCurrentVideoRequest(requestVersion, url, controller)) {
        _releasePreviewSlot();
        setState(() {
          _controller = null;
          _failedToLoad = true;
        });
      }
    }
  }

  bool _isCurrentVideoRequest(
    int requestVersion,
    String url,
    VideoPlayerController controller,
  ) {
    return mounted &&
        requestVersion == _initializeRequestVersion &&
        widget.url == url &&
        _controller == controller;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final controller = _controller;

    if (!_hasPreviewSlot) {
      return ColoredBox(
        color: Colors.black.withValues(alpha: 0.75),
        child: const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
      );
    }

    if (_failedToLoad) {
      return _MediaPlaceholder(label: text.templateFlowResultLoadFailed);
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
