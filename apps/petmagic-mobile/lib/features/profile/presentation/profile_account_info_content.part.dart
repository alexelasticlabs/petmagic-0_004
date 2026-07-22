part of 'profile_account_info_page.dart';

class _AccountProfileHeroCard extends StatelessWidget {
  const _AccountProfileHeroCard({
    required this.profile,
    required this.displayName,
    required this.isSaving,
    required this.onAvatarTap,
  });

  final MobileUserProfile profile;
  final String displayName;
  final bool isSaving;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // gradient accent strip
          Container(
            width: double.infinity,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                colors: [
                  colors.accent.withValues(alpha: 0.7),
                  colors.blue.withValues(alpha: 0.5),
                  colors.purple.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
          // tappable avatar
          Stack(
            alignment: Alignment.center,
            children: [
              ProfileAvatarBadge(
                imageUrl: profile.avatar?.url,
                fallbackLabel: displayName,
                size: 120,
                showEditOverlay: !isSaving,
                onTap: isSaving ? null : onAvatarTap,
              ),
              if (isSaving)
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text.profileAvatarTapToChange,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 16),
          // display name
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          // email
          Text(
            profile.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          // status pills
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (profile.isPremium)
                ProfileStatusPill(
                  label: text.premiumLabel,
                  leadingWidget: const PremiumCrownIcon(size: 13),
                  backgroundColor: colors.gold.withValues(alpha: 0.18),
                  foregroundColor: colors.gold,
                )
              else
                ProfileStatusPill(
                  label: text.freeLabel,
                  leading: Icons.person_outline_rounded,
                ),
              ProfileStatusPill(
                label: profile.emailConfirmed
                    ? text.profileEmailVerifiedShort
                    : text.profileEmailPendingShort,
                leading: profile.emailConfirmed
                    ? Icons.verified_rounded
                    : Icons.mail_outline_rounded,
                foregroundColor: profile.emailConfirmed
                    ? colors.accent
                    : colors.textMuted,
              ),
              if (profile.roles.isNotEmpty)
                ProfileStatusPill(
                  label: _localizedProfileRole(text, profile.roles.first),
                  leading: Icons.shield_outlined,
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

String _localizedProfileRole(AppLocalizations text, String role) {
  return switch (role.trim().toLowerCase()) {
    'user' => text.profileAccountRoleUser,
    'moderator' => text.profileAccountRoleModerator,
    'admin' => text.profileAccountRoleAdmin,
    _ => role,
  };
}

class _ProfileEditableNameCard extends StatelessWidget {
  const _ProfileEditableNameCard({
    required this.controller,
    required this.isEditing,
    required this.isSaving,
    required this.currentValue,
    required this.onStartEditing,
    required this.onCancelEditing,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool isEditing;
  final bool isSaving;
  final String currentValue;
  final VoidCallback onStartEditing;
  final VoidCallback onCancelEditing;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final material = MaterialLocalizations.of(context);

    return ProfileGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.accentSoft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.badge_outlined, color: colors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text.profileAccountDisplayNameLabel,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isEditing)
                IconButton(
                  onPressed: isSaving ? null : onStartEditing,
                  tooltip: text.profileAccountDisplayNameLabel,
                  icon: const Icon(Icons.edit_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isEditing) ...[
            TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              maxLength: 120,
              decoration: InputDecoration(
                counterText: '',
                hintText: text.profileAccountDisplayNameLabel,
              ),
              onSubmitted: (_) => onSave(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onCancelEditing,
                    child: Text(material.cancelButtonLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isSaving ? null : onSave,
                    child: Text(
                      isSaving
                          ? text.profileLoadingAction
                          : material.saveButtonLabel,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              currentValue,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
