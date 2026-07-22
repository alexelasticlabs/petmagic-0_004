part of 'generations_gallery_page.dart';

class _GalleryPremiumUpsellCard extends StatelessWidget {
  const _GalleryPremiumUpsellCard({required this.onOpenPremium});

  final VoidCallback onOpenPremium;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accent = colors.gold;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.74)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: PremiumBannerStyle.gradient(isLight),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const PremiumCrownIcon(size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.galleryPremiumUpsellTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    text.galleryPremiumUpsellSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textSoft.withValues(
                        alpha: isLight ? 0.92 : 0.86,
                      ),
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: PremiumShimmerButton(
                label: text.profilePremiumOpenAction,
                onTap: onOpenPremium,
                height: 34,
                borderRadius: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryGoldShimmerButton extends StatefulWidget {
  const _GalleryGoldShimmerButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_GalleryGoldShimmerButton> createState() =>
      _GalleryGoldShimmerButtonState();
}

class _GalleryGoldShimmerButtonState extends State<_GalleryGoldShimmerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
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
    if (!PerformanceGuard.shouldAnimateRepeatingEffects(context)) {
      return _buildButton();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final shimmerStart = -1.6 + (t * 2.8);
        return ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(shimmerStart, -1),
                        end: Alignment(shimmerStart + 0.9, 1),
                        colors: [
                          Colors.transparent,
                          const Color(0xFFFFF3C9).withValues(alpha: 0.0),
                          const Color(0xFFFFF3C9).withValues(alpha: 0.4),
                          const Color(0xFFFFF3C9).withValues(alpha: 0.0),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.30, 0.5, 0.70, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    final colors = context.petMagicColors;
    final backgroundColor = colors.gold;
    final foregroundColor = colors.on(backgroundColor);

    return FilledButton(
      onPressed: widget.onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
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
