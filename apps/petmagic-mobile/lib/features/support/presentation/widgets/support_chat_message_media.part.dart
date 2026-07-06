part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _DeletedAttachmentPlaceholder extends StatelessWidget {
  const _DeletedAttachmentPlaceholder({
    required this.isVideo,
    required this.maxBubbleWidth,
  });

  final bool isVideo;
  final double maxBubbleWidth;

  @override
  Widget build(BuildContext context) {
    final size = _resolveMediaPreviewSize(
      maxWidth: maxBubbleWidth,
      aspectRatio: 1,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: _DeletedAttachmentTileBackground(isVideo: isVideo),
      ),
    );
  }
}

class _UnsupportedAttachmentPlaceholder extends StatelessWidget {
  const _UnsupportedAttachmentPlaceholder({
    required this.isVideo,
    required this.maxBubbleWidth,
  });

  final bool isVideo;
  final double maxBubbleWidth;

  @override
  Widget build(BuildContext context) {
    final size = _resolveMediaPreviewSize(
      maxWidth: maxBubbleWidth,
      aspectRatio: isVideo ? 16 / 9 : 1,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: _UnsupportedAttachmentTileBackground(isVideo: isVideo),
      ),
    );
  }
}

class _DeletedAttachmentTileBackground extends StatelessWidget {
  const _DeletedAttachmentTileBackground({
    required this.isVideo,
    this.compact = false,
  });

  final bool isVideo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    return ColoredBox(
      color: colors.surface,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo
                    ? Icons.videocam_off_rounded
                    : Icons.image_not_supported_outlined,
                size: compact ? 16 : 24,
                color: colors.textMuted,
              ),
              SizedBox(height: compact ? 3 : 6),
              Text(
                text.supportChatAttachmentExpiredPlaceholder,
                textAlign: TextAlign.center,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: compact ? 9 : 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnsupportedAttachmentTileBackground extends StatelessWidget {
  const _UnsupportedAttachmentTileBackground({
    required this.isVideo,
    this.compact = false,
  });

  final bool isVideo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    return ColoredBox(
      color: colors.surface,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo
                    ? Icons.videocam_off_rounded
                    : Icons.image_not_supported_outlined,
                size: compact ? 16 : 24,
                color: colors.textMuted,
              ),
              SizedBox(height: compact ? 3 : 6),
              Text(
                text.supportChatUnavailableError,
                textAlign: TextAlign.center,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: compact ? 9 : 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkImageAttachmentPreview extends StatefulWidget {
  const _NetworkImageAttachmentPreview({
    required this.imageUrl,
    required this.maxBubbleWidth,
    required this.onTap,
  });

  final String imageUrl;
  final double maxBubbleWidth;
  final VoidCallback? onTap;

  @override
  State<_NetworkImageAttachmentPreview> createState() =>
      _NetworkImageAttachmentPreviewState();
}

class _NetworkImageAttachmentPreviewState
    extends State<_NetworkImageAttachmentPreview> {
  static const int _previewCacheWidth = 720;

  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  late ImageProvider<Object> _imageProvider;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _imageProvider = _buildImageProvider(widget.imageUrl);
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _NetworkImageAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _detachImageListener();
      _aspectRatio = null;
      _imageProvider = _buildImageProvider(widget.imageUrl);
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _detachImageListener();
    super.dispose();
  }

  void _resolveAspectRatio() {
    final stream = _imageProvider.resolve(const ImageConfiguration());
    _imageStream = stream;
    _imageStreamListener = ImageStreamListener((image, _) {
      if (!mounted) {
        return;
      }

      final width = image.image.width.toDouble();
      final height = image.image.height.toDouble();
      if (width <= 0 || height <= 0) {
        return;
      }

      setState(() {
        _aspectRatio = width / height;
      });
    });
    stream.addListener(_imageStreamListener!);
  }

  void _detachImageListener() {
    final listener = _imageStreamListener;
    final stream = _imageStream;
    if (listener != null && stream != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  ImageProvider<Object> _buildImageProvider(String imageUrl) {
    return ResizeImage.resizeIfNeeded(
      _previewCacheWidth,
      null,
      CachedNetworkImageProvider(
        imageUrl,
        cacheKey: persistentSafeSupportMediaUrl(imageUrl),
        maxWidth: _previewCacheWidth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final size = _resolveMediaPreviewSize(
      maxWidth: widget.maxBubbleWidth,
      aspectRatio: _aspectRatio ?? 1,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Image(
            image: _imageProvider,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return ColoredBox(
                color: colors.surface,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colors.textMuted,
                  size: 24,
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return ColoredBox(
                color: colors.surface,
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

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

({double width, double height}) _resolveMediaPreviewSize({
  required double maxWidth,
  required double aspectRatio,
}) {
  final safeAspect = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1;
  const minHeight = 104.0;
  const maxHeight = 260.0;

  final width = maxWidth;
  var height = width / safeAspect;

  height = height.clamp(minHeight, maxHeight).toDouble();
  return (width: width, height: height);
}

class _AttachmentStatusRow extends StatelessWidget {
  const _AttachmentStatusRow({
    required this.status,
    required this.isFromAdmin,
    required this.isRetryEnabled,
    required this.onRetryAttachment,
  });

  final String status;
  final bool isFromAdmin;
  final bool isRetryEnabled;
  final VoidCallback? onRetryAttachment;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final normalized = status.toLowerCase();
    final warningColor = colors.gold;

    final ({Color color, IconData icon, String label}) descriptor =
        switch (normalized) {
          'failed' => (
            color: colors.danger,
            icon: Icons.error_rounded,
            label: text.supportChatAttachmentStatusFailed,
          ),
          'retry' => (
            color: warningColor,
            icon: Icons.refresh_rounded,
            label: text.supportChatAttachmentStatusRetry,
          ),
          _ => (
            color: colors.textMuted,
            icon: Icons.error_outline_rounded,
            label: text.supportChatAttachmentStatusFailed,
          ),
        };

    final textColor = isFromAdmin
        ? descriptor.color
        : Colors.white.withValues(alpha: 0.92);

    return Row(
      children: [
        Icon(descriptor.icon, size: 13, color: textColor),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            descriptor.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (isRetryEnabled && !isFromAdmin)
          TextButton.icon(
            onPressed: onRetryAttachment,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(0, 0),
              foregroundColor: textColor,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 12),
            label: Text(
              text.retryAction,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _SupportAvatar extends StatelessWidget {
  const _SupportAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final avatarTone = _supportSecondaryGreen(context);
    final initial = label.trim().isEmpty ? 'P' : label.trim().substring(0, 1);

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceStrong,
        border: Border.all(color: colors.border),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
            color: avatarTone,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
