import 'package:flutter/material.dart';
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || PetMotion.reduceMotion(context)) {
      return widget.child;
    }

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
              final base =
                  widget.baseColor ??
                  Theme.of(context).dividerColor.withValues(alpha: 0.65);
              final highlight =
                  widget.highlightColor ??
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.32);

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
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.offset);

  final double offset;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(offset, 0, 0);
  }
}
