part of 'subscription_management_page.dart';

class _TokenGrantProgressBar extends StatefulWidget {
  const _TokenGrantProgressBar({
    required this.nextGrantUtc,
    required this.weeklyGrantAmount,
  });

  final DateTime? nextGrantUtc;
  final int weeklyGrantAmount;

  @override
  State<_TokenGrantProgressBar> createState() => _TokenGrantProgressBarState();
}

class _TokenGrantProgressBarState extends State<_TokenGrantProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _progressAnim;
  Timer? _ticker;
  DateTime _now = DateTime.now().toUtc();

  double get _currentProgress {
    final next = widget.nextGrantUtc;
    if (next == null) {
      return 0.0;
    }
    final prev = next.subtract(const Duration(days: 7));
    final total = const Duration(days: 7).inSeconds;
    final elapsed = _now.difference(prev).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: _currentProgress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _controller.forward();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now().toUtc());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  String _buildCountdown(AppLocalizations text) {
    final next = widget.nextGrantUtc;
    if (next == null) {
      return '';
    }
    final diff = next.difference(_now);
    if (diff.isNegative) {
      return '';
    }
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (d > 0) {
      return text.subscriptionGrantCountdownDaysHoursMinutes(d, h, m);
    }
    if (h > 0) {
      return text.subscriptionGrantCountdownHoursMinutesSeconds(h, m, s);
    }
    return text.subscriptionGrantCountdownMinutesSeconds(m, s);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final p = _controller.isCompleted ? _currentProgress : _progressAnim.value;
    final countdown = _buildCountdown(text);
    final isReady =
        widget.nextGrantUtc != null && _now.isAfter(widget.nextGrantUtc!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final fillW = (w * p).clamp(0.0, w);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: fillW,
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accent, colors.gold],
                      ),
                    ),
                  ),
                ),
                if (fillW > 6)
                  Positioned(
                    left: fillW - 6,
                    top: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.gold,
                        boxShadow: [
                          BoxShadow(
                            color: colors.gold.withValues(alpha: 0.55),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isReady)
              Text(
                text.subscriptionGrantReadyLabel,
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (countdown.isNotEmpty)
              Text(
                text.subscriptionGrantNextLabel(countdown),
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              const SizedBox.shrink(),
            Text(
              '${(p * 100).round()}%',
              style: TextStyle(
                color: colors.accent.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
