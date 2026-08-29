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
    final aspectRatio = _aspectRatio ?? (isVideo ? 9.0 / 16.0 : 2.0 / 3.0);
    final borderRadius = BorderRadius.circular(22);
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceStrong,
          borderRadius: borderRadius,
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
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.danger.withValues(alpha: 0.12),
            border: Border.all(color: colors.danger.withValues(alpha: 0.2)),
          ),
          child: Icon(
            Icons.sentiment_dissatisfied_rounded,
            color: colors.danger,
            size: 50,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          text.generationStatusFailedTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          failureReasonMessage(text, generation),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colors.textMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        _RefundStatus(generation: generation),
      ],
    );
  }
}

class _RefundStatus extends StatelessWidget {
  const _RefundStatus({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final state = generation.refundedAtUtc != null
        ? 'refunded'
        : generation.refundState.toLowerCase();
    final isRefunded = state == 'refunded';
    final isPending = state == 'pending';
    final color = isRefunded
        ? colors.accent
        : isPending
        ? colors.gold
        : colors.danger;
    final icon = isRefunded
        ? Icons.check_circle_rounded
        : isPending
        ? Icons.hourglass_top_rounded
        : Icons.error_outline_rounded;
    final label = isRefunded
        ? text.generationStatusRefundedBalance(generation.tokenCost)
        : isPending
        ? text.generationStatusRefundPending
        : text.generationStatusRefundFailed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isRefunded ? color : colors.textSoft,
                fontWeight: FontWeight.w700,
              ),
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
