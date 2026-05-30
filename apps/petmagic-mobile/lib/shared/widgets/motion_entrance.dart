import 'package:flutter/material.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';

class MotionEntrance extends StatefulWidget {
  const MotionEntrance({
    required this.child,
    this.delay = Duration.zero,
    this.duration = PetMotion.medium,
    this.beginOffset = const Offset(0, 12),
    this.beginScale = 0.98,
    this.curve = PetMotion.emphasized,
    this.enabled = false,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;
  final double beginScale;
  final Curve curve;
  final bool enabled;

  @override
  State<MotionEntrance> createState() => _MotionEntranceState();
}

class _MotionEntranceState extends State<MotionEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MotionEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled && widget.enabled) {
      _started = false;
      _startIfNeeded();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startIfNeeded() async {
    if (_started) {
      return;
    }

    if (!widget.enabled || PetMotion.reduceMotion(context)) {
      _controller.value = 1;
      _started = true;
      return;
    }

    _started = true;
    _controller.duration = PetMotion.effectiveDuration(context, widget.duration);

    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
      if (!mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    await _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || PetMotion.reduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final value = _animation.value;
        final dx = widget.beginOffset.dx * (1 - value);
        final dy = widget.beginOffset.dy * (1 - value);
        final scale = widget.beginScale + ((1 - widget.beginScale) * value);

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}
