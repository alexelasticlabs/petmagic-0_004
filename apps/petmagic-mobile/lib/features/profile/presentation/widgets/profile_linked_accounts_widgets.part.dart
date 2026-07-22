part of 'profile_linked_accounts_settings_section.dart';

class _LinkedDetailHeader extends StatelessWidget {
  const _LinkedDetailHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final navigator = context.appNavigator;

    return Row(
      children: [
        IconButton(
          onPressed: () {
            if (navigator.canPop()) {
              navigator.pop();
              return;
            }

            navigator.go(const ProfileSettingsDestination());
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textStrong,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

MobileLinkedAccount? _findLinkedAccount(
  List<MobileLinkedAccount> accounts,
  ExternalAuthProvider provider,
) {
  for (final account in accounts) {
    if (account.provider.toLowerCase() == provider.apiValue.toLowerCase()) {
      return account;
    }
  }

  return null;
}

class _LinkedAccountRow extends StatelessWidget {
  const _LinkedAccountRow({
    required this.providerLabel,
    required this.icon,
    required this.account,
    required this.isBusy,
    required this.actionsEnabled,
    required this.onConnect,
    required this.onDisconnect,
  });

  final String providerLabel;
  final IconData icon;
  final MobileLinkedAccount? account;
  final bool isBusy;
  final bool actionsEnabled;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isConnected = account != null;
    final canDisconnect = account?.canDisconnect ?? false;
    final providerAccountLabel = account?.displayName.trim();
    final hasAccountLabel =
        providerAccountLabel != null && providerAccountLabel.isNotEmpty;
    final statusLabel = isConnected
        ? text.profileLinkedAccountsConnectedStatus
        : text.profileLinkedAccountsNotConnectedStatus;

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.border.withValues(alpha: 0.75)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: colors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerLabel,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (hasAccountLabel) ...[
                          const SizedBox(height: 4),
                          Text(
                            providerAccountLabel,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: isConnected
                                ? colors.textStrong
                                : colors.textSoft,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isConnected && !canDisconnect) ...[
                          const SizedBox(height: 6),
                          Text(
                            text.profileLinkedAccountsProtectedHint,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: !actionsEnabled || isBusy
                    ? null
                    : isConnected
                    ? (canDisconnect ? onDisconnect : null)
                    : onConnect,
                child: Text(
                  isConnected
                      ? text.profileLinkedAccountsDisconnectAction
                      : text.profileLinkedAccountsConnectAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedAccountEmailRow extends StatelessWidget {
  const _LinkedAccountEmailRow({required this.email, this.showDivider = true});

  final String? email;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: colors.border.withValues(alpha: 0.75),
                  ),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.alternate_email_rounded,
                      color: colors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.profileEmailLabel,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (email ?? '').trim().isEmpty ? '—' : email!,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text.profileLinkedAccountsConnectedStatus,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          text.profileLinkedAccountsProtectedHint,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: (email ?? '').trim().isEmpty
                    ? null
                    : () {
                        context.appNavigator.push(
                          PasswordChangeDestination(
                            payload: PasswordChangeRouteArgs(
                              email: email!.trim(),
                            ),
                          ),
                        );
                      },
                child: Text(text.profileSettingsPasswordTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
