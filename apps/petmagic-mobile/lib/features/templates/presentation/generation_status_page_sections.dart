part of 'generation_status_page.dart';

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onBack,
    this.subtitle,
    this.onMenu,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: colors.textStrong,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onMenu != null)
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.more_vert_rounded),
            color: colors.textStrong,
          ),
      ],
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final progress = generation.effectiveProgressPercent;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                generationStatusIcon(generation),
                color: generationStatusColor(colors, generation),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  generation.templateTitle ?? text.generationStatusResultTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusTitle(text, generation),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: generation.isCompleted
                  ? colors.accent
                  : generation.isFailed
                  ? colors.danger
                  : colors.textSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (!generation.isTerminal) ...[
            Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress / 100,
                        strokeWidth: 7,
                        color: generationStatusColor(colors, generation),
                        backgroundColor: colors.border.withValues(alpha: 0.6),
                      ),
                      Center(
                        child: Text(
                          '$progress%',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.textStrong,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    etaLabel(text, generation),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text.generationStatusNonTerminalHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
          ] else if (generation.isCompleted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.accent.withValues(alpha: 0.14),
                    colors.accent.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      terminalHint(text, generation),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSoft,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              terminalHint(text, generation),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return _Panel(
      child: Column(
        children: [
          _StageRow(
            label: text.generationStatusStageQueued,
            done: generation.effectiveProgressPercent >= 10,
          ),
          _StageRow(
            label: text.templateFlowStepProcessPhoto,
            done: generation.effectiveProgressPercent >= 30,
          ),
          _StageRow(
            label: text.templateFlowStepCreateMagic,
            done: generation.effectiveProgressPercent >= 65,
          ),
          _StageRow(
            label: text.templateFlowStepFinalTouches,
            done: generation.effectiveProgressPercent >= 90,
          ),
          _StageRow(
            label: text.generationStatusStageDone,
            done: generation.isCompleted,
          ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? colors.accent : colors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: done ? colors.textStrong : colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final url = widget.generation.outputUrl ?? '';
    if (url.isEmpty) return;
    final safeUri = parseSafeGenerationMediaUri(url);
    if (safeUri == null) return;

    final stream = CachedNetworkImageProvider(
      safeUri.toString(),
      maxWidth: _aspectRatioProbeCacheWidth,
    ).resolve(const ImageConfiguration());
    _aspectRatioStream = stream;
    _aspectRatioListener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h > 0) setState(() => _aspectRatio = w / h);
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
                child: safeMediaUrl.isEmpty
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
                                    onAspectRatioResolved: (ar) {
                                      if (mounted) {
                                        setState(() => _aspectRatio = ar);
                                      }
                                    },
                                  )
                                : CachedNetworkImage(
                                    imageUrl: safeMediaUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 1080,
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

class _BackgroundHintCard extends StatelessWidget {
  const _BackgroundHintCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined, color: colors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.generationStatusBackgroundHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSoft,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyActionsRow extends StatelessWidget {
  const _ReadyActionsRow({required this.onSave, required this.onShare});

  final VoidCallback? onSave;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(text.supportChatShareAction),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(text.generationStatusDownloadAction),
          ),
        ),
      ],
    );
  }
}

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
  const _ActiveActions({required this.onContinue, required this.onCancel});

  final VoidCallback onContinue;
  final VoidCallback onCancel;

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
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onCancel,
          child: Text(text.generationStatusCancelGenerationAction),
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
  const _InlineVideoPreview({required this.url, this.onAspectRatioResolved});

  final String url;
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
    if (oldWidget.url != widget.url) {
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
    controller.setLooping(true);
    controller.setVolume(0);

    try {
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
    } catch (_) {
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

class _FullscreenResultViewer extends StatefulWidget {
  const _FullscreenResultViewer({
    required this.generation,
    required this.mediaUrl,
  });

  final TemplateGenerationResult generation;
  final String mediaUrl;

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
    controller.setLooping(true);

    try {
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
    } catch (_) {
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
      setState(() => _showControls = false);
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
                  : safeMediaUrl == null
                  ? _MediaPlaceholder(label: text.templateFlowResultLoadFailed)
                  : InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: CachedNetworkImage(
                        imageUrl: safeMediaUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: 1440,
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

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.title,
    required this.excellentLabel,
    required this.okayLabel,
    required this.badLabel,
    required this.isSubmitting,
    required this.onRatingSelected,
  });

  final String title;
  final String excellentLabel;
  final String okayLabel;
  final String badLabel;
  final bool isSubmitting;
  final ValueChanged<int> onRatingSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RatingButton(
                label: excellentLabel,
                icon: Icons.favorite_rounded,
                onTap: isSubmitting ? null : () => onRatingSelected(3),
              ),
              const SizedBox(width: 8),
              _RatingButton(
                label: okayLabel,
                icon: Icons.thumb_up_alt_rounded,
                onTap: isSubmitting ? null : () => onRatingSelected(2),
              ),
              const SizedBox(width: 8),
              _RatingButton(
                label: badLabel,
                icon: Icons.sentiment_dissatisfied_rounded,
                onTap: isSubmitting ? null : () => onRatingSelected(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              children: [
                Icon(icon, color: colors.accent, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NegativeFeedbackSheet extends StatefulWidget {
  const _NegativeFeedbackSheet();

  @override
  State<_NegativeFeedbackSheet> createState() => _NegativeFeedbackSheetState();
}

class _NegativeFeedbackSheetState extends State<_NegativeFeedbackSheet> {
  final _commentController = TextEditingController();
  final _selectedReasons = <String>{};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final reasons = <(String, String)>[
      ('pet_not_similar', text.generationStatusFeedbackReasonPetNotSimilar),
      ('face_distorted', text.generationStatusFeedbackReasonFaceDistorted),
      ('strange_motion', text.generationStatusFeedbackReasonStrangeMotion),
      ('preview_mismatch', text.generationStatusFeedbackReasonPreviewMismatch),
      ('low_quality', text.generationStatusFeedbackReasonLowQuality),
      ('style_disliked', text.generationStatusFeedbackReasonStyleDisliked),
      ('other', text.generationStatusFeedbackReasonOther),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundBottom,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text.generationStatusFeedbackImproveTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final reason in reasons)
                      FilterChip(
                        selected: _selectedReasons.contains(reason.$1),
                        label: Text(reason.$2),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedReasons.add(reason.$1);
                            } else {
                              _selectedReasons.remove(reason.$1);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: text.generationStatusFeedbackCommentLabel,
                    hintText: text.generationStatusFeedbackCommentHint,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _FeedbackResult(
                      _selectedReasons.toList(growable: false),
                      _commentController.text.trim().isEmpty
                          ? null
                          : _commentController.text.trim(),
                    ),
                  ),
                  child: Text(text.generationStatusFeedbackSubmitAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
