part of 'petmagic_shell.dart';

class _FloatingBottomNav extends ConsumerWidget {
  const _FloatingBottomNav({
    required this.currentIndex,
    required this.onItemSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isDegraded = PerformanceGuard.isDegradedMode(context);
    final disableGlass = PerformanceGuard.shouldDisableGlassEffects(context);
    final blurSigma = switch ((defaultTargetPlatform, isDegraded)) {
      (TargetPlatform.android, true) => 0.0,
      (TargetPlatform.android, false) => 10.0,
      (_, true) => 10.0,
      _ => 18.0,
    };
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final unreadCount = ref.watch(
      generationHistoryControllerProvider.select((state) => state.unreadCount),
    );
    final items = [
      _NavItem(0, Icons.explore_outlined, text.navDiscover),
      _NavItem(1, Icons.auto_awesome_rounded, text.navCreate, isPrimary: true),
      _NavItem(
        2,
        Icons.photo_library_outlined,
        text.navCreations,
        badgeCount: unreadCount,
      ),
      _NavItem(3, Icons.card_giftcard_rounded, text.navRewards),
      _NavItem(4, Icons.person_outline_rounded, text.navProfile),
    ];
    final navSurface = DecoratedBox(
      decoration: BoxDecoration(
        color: isLight
            ? colors.surfaceGlass.withValues(alpha: isDegraded ? 0.94 : 0.78)
            : Color.alphaBlend(
                Colors.black.withValues(alpha: isDegraded ? 0.40 : 0.30),
                colors.surfaceGlass.withValues(alpha: isDegraded ? 0.78 : 0.56),
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLight
              ? Colors.white.withValues(alpha: 0.74)
              : Colors.white.withValues(alpha: 0.11),
          width: isLight ? 1.1 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 1, 3, 1),
        child: SizedBox(
          height: _bottomNavHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: _BottomNavButton(
                      item: item,
                      selected: currentIndex == item.index,
                      onTap: currentIndex == item.index
                          ? null
                          : () => onItemSelected(item.index),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            bottomPadding + _bottomNavOuterGap,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                top: 1,
                bottom: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: disableGlass
                        ? [
                            BoxShadow(
                              color: colors.shadow.withValues(
                                alpha: isLight ? 0.14 : 0.18,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : isDegraded
                        ? [
                            BoxShadow(
                              color: colors.shadow.withValues(
                                alpha: isLight ? 0.20 : 0.24,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: colors.shadow.withValues(
                                alpha: isLight ? 0.30 : 0.38,
                              ),
                              blurRadius: isLight ? 24 : 22,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isLight ? 0.08 : 0.18,
                              ),
                              blurRadius: 34,
                              offset: const Offset(0, 14),
                            ),
                          ],
                  ),
                ),
              ),
              if (disableGlass)
                navSurface
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: navSurface,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final inactiveColor = Color.lerp(colors.textMuted, colors.textSoft, 0.62)!;
    final isPrimary = item.isPrimary;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: ExcludeSemantics(
        child: PressableScale(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          haptic: PressableScaleHaptic.selection,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isPrimary
                  ? colors.accent.withValues(alpha: selected ? 0.24 : 0.14)
                  : selected
                  ? colors.accent.withValues(alpha: isLight ? 0.26 : 0.1)
                  : Colors.transparent,
              border: selected || isPrimary
                  ? Border.all(
                      color: colors.accent.withValues(
                        alpha: isLight ? 0.48 : 0.08,
                      ),
                      width: isLight ? 1.05 : 1,
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 18,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      DecoratedBox(
                        decoration: isPrimary
                            ? BoxDecoration(
                                color: colors.accent,
                                shape: BoxShape.circle,
                              )
                            : const BoxDecoration(),
                        child: Padding(
                          padding: EdgeInsets.all(isPrimary ? 3 : 0),
                          child: Icon(
                            item.icon,
                            color: isPrimary
                                ? colors.on(colors.accent)
                                : selected
                                ? colors.accent
                                : inactiveColor,
                            size: isPrimary ? 16 : 17,
                          ),
                        ),
                      ),
                      if (item.badgeCount > 0)
                        Positioned(
                          right: 1,
                          top: 0,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? colors.accent : inactiveColor,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.05,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(
    this.index,
    this.icon,
    this.label, {
    this.badgeCount = 0,
    this.isPrimary = false,
  });

  final int index;
  final IconData icon;
  final String label;
  final int badgeCount;
  final bool isPrimary;
}
