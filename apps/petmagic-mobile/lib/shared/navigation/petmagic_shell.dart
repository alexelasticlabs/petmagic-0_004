import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

double petMagicBottomNavInset(BuildContext context) {
  final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
  return bottomPadding == 0 ? 78 : bottomPadding + 66;
}

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
          height: 84 + bottomPadding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.backgroundBottom.withValues(alpha: 0),
                colors.backgroundBottom.withValues(alpha: 0.18),
                colors.backgroundBottom.withValues(alpha: 0.42),
                colors.backgroundBottom.withValues(alpha: 0.74),
              ],
              stops: const [0, 0.34, 0.68, 1],
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
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding == 0 ? 10 : 6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              top: 1,
              bottom: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceGlass.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.12),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(3, 1, 3, 1),
                    child: SizedBox(
                      height: 42,
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
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? colors.accent.withValues(alpha: 0.1)
                : Colors.transparent,
            border: selected
                ? Border.all(color: colors.accent.withValues(alpha: 0.08))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: selected ? colors.accent : colors.textMuted,
                size: 17,
              ),
              const SizedBox(height: 1),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? colors.accent : colors.textMuted,
                  fontSize: 8.1,
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
