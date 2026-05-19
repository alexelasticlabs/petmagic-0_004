import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

class PetMagicShell extends StatelessWidget {
  const PetMagicShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          child,
          const _BottomNavBackdrop(),
          _FloatingBottomNav(location: location),
        ],
      ),
    );
  }
}

class _BottomNavBackdrop extends StatelessWidget {
  const _BottomNavBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 110 + bottomPadding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.backgroundBottom.withValues(alpha: 0),
                colors.backgroundBottom.withValues(alpha: 0.24),
                colors.backgroundBottom.withValues(alpha: 0.56),
                colors.backgroundBottom.withValues(alpha: 0.88),
              ],
              stops: const [0, 0.28, 0.62, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final items = [
      _NavItem('/templates', Icons.play_arrow_rounded, text.navTemplates),
      _NavItem('/creations', Icons.photo_library_outlined, text.navCreations),
      _NavItem('/profile', Icons.person_outline_rounded, text.navProfile),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, bottomPadding == 0 ? 18 : 12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              top: 2,
              bottom: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.48),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceGlass.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                    child: SizedBox(
                      height: 50,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in items)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 3,
                                ),
                                child: _BottomNavButton(
                                  item: item,
                                  selected: item.path == '/profile'
                                      ? location.startsWith('/profile')
                                      : location == item.path,
                                  onTap: () => context.go(item.path),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
    final colors = context.petMagicColors;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? colors.accent.withValues(alpha: 0.15)
                : Colors.transparent,
            border: selected
                ? Border.all(color: colors.accent.withValues(alpha: 0.14))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: selected ? colors.accent : colors.textMuted,
                size: 19,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? colors.accent : colors.textMuted,
                  fontSize: 8.8,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.icon, this.label);

  final String path;
  final IconData icon;
  final String label;
}
