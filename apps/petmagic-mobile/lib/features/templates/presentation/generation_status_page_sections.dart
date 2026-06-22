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
    final isRu = text.localeName.startsWith('ru');
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
          label: Text(
            isRu ? 'Создать видео из этого' : 'Create video from this',
          ),
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
    text.localeName.startsWith('ru') ? 'Похожий вариант' : 'Generate similar';

String _similarLoadingLabel(AppLocalizations text) =>
    text.localeName.startsWith('ru')
    ? 'Создаём похожий вариант...'
    : 'Creating a similar version...';

String _useAsInputLabel(AppLocalizations text) =>
    text.localeName.startsWith('ru') ? 'Взять за основу' : 'Use as input';

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
      await controller.setLooping(true);
      await _initializeFullscreenVideo(requestVersion, mediaUrl, controller);
      return;
    }

    final controller = VideoPlayerController.file(localFile);
    _videoController = controller;
    await controller.setLooping(true);
    await _initializeFullscreenVideo(requestVersion, mediaUrl, controller);
  }

  Future<void> _initializeFullscreenVideo(
    int requestVersion,
    String mediaUrl,
    VideoPlayerController controller,
  ) async {
    if (_videoController != controller) {
      return;
    }

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
      maxWidth: _beforeAfterCompareImageCacheWidth,
    );
    _afterProvider = CachedNetworkImageProvider(
      widget.afterUrl,
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
                                              child: const Icon(
                                                Icons.drag_indicator_rounded,
                                                color: Color(0xFF1F2937),
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

class _FailedFeedbackCard extends StatelessWidget {
  const _FailedFeedbackCard({
    required this.isSubmitting,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = _feedbackText(context);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.failedTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in text.failedReasons)
                ActionChip(
                  label: Text(reason.$2),
                  onPressed: isSubmitting ? null : () => onSubmit(reason.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProblemFeedbackSheet extends StatefulWidget {
  const _ProblemFeedbackSheet({required this.title, required this.reasons});

  final String title;
  final List<(String, String)> reasons;

  @override
  State<_ProblemFeedbackSheet> createState() => _ProblemFeedbackSheetState();
}

class _ProblemFeedbackSheetState extends State<_ProblemFeedbackSheet> {
  final _commentController = TextEditingController();
  String? _selectedReason;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = _feedbackText(context);
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
                  widget.title,
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
                    for (final reason in widget.reasons)
                      ChoiceChip(
                        selected: _selectedReason == reason.$1,
                        label: Text(reason.$2),
                        onSelected: (_) =>
                            setState(() => _selectedReason = reason.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: text.commentLabel,
                    hintText: text.commentHint,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _selectedReason == null
                      ? null
                      : () => Navigator.of(context).pop(
                          _FeedbackResult(
                            [_selectedReason!],
                            _commentController.text.trim().isEmpty
                                ? null
                                : _commentController.text.trim(),
                          ),
                        ),
                  child: Text(text.submit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackText {
  const _FeedbackText({
    required this.failedTitle,
    required this.failedReasons,
    required this.reportTitle,
    required this.reportReasons,
    required this.commentLabel,
    required this.commentHint,
    required this.submit,
  });

  final String failedTitle;
  final List<(String, String)> failedReasons;
  final String reportTitle;
  final List<(String, String)> reportReasons;
  final String commentLabel;
  final String commentHint;
  final String submit;
}

_FeedbackText _feedbackText(BuildContext context) {
  final isRu = AppLocalizations.of(context).localeName.startsWith('ru');
  if (isRu) {
    return const _FeedbackText(
      failedTitle: 'Что произошло?',
      failedReasons: [
        ('not_completed', 'Не завершилась'),
        ('too_long', 'Слишком долго'),
        ('credits_charged', 'Списались credits'),
        ('stuck', 'Зависло'),
        ('other', 'Другое'),
      ],
      reportTitle: 'Что не так с результатом?',
      reportReasons: [
        ('low_quality', 'Плохое качество'),
        ('wrong_pet', 'Не тот питомец'),
        ('distortion', 'Искажение'),
        ('inappropriate', 'Неподходящий'),
        ('wrong_template', 'Не тот шаблон'),
        ('watermark', 'Watermark'),
        ('payment', 'Оплата'),
        ('other', 'Другое'),
      ],
      commentLabel: 'Комментарий',
      commentHint: 'Можно оставить пустым',
      submit: 'Отправить',
    );
  }

  return const _FeedbackText(
    failedTitle: 'What happened?',
    failedReasons: [
      ('not_completed', 'Did not finish'),
      ('too_long', 'Too long'),
      ('credits_charged', 'Credits charged'),
      ('stuck', 'Stuck'),
      ('other', 'Other'),
    ],
    reportTitle: 'What is wrong with the result?',
    reportReasons: [
      ('low_quality', 'Low quality'),
      ('wrong_pet', 'Wrong pet'),
      ('distortion', 'Distortion'),
      ('inappropriate', 'Inappropriate'),
      ('wrong_template', 'Wrong template'),
      ('watermark', 'Watermark'),
      ('payment', 'Payment'),
      ('other', 'Other'),
    ],
    commentLabel: 'Comment',
    commentHint: 'Optional',
    submit: 'Send',
  );
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
