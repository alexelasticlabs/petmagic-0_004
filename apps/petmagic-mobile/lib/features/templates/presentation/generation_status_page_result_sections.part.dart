part of 'generation_status_page.dart';

class _ResultCard extends StatefulWidget {
  const _ResultCard({required this.generation, required this.onOpenViewer});

  final TemplateGenerationResult generation;
  final VoidCallback onOpenViewer;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  static const int _aspectRatioProbeCacheWidth = 720;

  ImageStream? _aspectRatioStream;
  ImageStreamListener? _aspectRatioListener;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    if (!isVideoGeneration(widget.generation)) {
      _resolveImageAspectRatio();
    }
  }

  @override
  void didUpdateWidget(covariant _ResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasVideo = isVideoGeneration(oldWidget.generation);
    final isVideo = isVideoGeneration(widget.generation);
    if (oldWidget.generation.outputUrl != widget.generation.outputUrl ||
        oldWidget.generation.localOutputPath !=
            widget.generation.localOutputPath ||
        wasVideo != isVideo) {
      _detachAspectRatioListener();
      _aspectRatio = null;
      if (!isVideo) {
        _resolveImageAspectRatio();
      }
    }
  }

  @override
  void dispose() {
    _detachAspectRatioListener();
    super.dispose();
  }

  void _resolveImageAspectRatio() {
    final localOutputFile = _localMediaFile(widget.generation.localOutputPath);
    late final ImageProvider provider;
    if (localOutputFile != null) {
      provider = ResizeImage(
        FileImage(localOutputFile),
        width: _aspectRatioProbeCacheWidth,
      );
    } else {
      final url = widget.generation.outputUrl ?? '';
      if (url.isEmpty) {
        return;
      }
      final safeUri = parseSafeGenerationMediaUri(url);
      if (safeUri == null) {
        return;
      }
      provider = CachedNetworkImageProvider(
        safeUri.toString(),
        cacheKey: persistentSafeGenerationMediaUrl(safeUri.toString()),
        maxWidth: _aspectRatioProbeCacheWidth,
      );
    }

    final stream = provider.resolve(const ImageConfiguration());
    _aspectRatioStream = stream;
    _aspectRatioListener = ImageStreamListener((info, _) {
      if (!mounted) {
        return;
      }
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h > 0) {
        setState(() => _aspectRatio = w / h);
      }
    }, onError: (error, stackTrace) {});
    stream.addListener(_aspectRatioListener!);
  }

  void _detachAspectRatioListener() {
    final listener = _aspectRatioListener;
    final stream = _aspectRatioStream;
    if (listener != null && stream != null) {
      stream.removeListener(listener);
    }
    _aspectRatioStream = null;
    _aspectRatioListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final outputUrl = widget.generation.outputUrl ?? '';
    final safeMediaUri = parseSafeGenerationMediaUri(outputUrl);
    final safeMediaUrl = safeMediaUri?.toString() ?? '';
    final localOutputFile = _localMediaFile(widget.generation.localOutputPath);
    final isVideo = isVideoGeneration(widget.generation);
    final aspectRatio = _aspectRatio ?? (isVideo ? 9.0 / 16.0 : 3.0 / 4.0);
    final borderRadius = BorderRadius.circular(22);
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceStrong,
          borderRadius: borderRadius,
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: safeMediaUrl.isEmpty ? null : widget.onOpenViewer,
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: safeMediaUrl.isEmpty && localOutputFile == null
                    ? _MediaPlaceholder(
                        label: text.templateFlowResultUnavailable,
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: colors.surfaceStrong,
                            child: isVideo
                                ? _InlineVideoPreview(
                                    url: safeMediaUrl,
                                    localFilePath: localOutputFile?.path,
                                    onAspectRatioResolved: (ar) {
                                      if (mounted) {
                                        setState(() => _aspectRatio = ar);
                                      }
                                    },
                                  )
                                : localOutputFile != null
                                ? Image.file(
                                    localOutputFile,
                                    fit: BoxFit.cover,
                                    cacheWidth: _resultCardImageCacheWidth,
                                    filterQuality: FilterQuality.medium,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: safeMediaUrl,
                                    cacheKey: persistentSafeGenerationMediaUrl(
                                      safeMediaUrl,
                                    ),
                                    fit: BoxFit.cover,
                                    memCacheWidth: _resultCardImageCacheWidth,
                                    maxWidthDiskCache:
                                        _resultCardImageCacheWidth,
                                    filterQuality: FilterQuality.medium,
                                    errorWidget: (context, url, error) =>
                                        _MediaPlaceholder(
                                          label:
                                              text.templateFlowResultLoadFailed,
                                        ),
                                  ),
                          ),
                          const Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 96,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xB5000000),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 14,
                            right: 14,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.52),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.fullscreen_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      text.templateFlowPreviewFallback,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: colors.danger),
              const SizedBox(width: 8),
              Text(
                text.generationStatusFailedTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            failureReasonMessage(text, generation),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            generation.refundedAtUtc != null
                ? text.generationStatusTokensRefundedHint
                : text.generationStatusSupportHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledCard extends StatelessWidget {
  const _CancelledCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_rounded, color: colors.textMuted),
              const SizedBox(width: 8),
              Text(
                text.generationStatusCancelledTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text.generationStatusCancelledMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSoft,
              height: 1.4,
            ),
          ),
          if (generation.refundedAtUtc != null) ...[
            const SizedBox(height: 8),
            Text(
              text.generationStatusTokensRefundedHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadyActionsRow extends StatelessWidget {
  const _ReadyActionsRow({
    required this.onGenerateSimilar,
    required this.onUseAsInput,
    required this.onSave,
    required this.onShare,
    required this.hasWatermark,
    required this.isWatermarkRemoved,
    required this.canRemoveWatermark,
    required this.removeWatermarkCostCredits,
    required this.isRemovingWatermark,
    required this.isGeneratingSimilar,
    required this.onUpgrade,
    this.watermarkMessage,
    this.onRemoveWatermark,
  });

  final VoidCallback? onGenerateSimilar;
  final VoidCallback? onUseAsInput;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final bool hasWatermark;
  final bool isWatermarkRemoved;
  final bool canRemoveWatermark;
  final int removeWatermarkCostCredits;
  final bool isRemovingWatermark;
  final bool isGeneratingSimilar;
  final String? watermarkMessage;
  final VoidCallback? onRemoveWatermark;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final message = watermarkMessage?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null && message.isNotEmpty) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border.withValues(alpha: 0.75)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isWatermarkRemoved
                        ? Icons.verified_rounded
                        : Icons.auto_awesome_motion_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isWatermarkRemoved
                          ? text.generationStatusWatermarkRemoved
                          : hasWatermark
                          ? text.generationStatusWatermarkAddedFreePlan
                          : message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSoft,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: isGeneratingSimilar ? null : onGenerateSimilar,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  isGeneratingSimilar
                      ? _similarLoadingLabel(text)
                      : _similarActionLabel(text),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onUseAsInput,
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                label: Text(_useAsInputLabel(text)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(
                  hasWatermark
                      ? text.generationStatusShareWithWatermark
                      : text.supportChatShareAction,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  isWatermarkRemoved
                      ? text.generationStatusDownloadWithoutWatermark
                      : hasWatermark
                      ? text.generationStatusSaveWithWatermark
                      : text.generationStatusDownloadAction,
                ),
              ),
            ),
          ],
        ),
        if (canRemoveWatermark) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRemovingWatermark ? null : onRemoveWatermark,
                  icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                  label: Text(
                    isRemovingWatermark
                        ? text.generationStatusRemovingWatermark
                        : text.generationStatusRemoveWatermark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: Text(text.generationStatusUpgradePremium),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ResultInputActions extends StatelessWidget {
  const _ResultInputActions({
    required this.onCreateVideo,
    required this.onUseAsInput,
    required this.hasWatermark,
    required this.isWatermarkRemoved,
    this.watermarkMessage,
  });

  final VoidCallback? onCreateVideo;
  final VoidCallback? onUseAsInput;
  final bool hasWatermark;
  final bool isWatermarkRemoved;
  final String? watermarkMessage;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final message = watermarkMessage?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null && message.isNotEmpty) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border.withValues(alpha: 0.75)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isWatermarkRemoved
                        ? Icons.verified_rounded
                        : Icons.auto_awesome_motion_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isWatermarkRemoved
                          ? text.generationStatusWatermarkRemoved
                          : hasWatermark
                          ? text.generationStatusWatermarkAddedFreePlan
                          : message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSoft,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          onPressed: onCreateVideo,
          icon: const Icon(Icons.movie_creation_rounded, size: 18),
          label: Text(text.generationStatusCreateVideoFromResultAction),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onUseAsInput,
          icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
          label: Text(_useAsInputLabel(text)),
        ),
      ],
    );
  }
}

String _similarActionLabel(AppLocalizations text) =>
    text.generationStatusGenerateSimilarAction;

String _similarLoadingLabel(AppLocalizations text) =>
    text.generationStatusGenerateSimilarLoading;

String _useAsInputLabel(AppLocalizations text) =>
    text.generationStatusUseAsInputAction;

class _FailedActions extends StatelessWidget {
  const _FailedActions({
    required this.onPickAnotherPhoto,
    required this.onRetry,
    required this.onSupport,
  });

  final VoidCallback onPickAnotherPhoto;
  final VoidCallback onRetry;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onPickAnotherPhoto,
          child: Text(text.generationStatusPickAnotherPhotoAction),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(text.generationStatusRetryAction),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onSupport,
          child: Text(text.generationStatusContactSupportAction),
        ),
      ],
    );
  }
}

class _ActiveActions extends StatelessWidget {
  const _ActiveActions({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onContinue,
          child: Text(text.generationStatusContinueInAppAction),
        ),
      ],
    );
  }
}

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
  });

  final String url;
  final String? localFilePath;
  final ValueChanged<double>? onAspectRatioResolved;

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
