part of 'generation_status_page.dart';

const int _resultCardImageCacheWidth = 1080;
const int _resultFullscreenImageCacheWidth = 1440;
const int _beforeAfterCompareImageCacheWidth = 1024;

File? _localMediaFile(String? path) {
  final normalized = path?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final file = File(normalized);
  if (!file.existsSync()) {
    return null;
  }
  return file;
}

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

class _ActiveGenerationCard extends StatelessWidget {
  const _ActiveGenerationCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final progress = generation.effectiveProgressPercent.clamp(0, 100);
    final progressValue = progress / 100;
    final statusColor = generationStatusColor(colors, generation);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceGlass.withValues(alpha: 0.98),
            colors.surfaceStrong.withValues(alpha: 0.86),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.76)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.gold.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ActivePreviewFrame(generation: generation),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StatusBadge(
                              label: statusTitle(text, generation),
                              icon: generationStatusIcon(generation),
                              color: statusColor,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              generation.templateTitle ??
                                  text.generationStatusResultTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.textStrong,
                                    fontWeight: FontWeight.w900,
                                    height: 1.12,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                _MetaPill(
                                  icon: isVideoGeneration(generation)
                                      ? Icons.movie_creation_rounded
                                      : Icons.image_rounded,
                                  label: typeLabel(text, generation),
                                ),
                                _MetaPill(
                                  icon: Icons.bolt_rounded,
                                  label: '${generation.tokenCost} PawSpark',
                                  color: colors.gold,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$progress%',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: colors.textStrong,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            etaLabel(text, generation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colors.textSoft,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _PremiumProgressBar(value: progressValue, color: statusColor),
                  const SizedBox(height: 18),
                  _StageTimeline(generation: generation),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceStrong.withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.gold.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            color: colors.gold,
                            size: 19,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              text.generationStatusBackgroundHint,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.textSoft,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }
}

class _ActivePreviewFrame extends StatelessWidget {
  const _ActivePreviewFrame({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final previewUrl = _activePreviewUrl(generation);
    final localPreviewFile = _localMediaFile(generation.localPreviewPath);
    const size = 104.0;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.gold.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (localPreviewFile != null)
                Image.file(
                  localPreviewFile,
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  filterQuality: FilterQuality.medium,
                )
              else if (previewUrl != null)
                CachedNetworkImage(
                  imageUrl: previewUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 320,
                  maxWidthDiskCache: 320,
                  filterQuality: FilterQuality.medium,
                  errorWidget: (context, url, error) =>
                      _ActivePreviewPlaceholder(label: text.imageLabel),
                )
              else
                _ActivePreviewPlaceholder(label: typeLabel(text, generation)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.62),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 9,
                bottom: 8,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colors.gold,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivePreviewPlaceholder extends StatelessWidget {
  const _ActivePreviewPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong,
            colors.surfaceStrong.withValues(alpha: 0.68),
            colors.gold.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, color: colors.gold, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final tint = color ?? colors.textSoft;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tint, size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumProgressBar extends StatelessWidget {
  const _PremiumProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final clamped = value.clamp(0, 1).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 11,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.border.withValues(alpha: 0.62)),
            FractionallySizedBox(
              widthFactor: clamped,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, colors.gold.withValues(alpha: 0.92)],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: clamped,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
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

class _StageTimeline extends StatelessWidget {
  const _StageTimeline({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final stages = [
      _ActiveStage(
        label: text.generationStatusStageQueued,
        icon: Icons.schedule_rounded,
        threshold: 10,
      ),
      _ActiveStage(
        label: text.templateFlowStepProcessPhoto,
        icon: Icons.photo_filter_rounded,
        threshold: 30,
      ),
      _ActiveStage(
        label: text.templateFlowStepCreateMagic,
        icon: Icons.auto_awesome_rounded,
        threshold: 65,
      ),
      _ActiveStage(
        label: text.templateFlowStepFinalTouches,
        icon: Icons.stars_rounded,
        threshold: 90,
      ),
      _ActiveStage(
        label: text.generationStatusStageDone,
        icon: Icons.check_rounded,
        threshold: 100,
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < stages.length; index++)
          _TimelineRow(
            stage: stages[index],
            generation: generation,
            isLast: index == stages.length - 1,
          ),
      ],
    );
  }
}

class _ActiveStage {
  const _ActiveStage({
    required this.label,
    required this.icon,
    required this.threshold,
  });

  final String label;
  final IconData icon;
  final int threshold;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.stage,
    required this.generation,
    required this.isLast,
  });

  final _ActiveStage stage;
  final TemplateGenerationResult generation;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final progress = generation.effectiveProgressPercent;
    final isDone = progress >= stage.threshold || generation.isCompleted;
    final isActive = !generation.isCompleted && _isCurrentStage(generation);
    final tint = isDone
        ? colors.accent
        : isActive
        ? colors.gold
        : colors.textMuted;

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: isDone || isActive ? 0.16 : 0),
                  border: Border.all(
                    color: tint.withValues(
                      alpha: isDone || isActive ? 0.42 : 0.30,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isDone ? Icons.check_rounded : stage.icon,
                    color: tint,
                    size: 15,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: (isDone ? colors.accent : colors.border).withValues(
                      alpha: isDone ? 0.44 : 0.72,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 11, top: 1),
              child: Text(
                stage.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDone || isActive
                      ? colors.textStrong
                      : colors.textMuted,
                  fontWeight: isDone || isActive
                      ? FontWeight.w800
                      : FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentStage(TemplateGenerationResult generation) {
    final stageValue = generation.stage;
    if (stageValue == null || stageValue.isEmpty) {
      final progress = generation.effectiveProgressPercent;
      return progress < stage.threshold && progress >= stage.threshold - 25;
    }

    return switch (stageValue) {
      'queued' => stage.threshold == 10,
      'preprocessing' || 'processing' => stage.threshold == 30,
      'generating' => stage.threshold == 65,
      'finalizing' => stage.threshold == 90,
      _ => false,
    };
  }
}

String? _activePreviewUrl(TemplateGenerationResult generation) {
  for (final candidate in [
    generation.inputPreviewUrl,
    generation.sourceImageAsset?.url,
    generation.normalizedImageUrl,
    generation.resultPreviewUrl,
    generation.outputUrl,
  ]) {
    final value = candidate?.trim();
    if (value == null || value.isEmpty) {
      continue;
    }

    final safeUri = parseSafeGenerationMediaUri(value);
    if (safeUri != null) {
      return safeUri.toString();
    }
  }

  return null;
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
        maxWidth: _aspectRatioProbeCacheWidth,
      );
    }

    final stream = provider.resolve(const ImageConfiguration());
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
      await controller.setLooping(true);
      await controller.setVolume(0);
      await _initializeController(requestVersion, url, controller);
      return;
    }

    final controller = VideoPlayerController.file(localFile);
    _controller = controller;
    await controller.setLooping(true);
    await controller.setVolume(0);
    await _initializeController(requestVersion, url, controller);
  }

  Future<void> _initializeController(
    int requestVersion,
    String url,
    VideoPlayerController controller,
  ) async {
    if (_controller != controller) {
      return;
    }

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
