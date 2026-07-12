part of 'petmagic_shell.dart';

class _ShellTabFadeTransition extends StatefulWidget {
  const _ShellTabFadeTransition({required this.tabIndex, required this.child});

  final int tabIndex;
  final Widget child;

  @override
  State<_ShellTabFadeTransition> createState() =>
      _ShellTabFadeTransitionState();
}

class _ShellTabFadeTransitionState extends State<_ShellTabFadeTransition>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  late final AnimationController _controller;
  late final Animation<double> _animation;
  late int _lastTabIndex;

  @override
  void initState() {
    super.initState();
    _lastTabIndex = widget.tabIndex;
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: 1,
    );
    _animation = CurvedAnimation(parent: _controller, curve: _curve);
  }

  @override
  void didUpdateWidget(covariant _ShellTabFadeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastTabIndex == widget.tabIndex) {
      return;
    }

    _lastTabIndex = widget.tabIndex;
    if (_disableAnimations(context)) {
      _controller.value = 1;
      return;
    }

    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_disableAnimations(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final opacity = 0.82 + (_animation.value * 0.18);
        final translateY = (1 - _animation.value) * 10;
        final scale = 0.992 + (_animation.value * 0.008);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }

  bool _disableAnimations(BuildContext context) {
    return PerformanceGuard.shouldDisableSharedRouteAnimations(context);
  }
}
