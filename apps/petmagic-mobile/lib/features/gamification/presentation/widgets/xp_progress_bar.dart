import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';

class XpProgressBar extends StatelessWidget {
  const XpProgressBar({
    super.key,
    required this.currentXp,
    required this.xpForCurrentLevel,
    required this.xpForNextLevel,
    required this.level,
    required this.evolutionStage,
    this.height = 12,
    this.showLabels = true,
  });

  final int currentXp;
  final int xpForCurrentLevel;
  final int xpForNextLevel;
  final int level;
  final String evolutionStage;
  final double height;
  final bool showLabels;

  static List<Color> gradientForStage(String stage) {
    switch (stage) {
      case 'baby':
        return const [Color(0xFF4CAF50), Color(0xFF66BB6A)];
      case 'teen':
        return const [Color(0xFF42A5F5), Color(0xFF5C6BC0)];
      case 'adult':
        return const [Color(0xFFAB47BC), Color(0xFF7E57C2)];
      case 'legendary':
        return const [Color(0xFFFFD700), Color(0xFFFFA000)];
      default:
        return const [Color(0xFF9E9E9E), Color(0xFFBDBDBD)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final range = xpForNextLevel - xpForCurrentLevel;
    final progress = range > 0
        ? ((currentXp - xpForCurrentLevel) / range).clamp(0.0, 1.0)
        : 1.0;

    final gradientColors = gradientForStage(evolutionStage);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabels)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                _LevelBadge(level: level, evolutionStage: evolutionStage),
                const Spacer(),
                Text(
                  '$currentXp / $xpForNextLevel XP',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSoft,
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: colors.surfaceStrong.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(gradientColors.last),
              minHeight: height,
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.evolutionStage});

  final int level;
  final String evolutionStage;

  @override
  Widget build(BuildContext context) {
    final stageColors = XpProgressBar.gradientForStage(evolutionStage);
    final foreground = context.petMagicColors.on(stageColors.last);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: stageColors,
        ),
        boxShadow: [
          BoxShadow(
            color: stageColors.last.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$level',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class EvolutionBadge extends StatefulWidget {
  const EvolutionBadge({
    super.key,
    required this.evolutionStage,
    required this.level,
    this.size = 48,
    this.showGlow = true,
  });

  final String evolutionStage;
  final int level;
  final double size;
  final bool showGlow;

  @override
  State<EvolutionBadge> createState() => _EvolutionBadgeState();
}

class _EvolutionBadgeState extends State<EvolutionBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(EvolutionBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimationState();
  }

  @override
  void dispose() {
    _glowController.stop();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stageEmoji = _emojiForStage(widget.evolutionStage);
    final stageColor = XpProgressBar.gradientForStage(widget.evolutionStage);

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowOpacity = widget.showGlow && widget.evolutionStage != 'egg'
            ? 0.3 + (_glowController.value * 0.3)
            : 0.0;

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: stageColor.last.withValues(alpha: 0.15),
            boxShadow: [
              if (widget.showGlow && widget.evolutionStage != 'egg')
                BoxShadow(
                  color: stageColor.last.withValues(alpha: glowOpacity),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            stageEmoji,
            style: TextStyle(fontSize: widget.size * 0.5),
          ),
        );
      },
    );
  }

  void _syncAnimationState() {
    final shouldAnimate =
        widget.showGlow &&
        widget.evolutionStage != 'egg' &&
        PerformanceGuard.shouldAnimateRepeatingEffects(context);
    if (!shouldAnimate) {
      _glowController.stop();
      return;
    }

    if (!_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    }
  }
}

String _emojiForStage(String stage) {
  switch (stage) {
    case 'baby':
      return '🐣';
    case 'teen':
      return '🐱';
    case 'adult':
      return '🦁';
    case 'legendary':
      return '🐉';
    default:
      return '🥚';
  }
}
