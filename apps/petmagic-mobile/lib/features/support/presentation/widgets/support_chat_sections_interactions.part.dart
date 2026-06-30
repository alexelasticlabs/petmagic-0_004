part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _MessageEntranceAnimation extends StatelessWidget {
  const _MessageEntranceAnimation({
    required this.messageId,
    required this.child,
  });

  final String messageId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (PerformanceGuard.isDegradedMode(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('support-message-entrance-$messageId'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, nestedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: nestedChild,
          ),
        );
      },
    );
  }
}

class _SwipeToReplyBubble extends StatefulWidget {
  const _SwipeToReplyBubble({
    required this.enabled,
    required this.onReply,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onReply;
  final Widget child;

  @override
  State<_SwipeToReplyBubble> createState() => _SwipeToReplyBubbleState();
}

class _SwipeToReplyBubbleState extends State<_SwipeToReplyBubble>
    with SingleTickerProviderStateMixin {
  static const _triggerOffset = 52.0;
  static const _maxOffset = 72.0;

  late final AnimationController _animationController;
  Animation<double>? _returnAnimation;
  double _offset = 0;
  bool _replyTriggered = false;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          final animation = _returnAnimation;
          if (animation == null || !mounted) {
            return;
          }
          setState(() {
            _offset = animation.value;
          });
        });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) {
      return;
    }

    _animationController.stop();
    _returnAnimation = null;
    final delta = details.primaryDelta ?? 0;
    final nextOffset = (_offset - delta).clamp(0.0, _maxOffset * 1.2);
    if (nextOffset == _offset) {
      return;
    }

    final shouldTrigger = nextOffset >= _triggerOffset;
    if (shouldTrigger && !_replyTriggered) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _offset = nextOffset;
      _replyTriggered = shouldTrigger;
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) {
      return;
    }

    final shouldReply = _offset >= _triggerOffset;
    _animateBack();
    if (shouldReply) {
      widget.onReply();
    }
  }

  void _handleHorizontalDragCancel() {
    _animateBack();
  }

  void _animateBack() {
    final begin = _offset;
    _replyTriggered = false;
    if (begin <= 0) {
      if (mounted) {
        setState(() {
          _offset = 0;
        });
      }
      return;
    }

    _returnAnimation = Tween<double>(begin: begin, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final revealProgress = (_offset / _triggerOffset).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      onHorizontalDragCancel: _handleHorizontalDragCancel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 90),
                  opacity: revealProgress,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    curve: Curves.easeOut,
                    width: 24 + (revealProgress * 10),
                    height: 24 + (revealProgress * 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent.withValues(
                        alpha: 0.08 + (revealProgress * 0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      size: 16 + (revealProgress * 4),
                      color: colors.accent.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(-_offset, 0), child: widget.child),
        ],
      ),
    );
  }
}
