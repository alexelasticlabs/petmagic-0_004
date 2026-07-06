part of 'generation_status_page.dart';

class _BeforeAfterCompareViewer extends StatefulWidget {
  const _BeforeAfterCompareViewer({
    required this.generation,
    required this.beforeUrl,
    required this.afterUrl,
    this.onViewed,
    this.onSliderMoved,
    this.onClosed,
    this.onShare,
  });

  final TemplateGenerationResult generation;
  final String beforeUrl;
  final String afterUrl;
  final Future<void> Function()? onViewed;
  final Future<void> Function()? onSliderMoved;
  final Future<void> Function()? onClosed;
  final Future<void> Function()? onShare;

  @override
  State<_BeforeAfterCompareViewer> createState() =>
      _BeforeAfterCompareViewerState();
}

class _BeforeAfterCompareViewerState extends State<_BeforeAfterCompareViewer> {
  static const double _handleSize = 42;

  ImageStream? _beforeStream;
  ImageStreamListener? _beforeListener;
  ImageStream? _afterStream;
  ImageStreamListener? _afterListener;
  ImageProvider<Object>? _beforeProvider;
  ImageProvider<Object>? _afterProvider;
  double? _beforeAspectRatio;
  double? _afterAspectRatio;
  bool _beforeLoaded = false;
  bool _afterLoaded = false;
  bool _beforeFailed = false;
  bool _afterFailed = false;
  bool _trackedSliderMove = false;
  bool _triggeredHaptic = false;
  double _sliderPosition = 0.5;

