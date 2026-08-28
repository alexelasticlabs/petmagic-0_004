part of 'app_settings_bottom_sheets.dart';

class _ProfileSettingsSheetShell extends StatelessWidget {
  const _ProfileSettingsSheetShell({
    required this.bottomInset,
    required this.child,
    this.horizontalInset = 16,
    this.topInset = 12,
    this.borderRadius = 32,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 12, 20, 16),
  });

  final double bottomInset;
  final Widget child;
  final double horizontalInset;
  final double topInset;
  final double borderRadius;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(padding: contentPadding, child: child),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          topInset,
          horizontalInset,
          bottomInset,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
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
  const _SheetHandle({this.width = 56, this.height = 6});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Center(
      child: Container(
        width: width,
        height: height,
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
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  final Locale locale;
  final String nativeLabel;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: nativeLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? colors.accent.withValues(alpha: 0.13)
              : Colors.transparent,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        flag,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 28,
                      child: Text(
                        locale.languageCode.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? colors.accent : colors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nativeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? colors.textStrong
                              : colors.textSoft,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_rounded, color: colors.accent, size: 22),
                  ],
                ),
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
