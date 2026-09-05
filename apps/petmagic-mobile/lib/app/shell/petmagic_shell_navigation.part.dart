part of 'petmagic_shell.dart';

class _FloatingBottomNav extends ConsumerWidget {
  const _FloatingBottomNav({
    required this.currentIndex,
    required this.isAuthenticated,
    required this.onItemSelected,
  });

  final int currentIndex;
  final bool isAuthenticated;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final disableGlass = PerformanceGuard.shouldDisableGlassEffects(context);
    final unreadCount = isAuthenticated
        ? ref.watch(
            generationHistoryControllerProvider.select(
              (state) => state.unreadCount,
            ),
          )
        : 0;
    final items = [
      _NavItem(
        0,
        Icons.auto_awesome_outlined,
        Icons.auto_awesome_rounded,
        text.navDiscover,
      ),
      _NavItem(
        1,
        Icons.photo_library_outlined,
        Icons.photo_library_rounded,
        text.navCreations,
        badgeCount: unreadCount,
        requiresSignIn: !isAuthenticated,
      ),
      _NavItem(
        2,
        Icons.emoji_events_outlined,
        Icons.emoji_events_rounded,
        text.navRewards,
        requiresSignIn: !isAuthenticated,
      ),
      _NavItem(
        3,
        isAuthenticated ? Icons.person_outline_rounded : Icons.login_rounded,
        isAuthenticated ? Icons.person_rounded : Icons.login_rounded,
        isAuthenticated ? text.navProfile : text.profileSignInAction,
      ),
    ];
    const radius = BorderRadius.all(Radius.circular(24));
    final navSurface = DecoratedBox(
      key: const ValueKey('bottom-nav-surface'),
      decoration: BoxDecoration(
        color: colors.surfaceGlass.withValues(
          alpha: disableGlass ? 1 : (isLight ? 0.94 : 0.92),
        ),
        borderRadius: radius,
        border: Border.all(
          color: colors.border.withValues(alpha: isLight ? 0.75 : 0.9),
        ),
      ),
      child: SizedBox(
        height: petMagicBottomNavHeight(context),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Expanded(
                  child: _BottomNavButton(
                    item: item,
                    selected: currentIndex == item.index,
                    onTap: () => onItemSelected(item.index),
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
            MediaQuery.viewPaddingOf(context).bottom +
                kPetMagicBottomNavOuterGap,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: isLight ? 0.08 : 0.2,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: disableGlass
                    ? navSurface
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: navSurface,
                      ),
              ),
            ),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = selected ? colors.accentInk : colors.textMuted;
    final label = item.badgeCount > 0
        ? '${item.label}, ${text.generationStatusUnreadCount(item.badgeCount)}'
        : item.label;
    final largeText = MediaQuery.textScalerOf(context).scale(11) > 14.3;
    return Semantics(
      key: ValueKey('bottom-nav-item-${item.index}'),
      selected: selected,
      button: true,
      label: label,
      hint: item.requiresSignIn ? text.authSignInRequired : null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: item.requiresSignIn
              ? '${item.label} · ${text.authSignInRequired}'
              : label,
          child: PressableScale(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            haptic: PressableScaleHaptic.selection,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: PerformanceGuard.shouldReduceMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 48,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: selected
                          ? colors.accent.withValues(
                              alpha: isLight ? 0.15 : 0.16,
                            )
                          : Colors.transparent,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          selected ? item.selectedIcon : item.icon,
                          color: foreground,
                          size: 22,
                        ),
                        if (item.requiresSignIn)
                          PositionedDirectional(
                            end: 1,
                            top: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surfaceGlass,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.lock_rounded,
                                  size: 9,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                          )
                        else if (item.badgeCount > 0)
                          PositionedDirectional(
                            end: 5,
                            top: 1,
                            child: Container(
                              key: const ValueKey('bottom-nav-unread'),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.surfaceGlass,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: largeText ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
    this.selectedIcon,
    this.label, {
    this.badgeCount = 0,
    this.requiresSignIn = false,
  });

  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;
  final bool requiresSignIn;
}
