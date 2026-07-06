part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportImagePreviewDialog extends StatefulWidget {
  const _SupportImagePreviewDialog({
    required this.imageUrl,
    required this.fileName,
    required this.onSaveImage,
    required this.onShareImage,
    required this.onOpenOriginal,
  });

  final String imageUrl;
  final String? fileName;
  final Future<void> Function() onSaveImage;
  final Future<void> Function() onShareImage;
  final Future<void> Function() onOpenOriginal;

  @override
  State<_SupportImagePreviewDialog> createState() =>
      _SupportImagePreviewDialogState();
}

class _SupportImagePreviewDialogState
    extends State<_SupportImagePreviewDialog> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.01 || details == null) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    final position = details.localPosition;
    final zoomMatrix = Matrix4.identity()
      ..setEntry(0, 0, 2.4)
      ..setEntry(1, 1, 2.4)
      ..setTranslationRaw(-position.dx, -position.dy, 0);
    _transformationController.value = zoomMatrix;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.fileName?.trim().isNotEmpty == true
                          ? widget.fileName!
                          : text.supportChatImageLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<_SupportImagePreviewAction>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                    ),
                    color: Colors.black.withValues(alpha: 0.92),
                    onSelected: (action) {
                      switch (action) {
                        case _SupportImagePreviewAction.save:
                          unawaited(widget.onSaveImage());
                          return;
                        case _SupportImagePreviewAction.share:
                          unawaited(widget.onShareImage());
                          return;
                        case _SupportImagePreviewAction.openOriginal:
                          unawaited(widget.onOpenOriginal());
                          return;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _SupportImagePreviewAction.save,
                        child: Text(text.supportChatSaveImageAction),
                      ),
                      PopupMenuItem(
                        value: _SupportImagePreviewAction.share,
                        child: Text(text.supportChatShareAction),
                      ),
                      PopupMenuItem(
                        value: _SupportImagePreviewAction.openOriginal,
                        child: Text(text.supportChatOpenOriginalAction),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onDoubleTapDown: _handleDoubleTapDown,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      cacheKey: persistentSafeSupportMediaUrl(widget.imageUrl),
                      fit: BoxFit.contain,
                      memCacheWidth: _supportImagePreviewDialogCacheWidth,
                      maxWidthDiskCache: _supportImagePreviewDialogCacheWidth,
                      filterQuality: FilterQuality.medium,
                      placeholder: (context, url) {
                        return const SizedBox.shrink();
                      },
                      errorWidget: (context, url, error) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportVideoPreviewDialog extends StatefulWidget {
  const _SupportVideoPreviewDialog({
    required this.videoUrl,
    required this.fileName,
    required this.onOpenOriginal,
  });

  final String videoUrl;
  final String? fileName;
  final Future<void> Function() onOpenOriginal;

  @override
  State<_SupportVideoPreviewDialog> createState() =>
      _SupportVideoPreviewDialogState();
}

class _SupportVideoPreviewDialogState
    extends State<_SupportVideoPreviewDialog> {
  VideoPlayerController? _controller;
  bool _failedToLoad = false;
  int _initializeRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _initializeRequestVersion++;
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    final requestVersion = ++_initializeRequestVersion;
    final videoUrl = widget.videoUrl;
    final safeUri = parseSafeSupportExternalUri(videoUrl);
    if (safeUri == null) {
      if (_isCurrentVideoRequestWithoutController(requestVersion, videoUrl)) {
        setState(() => _failedToLoad = true);
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(safeUri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.seekTo(Duration.zero);
      if (!_isCurrentVideoRequest(requestVersion, videoUrl, controller)) {
        await controller.dispose();
        return;
      }
      setState(() {});
    } on Object {
      await controller.dispose();
      if (_isCurrentVideoRequest(requestVersion, videoUrl, controller)) {
        setState(() {
          _controller = null;
          _failedToLoad = true;
        });
      }
    }
  }

  bool _isCurrentVideoRequest(
    int requestVersion,
    String videoUrl,
    VideoPlayerController controller,
  ) {
    return mounted &&
        requestVersion == _initializeRequestVersion &&
        widget.videoUrl == videoUrl &&
        _controller == controller;
  }

  bool _isCurrentVideoRequestWithoutController(
    int requestVersion,
    String videoUrl,
  ) {
    return mounted &&
        requestVersion == _initializeRequestVersion &&
        widget.videoUrl == videoUrl &&
        _controller == null;
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final controller = _controller;
    final isInitialized = controller?.value.isInitialized == true;
    final duration = isInitialized ? controller!.value.duration : Duration.zero;
    final position = isInitialized ? controller!.value.position : Duration.zero;
    final safePosition = position > duration ? duration : position;
    final isPlaying = isInitialized && controller!.value.isPlaying;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.fileName?.trim().isNotEmpty == true
                          ? widget.fileName!
                          : text.supportChatVideoLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => unawaited(widget.onOpenOriginal()),
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      color: Colors.white,
                    ),
                    tooltip: text.supportChatOpenOriginalAction,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: isInitialized
                      ? controller!.value.aspectRatio
                      : 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColoredBox(
                      color: Colors.black,
                      child: _failedToLoad
                          ? const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 48,
                              ),
                            )
                          : !isInitialized
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : VideoPlayer(controller!),
                    ),
                  ),
                ),
              ),
            ),
            if (isInitialized)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      controller!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white54,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          _formatDuration(safePosition),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () async {
                            if (!isInitialized) {
                              return;
                            }
                            if (controller.value.position >=
                                controller.value.duration) {
                              await controller.seekTo(Duration.zero);
                            }
                            if (controller.value.isPlaying) {
                              await controller.pause();
                            } else {
                              await controller.play();
                            }
                            if (mounted) {
                              setState(() {});
                            }
                          },
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _SupportImagePreviewAction { save, share, openOriginal }
