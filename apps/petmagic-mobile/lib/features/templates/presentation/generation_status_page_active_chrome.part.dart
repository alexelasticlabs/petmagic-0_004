part of 'generation_status_page.dart';

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

class _GenerationProgressBar extends StatelessWidget {
  const _GenerationProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 1).toDouble();
    final Widget progressFill;
    if (PetMotion.reduceMotion(context)) {
      progressFill = _GenerationProgressFill(value: clamped);
    } else {
      progressFill = TweenAnimationBuilder<double>(
        tween: Tween<double>(end: clamped),
        duration: PetMotion.medium,
        curve: PetMotion.emphasized,
        builder: (context, animatedValue, _) {
          return _GenerationProgressFill(value: animatedValue);
        },
      );
    }

    return Semantics(
      value: '${(clamped * 100).round()}%',
      child: ExcludeSemantics(child: progressFill),
    );
  }
}

class _GenerationProgressFill extends StatelessWidget {
  const _GenerationProgressFill({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 11,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.border.withValues(alpha: 0.62)),
            FractionallySizedBox(
              widthFactor: value,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.accent.withValues(alpha: 0.82),
                      colors.accent,
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
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
        label: text.generationStatusPhotoReceived,
        icon: Icons.check_rounded,
      ),
      _ActiveStage(
        label: text.generationStatusCreatingImage,
        icon: Icons.auto_awesome_rounded,
      ),
      _ActiveStage(
        label: text.templateFlowStepFinalTouches,
        icon: Icons.stars_rounded,
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < stages.length; index++)
          _TimelineRow(
            stage: stages[index],
            stageIndex: index,
            generation: generation,
            isLast: index == stages.length - 1,
          ),
      ],
    );
  }
}

class _ActiveStage {
  const _ActiveStage({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.stage,
    required this.stageIndex,
    required this.generation,
    required this.isLast,
  });

  final _ActiveStage stage;
  final int stageIndex;
  final TemplateGenerationResult generation;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final currentStage = _activeGenerationStageIndex(generation);
    final isDone = generation.isCompleted || stageIndex < currentStage;
    final isActive = !generation.isCompleted && stageIndex == currentStage;
    final tint = isDone
        ? colors.accent
        : isActive
        ? colors.accent
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
}

int _activeGenerationStageIndex(TemplateGenerationResult generation) {
  if (generation.isCompleted) {
    return 3;
  }

  final stage = generation.stage?.trim();
  if (stage == 'finalizing' ||
      stage == 'importingMedia' ||
      generation.status == TemplateGenerationStatus.finalizing ||
      generation.status == TemplateGenerationStatus.importingMedia ||
      generation.status == TemplateGenerationStatus.cancellationRequested) {
    return 2;
  }

  return 1;
}

double _stageProgressValue(TemplateGenerationResult generation) {
  return switch (_activeGenerationStageIndex(generation)) {
    0 => 0.2,
    1 => 0.48,
    2 => 0.78,
    _ => 1,
  };
}
