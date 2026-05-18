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
          height: 104 + bottomPadding,
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
        padding: EdgeInsets.fromLTRB(18, 0, 18, bottomPadding == 0 ? 10 : 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceGlass.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.72),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (final item in items)
                        Expanded(
                          child: Center(
                            child: _BottomNavButton(
                              item: item,
                              selected: location == item.path,
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? colors.accent.withValues(alpha: 0.15)
                : Colors.transparent,
            border: selected
                ? Border.all(color: colors.accent.withValues(alpha: 0.14))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: selected ? colors.accent : colors.textMuted,
                size: 20,
              ),
              const SizedBox(height: 1),
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
