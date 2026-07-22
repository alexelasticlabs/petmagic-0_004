part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _NetworkVideoAttachmentPreview extends StatefulWidget {
  const _NetworkVideoAttachmentPreview({
    required this.videoUrl,
    required this.maxBubbleWidth,
    required this.onTap,
  });

  final String videoUrl;
  final double maxBubbleWidth;
  final VoidCallback? onTap;

  @override
  State<_NetworkVideoAttachmentPreview> createState() =>
      _NetworkVideoAttachmentPreviewState();
}

class _NetworkVideoAttachmentPreviewState
    extends State<_NetworkVideoAttachmentPreview> {
  VideoPlayerController? _controller;
  bool _failedToLoad = false;
  bool _hasPreviewSlot = false;
  int _initializeRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _tryInitializePreview();
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      final previous = _controller;
      _controller = null;
      _failedToLoad = false;
      _releasePreviewSlot();
      unawaited(previous?.dispose());
      _tryInitializePreview();
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

  void _tryInitializePreview() {
    final requestVersion = ++_initializeRequestVersion;
    final videoUrl = widget.videoUrl;
    _hasPreviewSlot = MediaLifecyclePolicy.tryAcquireVideoPreviewSlot();
    if (!_hasPreviewSlot) {
      return;
    }
    unawaited(_initialize(requestVersion, videoUrl));
  }

  void _releasePreviewSlot() {
    if (!_hasPreviewSlot) {
      return;
    }
    _hasPreviewSlot = false;
    MediaLifecyclePolicy.releaseVideoPreviewSlot();
  }

  Future<void> _initialize(int requestVersion, String videoUrl) async {
    final safeUri = parseSafeSupportExternalUri(videoUrl);
    if (safeUri == null) {
      if (_isCurrentVideoRequestWithoutController(requestVersion, videoUrl)) {
        _releasePreviewSlot();
        setState(() => _failedToLoad = true);
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(safeUri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.pause();
      await controller.seekTo(Duration.zero);
      if (!_isCurrentVideoRequest(requestVersion, videoUrl, controller)) {
        await controller.dispose();
        return;
      }
      setState(() {});
    } on Object {
      await controller.dispose();
      if (_isCurrentVideoRequest(requestVersion, videoUrl, controller)) {
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

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    if (!_hasPreviewSlot) {
      final size = _resolveMediaPreviewSize(
        maxWidth: widget.maxBubbleWidth,
        aspectRatio: 16 / 9,
      );
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: colors.surfaceStrong),
                Container(color: Colors.black.withValues(alpha: 0.18)),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    final aspectRatio = controller?.value.isInitialized == true
        ? controller!.value.aspectRatio
        : (16 / 9);
    final size = _resolveMediaPreviewSize(
      maxWidth: widget.maxBubbleWidth,
      aspectRatio: aspectRatio,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_failedToLoad)
                ColoredBox(
                  color: colors.surface,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.textMuted,
                    size: 24,
                  ),
                )
              else if (controller == null || !controller.value.isInitialized)
                ColoredBox(
                  color: colors.surface,
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              Container(color: Colors.black.withValues(alpha: 0.18)),
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
