part of 'auth_entry_page.dart';

class _TermsConsentOption extends StatelessWidget {
  const _TermsConsentOption({
    required this.value,
    required this.label,
    required this.enabled,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    required this.onChanged,
    this.showError = false,
  });

  final bool value;
  final String label;
  final bool enabled;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;
  final ValueChanged<bool?> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final split = _ConsentLabelSplit.tryParse(
      label: label,
      termsText: text.authTermsLinkText,
      privacyText: text.authPrivacyLinkText,
    );
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: enabled ? colors.textStrong : colors.textMuted,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.34,
    );
    final linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: enabled ? colors.accent : colors.textMuted,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      height: 1.34,
      decoration: TextDecoration.underline,
      decorationColor: (enabled ? colors.accent : colors.textMuted).withValues(
        alpha: 0.7,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: value
              ? colors.accent.withValues(alpha: isDark ? 0.09 : 0.11)
              : colors.surfaceGlass.withValues(alpha: isDark ? 0.54 : 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showError
                ? colors.danger.withValues(alpha: 0.48)
                : value
                ? colors.accent.withValues(alpha: 0.52)
                : colors.border.withValues(alpha: isDark ? 0.58 : 0.62),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 5, 10, 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: colors.accent,
              checkColor: Theme.of(context).colorScheme.onPrimary,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(
                color: showError
                    ? colors.danger.withValues(alpha: 0.72)
                    : colors.border.withValues(alpha: 0.86),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: split == null
                    ? Text(label, style: textStyle)
                    : Wrap(
                        children: [
                          Text(split.prefix, style: textStyle),
                          _InlineLegalLink(
                            key: const ValueKey('auth_terms_link'),
                            text: split.terms,
                            style: linkStyle,
                            onTap: onOpenTerms,
                          ),
                          Text(split.between, style: textStyle),
                          _InlineLegalLink(
                            key: const ValueKey('auth_privacy_link'),
                            text: split.privacy,
                            style: linkStyle,
                            onTap: onOpenPrivacy,
                          ),
                          Text(split.suffix, style: textStyle),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketingConsentOption extends StatelessWidget {
  const _MarketingConsentOption({
    required this.value,
    required this.title,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: colors.accent,
                checkColor: Theme.of(context).colorScheme.onPrimary,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: colors.border.withValues(alpha: 0.86),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalStateLine extends StatelessWidget {
  const _LegalStateLine({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isError
            ? colors.danger.withValues(alpha: isDark ? 0.1 : 0.07)
            : colors.surfaceGlass.withValues(alpha: isDark ? 0.46 : 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? colors.danger.withValues(alpha: 0.2)
              : colors.border.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: isError
                  ? colors.danger.withValues(alpha: 0.86)
                  : colors.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isError
                    ? colors.danger.withValues(alpha: isDark ? 0.92 : 0.86)
                    : colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLegalLink extends StatelessWidget {
  const _InlineLegalLink({
    super.key,
    required this.text,
    required this.style,
    required this.onTap,
  });

  final String text;
  final TextStyle? style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        visualDensity: VisualDensity.compact,
        textStyle: style,
      ),
      child: Text(text, style: style),
    );
  }
}

class _ConsentLabelSplit {
  const _ConsentLabelSplit({
    required this.prefix,
    required this.terms,
    required this.between,
    required this.privacy,
    required this.suffix,
  });

  final String prefix;
  final String terms;
  final String between;
  final String privacy;
  final String suffix;

  static _ConsentLabelSplit? tryParse({
    required String label,
    required String termsText,
    required String privacyText,
  }) {
    final lower = label.toLowerCase();
    final lowerTerms = termsText.toLowerCase();
    final lowerPrivacy = privacyText.toLowerCase();
    final termsStart = lower.indexOf(lowerTerms);
    final privacyStart = lower.indexOf(lowerPrivacy);
    if (termsStart == -1 || privacyStart == -1 || termsStart >= privacyStart) {
      return null;
    }

    return _ConsentLabelSplit(
      prefix: label.substring(0, termsStart),
      terms: label.substring(termsStart, termsStart + termsText.length),
      between: label.substring(termsStart + termsText.length, privacyStart),
      privacy: label.substring(privacyStart, privacyStart + privacyText.length),
      suffix: label.substring(privacyStart + privacyText.length),
    );
  }
}
