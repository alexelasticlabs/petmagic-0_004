part of 'profile_settings_detail_page.dart';

class _ProfileSettingsStaticDetailContent extends StatelessWidget {
  const _ProfileSettingsStaticDetailContent({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.nextStep,
    required this.bottomInset,
    required this.onOpenSupport,
    required this.onDeleteAccount,
  });

  final ProfileSettingsDetailKind kind;
  final String title;
  final String subtitle;
  final String status;
  final String nextStep;
  final double bottomInset;
  final VoidCallback? onOpenSupport;
  final Future<void> Function()? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
          children: [
            _DetailHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 22),
            ProfileSectionLabel(label: text.profileDetailsCurrentStatusSection),
            ProfileGlassCard(
              child: Text(
                status,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            ProfileSectionLabel(label: text.profileDetailsNextStepSection),
            ProfileGlassCard(
              child: Text(
                nextStep,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onOpenSupport != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenSupport,
                  icon: const Icon(Icons.support_agent_rounded),
                  label: Text(text.supportHomeOpenChatAction),
                ),
              ),
            ],
            if (kind == ProfileSettingsDetailKind.deleteAccount &&
                onDeleteAccount != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.danger,
                    foregroundColor: colors.backgroundBottom,
                    shadowColor: colors.danger.withValues(alpha: 0.35),
                  ),
                  onPressed: onDeleteAccount,
                  child: Text(text.profileSettingsDeleteAccountTitle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
