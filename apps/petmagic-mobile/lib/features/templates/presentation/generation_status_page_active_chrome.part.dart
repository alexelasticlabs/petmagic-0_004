part of 'generation_status_page.dart';

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
      'submittingToProvider' || 'providerQueued' => stage.threshold == 10,
      'preprocessing' || 'processing' => stage.threshold == 30,
      'providerProcessing' => stage.threshold == 65,
      'generating' => stage.threshold == 65,
      'finalizing' || 'importingMedia' => stage.threshold == 90,
      _ => false,
    };
  }
}
