part of 'petmagic_shell.dart';

class _BottomNavBackdrop extends StatelessWidget {
  const _BottomNavBackdrop();

  @override
  Widget build(BuildContext context) {
    final background = context.petMagicColors.backgroundBottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: petMagicBottomNavInset(context, extraSpacing: 24),
      child: IgnorePointer(
        child: DecoratedBox(
          key: const ValueKey('bottom-nav-backdrop'),
          decoration: BoxDecoration(
            // Fade the feed into the page background. Blurring a full-width
            // strip produced a visible seam on light media.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                background.withValues(alpha: 0),
                background.withValues(alpha: 0.12),
                background.withValues(alpha: 0.64),
                background.withValues(alpha: 0.96),
                background,
              ],
              stops: const [0, 0.22, 0.52, 0.82, 1],
            ),
          ),
        ),
      ),
    );
  }
}
