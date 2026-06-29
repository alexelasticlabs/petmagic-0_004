import 'package:flutter/material.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';

class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    required this.child,
    this.enabled = true,
    this.baseColor,
    this.highlightColor,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Color? _resolvedBaseColor;
  Color? _resolvedHighlightColor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncResolvedColors();
    _syncDuration();
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant ShimmerBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseColor != widget.baseColor ||
        oldWidget.highlightColor != widget.highlightColor ||
        oldWidget.enabled != widget.enabled) {
      _syncResolvedColors();
      _syncDuration();
      _syncAnimationState();
    }
  }

  @override
  void deactivate() {
    _controller.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _syncAnimationState();
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useStaticPlaceholder(context)) {
      return widget.child;
    }

    final base = _resolvedBaseColor ?? const Color(0xA6D0D5DD);
    final highlight = _resolvedHighlightColor ?? const Color(0x52F5F5F5);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final width = bounds.width;
              final offset = (width * 2.2) * _controller.value - width;

              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [base, highlight, base],
                stops: const [0.18, 0.48, 0.82],
                transform: _SlidingGradientTransform(offset),
              ).createShader(bounds);
            },
          );
        },
      ),
    );
  }

  void _syncResolvedColors() {
    final theme = Theme.of(context);
    _resolvedBaseColor =
        widget.baseColor ?? theme.dividerColor.withValues(alpha: 0.65);
    _resolvedHighlightColor =
        widget.highlightColor ??
        theme.colorScheme.surface.withValues(alpha: 0.32);
  }

  void _syncDuration() {
    _controller.duration = PerformanceGuard.isDegradedMode(context)
        ? const Duration(milliseconds: 1900)
        : const Duration(milliseconds: 1400);
  }

  void _syncAnimationState() {
    if (_useStaticPlaceholder(context)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return;
    }

    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  bool _useStaticPlaceholder(BuildContext context) {
    return !widget.enabled ||
        PetMotion.reduceMotion(context) ||
        PerformanceGuard.shouldUseStaticPlaceholders(context);
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.offset);

  final double offset;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(offset, 0, 0);
  }
}
