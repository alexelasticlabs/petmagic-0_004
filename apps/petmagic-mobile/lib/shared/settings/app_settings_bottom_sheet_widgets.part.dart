part of 'app_settings_bottom_sheets.dart';

class _ProfileSettingsSheetShell extends StatelessWidget {
  const _ProfileSettingsSheetShell({
    required this.bottomInset,
    required this.child,
  });

  final double bottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: child,
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: PerformanceGuard.shouldAvoidBlur(context)
              ? content
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: content,
                ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Center(
      child: Container(
        width: 56,
        height: 6,
        decoration: BoxDecoration(
          color: colors.border.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.locale,
    required this.nativeLabel,
    required this.isSelected,
    required this.onTap,
  });

  final Locale locale;
  final String nativeLabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colors.accent.withValues(alpha: 0.6)
                : colors.border.withValues(alpha: 0.76),
          ),
          color: isSelected
              ? colors.accentSoft.withValues(alpha: 0.26)
              : colors.surfaceGlass.withValues(alpha: 0.34),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: isSelected
                          ? colors.accent.withValues(alpha: 0.2)
                          : colors.surfaceStrong.withValues(alpha: 0.52),
                    ),
                    child: Text(
                      locale.languageCode.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? colors.accent : colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nativeLabel,
                      style: TextStyle(
                        color: isSelected ? colors.textStrong : colors.textSoft,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? colors.accent : colors.textMuted,
                    size: 21,
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

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colors.accent.withValues(alpha: 0.56)
                  : colors.border.withValues(alpha: 0.62),
            ),
            color: isSelected
                ? colors.accent.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colors.accent : colors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? colors.accent : colors.textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSameLocale(Locale left, Locale right) {
  return left.languageCode == right.languageCode &&
      (left.countryCode ?? '') == (right.countryCode ?? '');
}