  @override
  void initState() {
    super.initState();
    _beforeProvider = CachedNetworkImageProvider(
      widget.beforeUrl,
      cacheKey: persistentSafeGenerationMediaUrl(widget.beforeUrl),
      maxWidth: _beforeAfterCompareImageCacheWidth,
    );
    _afterProvider = CachedNetworkImageProvider(
      widget.afterUrl,
      cacheKey: persistentSafeGenerationMediaUrl(widget.afterUrl),
      maxWidth: _beforeAfterCompareImageCacheWidth,
    );
    _attachBeforeListener();
    _attachAfterListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(widget.onViewed?.call());
    });
  }

  @override
  void dispose() {
    _detachBeforeListener();
    _detachAfterListener();
    unawaited(widget.onClosed?.call());
    super.dispose();
  }

  void _attachBeforeListener() {
    final provider = _beforeProvider;
    if (provider == null) {
      return;
    }

    final stream = provider.resolve(const ImageConfiguration());
    _beforeStream = stream;
    _beforeListener = ImageStreamListener(
      (info, _) {
        if (!mounted) {
          return;
        }
        final aspectRatio = info.image.height == 0
            ? null
            : info.image.width / info.image.height;
        setState(() {
          _beforeLoaded = true;
          _beforeFailed = false;
          _beforeAspectRatio = aspectRatio;
        });
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!mounted) {
          return;
        }
        setState(() {
          _beforeFailed = true;
        });
      },
    );
    stream.addListener(_beforeListener!);
  }

  void _attachAfterListener() {
    final provider = _afterProvider;
    if (provider == null) {
      return;
    }

    final stream = provider.resolve(const ImageConfiguration());
    _afterStream = stream;
    _afterListener = ImageStreamListener(
      (info, _) {
        if (!mounted) {
          return;
        }
        final aspectRatio = info.image.height == 0
            ? null
            : info.image.width / info.image.height;
        setState(() {
          _afterLoaded = true;
          _afterFailed = false;
          _afterAspectRatio = aspectRatio;
        });
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!mounted) {
          return;
        }
        setState(() {
          _afterFailed = true;
        });
      },
    );
    stream.addListener(_afterListener!);
  }

  void _detachBeforeListener() {
    final listener = _beforeListener;
    final stream = _beforeStream;
    if (listener != null && stream != null) {
      stream.removeListener(listener);
    }
    _beforeListener = null;
    _beforeStream = null;
  }

  void _detachAfterListener() {
    final listener = _afterListener;
    final stream = _afterStream;
    if (listener != null && stream != null) {
      stream.removeListener(listener);
    }
    _afterListener = null;
    _afterStream = null;
  }

  void _handleDragUpdate(DragUpdateDetails details, double width) {
    if (!_triggeredHaptic) {
      _triggeredHaptic = true;
      unawaited(PetMagicHaptics.light());
    }
    if (!_trackedSliderMove) {
      _trackedSliderMove = true;
      unawaited(widget.onSliderMoved?.call());
    }

    final next = (details.localPosition.dx / width).clamp(0.0, 1.0);
    setState(() {
      _sliderPosition = next;
    });
  }

  BoxFit _resolveImageFit() {
    final before = _beforeAspectRatio;
    final after = _afterAspectRatio;
    if (before == null || after == null) {
      return BoxFit.contain;
    }

    return (before - after).abs() <= 0.14 ? BoxFit.cover : BoxFit.contain;
  }

  double _resolveContainerAspectRatio() {
    final before = _beforeAspectRatio;
    final after = _afterAspectRatio;
    if (before != null && after != null) {
      return ((before + after) / 2).clamp(0.6, 1.8);
    }
    return (before ?? after ?? 1).clamp(0.6, 1.8);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final fit = _resolveImageFit();
    final aspectRatio = _resolveContainerAspectRatio();
    final isReady = _beforeLoaded && _afterLoaded;
    final errorMessage = _beforeFailed
        ? text.generationStatusCompareBeforeUnavailable
        : _afterFailed
        ? text.generationStatusCompareResultUnavailable
        : null;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textStrong,
                  ),
                  Expanded(
                    child: Text(
                      widget.generation.templateTitle ??
                          text.generationStatusCompareAction,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onShare == null
                        ? null
                        : () => unawaited(widget.onShare!.call()),
                    icon: const Icon(Icons.share_rounded),
                    color: colors.textStrong,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceStrong,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.7),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: errorMessage != null
                            ? _MediaPlaceholder(label: errorMessage)
                            : !isReady
                            ? const _CompareViewerSkeleton()
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  final sliderX = width * _sliderPosition;
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragUpdate: (details) =>
                                        _handleDragUpdate(details, width),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _CompareImageLayer(
                                          provider: _afterProvider!,
                                          fit: fit,
                                        ),
                                        ClipRect(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: _sliderPosition,
                                            child: SizedBox(
                                              width: constraints.maxWidth,
                                              height: constraints.maxHeight,
                                              child: _CompareImageLayer(
                                                provider: _beforeProvider!,
                                                fit: fit,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 14,
                                          left: 14,
                                          child: _ComparePillLabel(
                                            label: text
                                                .generationStatusCompareBeforeLabel,
                                          ),
                                        ),
                                        Positioned(
                                          top: 14,
                                          right: 14,
                                          child: _ComparePillLabel(
                                            label: text
                                                .generationStatusCompareAfterLabel,
                                          ),
                                        ),
                                        Positioned(
                                          left: sliderX - 1.25,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 2.5,
                                            color: Colors.white.withValues(
                                              alpha: 0.92,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: sliderX - (_handleSize / 2),
                                          top:
                                              (constraints.maxHeight / 2) -
                                              (_handleSize / 2),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.2),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 10),
                                                ),
                                              ],
                                            ),
                                            child: SizedBox(
                                              width: _handleSize,
                                              height: _handleSize,
                                              child: Icon(
                                                Icons.drag_indicator_rounded,
                                                color: context.petMagicColors
                                                    .on(Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareImageLayer extends StatelessWidget {
  const _CompareImageLayer({required this.provider, required this.fit});

  final ImageProvider<Object> provider;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.petMagicColors.surfaceStrong,
      child: Image(
        image: provider,
        fit: fit,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _ComparePillLabel extends StatelessWidget {
  const _ComparePillLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CompareViewerSkeleton extends StatelessWidget {
  const _CompareViewerSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x1AFFFFFF), Color(0x08FFFFFF), Color(0x14000000)],
        ),
      ),
      child: const Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
