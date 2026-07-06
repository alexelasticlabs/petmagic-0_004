part of 'template_flow_sheets.dart';

class _InsufficientBalanceBanner extends StatelessWidget {
  const _InsufficientBalanceBanner({
    required this.templateCost,
    required this.balance,
    required this.showPremiumCta,
    required this.onClose,
    required this.onOpenPremium,
    required this.onTopUpBalance,
    required this.onLater,
  });

  final int templateCost;
  final int balance;
  final bool showPremiumCta;
  final VoidCallback onClose;
  final VoidCallback onOpenPremium;
  final VoidCallback onTopUpBalance;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final rightInset = compact ? 146.0 : 200.0;
        final mascotHeight = compact ? 252.0 : 300.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.gold.withValues(alpha: isLight ? 0.78 : 0.9),
              width: 1.15,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: PremiumBannerStyle.gradient(isLight),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 8,
                top: 6,
                child: IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: colors.textSoft),
                ),
              ),
              Positioned(
                right: -8,
                bottom: -2,
                child: IgnorePointer(
                  child: Image.asset(
                    _kInsufficientBalanceMascotAsset,
                    height: mascotHeight,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 18, rightInset, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.gold.withValues(
                              alpha: isLight ? 0.16 : 0.22,
                            ),
                            border: Border.all(
                              color: colors.gold.withValues(alpha: 0.76),
                            ),
                          ),
                          child: Icon(
                            Icons.bolt_rounded,
                            color: colors.gold,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            text.templateFlowInsufficientBalanceTitle,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.templateFlowInsufficientBalanceUpsellMessage,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text.templateFlowInsufficientBalanceMessage(
                        templateCost,
                        balance,
                      ),
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (showPremiumCta) ...[
                      PremiumShimmerButton(
                        label: text.profilePremiumOpenAction,
                        onTap: onOpenPremium,
                        height: 40,
                      ),
                      const SizedBox(height: 9),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: onTopUpBalance,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.accent, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            text.templateFlowTopUpBalanceAction,
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: onLater,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colors.border.withValues(
                              alpha: isLight ? 0.9 : 0.78,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            text.templateFlowChooseAnotherTemplateAction,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TemplateGoldShimmerButton extends StatefulWidget {
  const _TemplateGoldShimmerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_TemplateGoldShimmerButton> createState() =>
      _TemplateGoldShimmerButtonState();
}

class _TemplateGoldShimmerButtonState extends State<_TemplateGoldShimmerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
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
    final animateShimmer = PerformanceGuard.shouldAnimateRepeatingEffects(
      context,
    );

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE0A91E).withValues(alpha: 0.34),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: animateShimmer
                  ? AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final t = _controller.value;
                        final shimmerStart = -1.6 + (t * 2.8);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFF4C64D),
                                    Color(0xFFEAB13A),
                                  ],
                                ),
                              ),
                              child: child,
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(shimmerStart, -1),
                                      end: Alignment(shimmerStart + 0.9, 1),
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.68),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.23, 0.5, 0.77],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      child: _buildButtonSurface(),
                    )
                  : DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF4C64D), Color(0xFFEAB13A)],
                        ),
                      ),
                      child: _buildButtonSurface(),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonSurface() {
    final foreground = context.petMagicColors.on(const Color(0xFFEAB13A));

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          widget.label,
          style: TextStyle(
            color: foreground,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  void _syncAnimationState() {
    if (!PerformanceGuard.shouldAnimateRepeatingEffects(context)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return;
    }

    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }
}
