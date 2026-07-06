part of 'generation_status_page.dart';

class _FullscreenResultViewer extends StatefulWidget {
  const _FullscreenResultViewer({
    required this.generation,
    required this.mediaUrl,
    required this.localFilePath,
  });

  final TemplateGenerationResult generation;
  final String mediaUrl;
  final String? localFilePath;

  @override
  State<_FullscreenResultViewer> createState() =>
      _FullscreenResultViewerState();
}

class _FullscreenResultViewerState extends State<_FullscreenResultViewer> {
  VideoPlayerController? _videoController;
  bool _videoFailed = false;
  bool _showControls = true;
  bool _isMuted = false;
  Timer? _controlsTimer;
  int _videoInitializeRequestVersion = 0;

  bool get _isVideo => isVideoGeneration(widget.generation);

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      unawaited(_initializeVideo());
    }
    _startControlsTimer();
  }

  @override
  void dispose() {
    _videoInitializeRequestVersion++;
    _controlsTimer?.cancel();
    final controller = _videoController;
    _videoController = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final requestVersion = ++_videoInitializeRequestVersion;
    final mediaUrl = widget.mediaUrl;
    final localFile = _localMediaFile(widget.localFilePath);
    if (localFile == null) {
      final safeUri = parseSafeGenerationMediaUri(mediaUrl);
      if (safeUri == null) {
        setState(() {
          _videoController = null;
          _videoFailed = true;
        });
        return;
      }

      final controller = VideoPlayerController.networkUrl(safeUri);
      _videoController = controller;
      await _initializeFullscreenVideo(requestVersion, mediaUrl, controller);
      return;
    }

    final controller = VideoPlayerController.file(localFile);
    _videoController = controller;
    await _initializeFullscreenVideo(requestVersion, mediaUrl, controller);
  }

  Future<void> _initializeFullscreenVideo(
    int requestVersion,
    String mediaUrl,
    VideoPlayerController controller,
  ) async {
    if (!_isCurrentVideoRequest(requestVersion, mediaUrl, controller)) {
      await controller.dispose();
      return;
    }

    try {
      await controller.setLooping(true);
      if (!_isCurrentVideoRequest(requestVersion, mediaUrl, controller)) {
        await controller.dispose();
        return;
      }

      await controller.initialize();
      if (!_isCurrentVideoRequest(requestVersion, mediaUrl, controller)) {
        await controller.dispose();
        return;
      }

      await controller.play();
      if (!_isCurrentVideoRequest(requestVersion, mediaUrl, controller)) {
        await controller.dispose();
        return;
      }
      setState(() {});
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationStatusFullscreen',
        operation: 'initialize_video_preview',
        message: 'Fullscreen video preview failed to initialize.',
        error: error,
        stackTrace: stackTrace,
        context: {'usesLocalFile': widget.localFilePath != null},
      );
      await controller.dispose();
      if (_isCurrentVideoRequest(requestVersion, mediaUrl, controller)) {
        setState(() {
          _videoController = null;
          _videoFailed = true;
        });
      }
    }
  }

  bool _isCurrentVideoRequest(
    int requestVersion,
    String mediaUrl,
    VideoPlayerController controller,
  ) {
    return mounted &&
        requestVersion == _videoInitializeRequestVersion &&
        widget.mediaUrl == mediaUrl &&
        _videoController == controller;
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showControls = false;
      });
    });
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
    _startControlsTimer();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final controller = _videoController;
    final safeMediaUrl = parseSafeGenerationMediaUri(
      widget.mediaUrl,
    )?.toString();
    final localMediaFile = _localMediaFile(widget.localFilePath);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: _isVideo
                  ? _buildVideoMedia(text, controller)
                  : localMediaFile != null
                  ? InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.file(
                        localMediaFile,
                        fit: BoxFit.contain,
                        cacheWidth: _resultFullscreenImageCacheWidth,
                        filterQuality: FilterQuality.medium,
                      ),
                    )
                  : safeMediaUrl == null
                  ? _MediaPlaceholder(label: text.templateFlowResultLoadFailed)
                  : InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: CachedNetworkImage(
                        imageUrl: safeMediaUrl,
                        cacheKey: persistentSafeGenerationMediaUrl(
                          safeMediaUrl,
                        ),
                        fit: BoxFit.contain,
                        memCacheWidth: _resultFullscreenImageCacheWidth,
                        maxWidthDiskCache: _resultFullscreenImageCacheWidth,
                        filterQuality: FilterQuality.medium,
                        errorWidget: (context, url, error) => _MediaPlaceholder(
                          label: text.templateFlowResultLoadFailed,
                        ),
                      ),
                    ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showControls ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Column(
                  children: [
                    SafeArea(
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: Colors.white,
                          ),
                          Expanded(
                            child: Text(
                              widget.generation.templateTitle ??
                                  text.generationStatusResultTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_isVideo)
                            IconButton(
                              onPressed: _toggleMute,
                              icon: Icon(
                                _isMuted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                              ),
                              color: Colors.white,
                            ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_isVideo &&
                        controller != null &&
                        controller.value.isInitialized)
                      _FullscreenVideoControls(
                        controller: controller,
                        borderColor: colors.border.withValues(alpha: 0.5),
                        onInteraction: _startControlsTimer,
                        formatVideoTime: _formatVideoTime,
                      )
                    else
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            text.generationStatusFullscreenControlsHint,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoMedia(
    AppLocalizations text,
    VideoPlayerController? controller,
  ) {
    if (_videoFailed) {
      return _MediaPlaceholder(label: text.templateFlowResultLoadFailed);
    }

    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator.adaptive();
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

  String _formatVideoTime(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _FullscreenVideoControls extends StatelessWidget {
  const _FullscreenVideoControls({
    required this.controller,
    required this.borderColor,
    required this.onInteraction,
    required this.formatVideoTime,
  });

  final VideoPlayerController controller;
  final Color borderColor;
  final VoidCallback onInteraction;
  final String Function(Duration value) formatVideoTime;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final durationMs = value.duration.inMilliseconds.toDouble();
                final max = durationMs.clamp(1, double.infinity).toDouble();
                final current = value.position.inMilliseconds
                    .toDouble()
                    .clamp(0, max)
                    .toDouble();
                return Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        if (value.isPlaying) {
                          await controller.pause();
                        } else {
                          await controller.play();
                        }
                        onInteraction();
                      },
                      icon: Icon(
                        value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: current,
                        max: max,
                        onChanged: (next) async {
                          await controller.seekTo(
                            Duration(milliseconds: next.round()),
                          );
                          onInteraction();
                        },
                      ),
                    ),
                    Text(
                      '${formatVideoTime(value.position)} / ${formatVideoTime(value.duration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
