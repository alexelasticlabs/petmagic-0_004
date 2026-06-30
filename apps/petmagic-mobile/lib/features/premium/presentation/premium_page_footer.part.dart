part of 'premium_page.dart';

class _Footer extends StatelessWidget {
  const _Footer({
    required this.isDark,
    required this.state,
    required this.controller,
  });

  final bool isDark;
  final PremiumState state;
  final PremiumController controller;

  @override
  Widget build(BuildContext context) {
    final text = _premiumText(context);
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final accent = isDark ? const Color(0xFFAA8FFF) : _kLightAccent;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 12, color: sub),
            const SizedBox(width: 5),
            Text(
              text.premiumStorePaymentDisclaimerTitle,
              style: TextStyle(
                color: sub,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text.premiumStorePaymentDisclaimerBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: sub.withValues(alpha: 0.84),
            fontSize: 10,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 8,
          children: [
            _Link(
              text: text.premiumRestoreAction,
              accent: accent,
              onTap: state.isRestoring ? null : controller.restorePurchases,
            ),
            Text(' • ', style: TextStyle(color: sub, fontSize: 11)),
            _Link(
              text: text.profileSettingsTermsTitle,
              accent: accent,
              url: 'https://petmagic.app/terms',
            ),
            Text(' • ', style: TextStyle(color: sub, fontSize: 11)),
            _Link(
              text: text.profileSettingsPrivacyTitle,
              accent: accent,
              url: 'https://petmagic.app/privacy',
            ),
          ],
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.text, required this.accent, this.url, this.onTap});

  final String text;
  final Color accent;
  final String? url;
  final VoidCallback? onTap;

  Future<void> _handleUrlTap(BuildContext context) async {
    final safeUri = parseSafePremiumExternalUri(url);
    if (safeUri == null) {
      final text = _premiumText(context);
      PetMagicToast.show(
        context,
        message: text.premiumManageFailed,
        tone: PetMagicToastTone.warning,
      );
      return;
    }

    var launched = false;
    try {
      launched = await launchUrl(safeUri, mode: LaunchMode.externalApplication);
    } on Object {
      launched = false;
    }
    if (!context.mounted) {
      return;
    }

    if (!launched) {
      final text = _premiumText(context);
      PetMagicToast.show(
        context,
        message: text.premiumManageFailed,
        tone: PetMagicToastTone.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          (url != null ? () => unawaited(_handleUrlTap(context)) : null),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: accent.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
