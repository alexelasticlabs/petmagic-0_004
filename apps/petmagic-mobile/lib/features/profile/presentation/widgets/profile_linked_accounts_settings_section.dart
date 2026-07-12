import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_page.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';

class ProfileLinkedAccountsSettingsSection extends ConsumerStatefulWidget {
  const ProfileLinkedAccountsSettingsSection({
    required this.title,
    required this.subtitle,
    required this.bottomInset,
    super.key,
  });

  final String title;
  final String subtitle;
  final double bottomInset;

  @override
  ConsumerState<ProfileLinkedAccountsSettingsSection> createState() =>
      _ProfileLinkedAccountsSettingsSectionState();
}

class _ProfileLinkedAccountsSettingsSectionState
    extends ConsumerState<ProfileLinkedAccountsSettingsSection> {
  List<MobileLinkedAccount>? _cachedLinkedAccounts;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final state = ref.watch(profileControllerProvider);
    final profile = state.profile;
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final linkedAccountsAsync = hasInternet
        ? ref.watch(linkedAccountsProvider)
        : null;
    final linkedAccounts = switch (linkedAccountsAsync) {
      AsyncData(:final value) => value,
      _ => _cachedLinkedAccounts ?? const <MobileLinkedAccount>[],
    };
    final linkedAccountsLoading =
        linkedAccountsAsync is AsyncLoading<List<MobileLinkedAccount>>;
    final linkedAccountsFailed =
        linkedAccountsAsync is AsyncError<List<MobileLinkedAccount>>;
    final accountActionsEnabled =
        hasInternet &&
        !linkedAccountsLoading &&
        !linkedAccountsFailed &&
        profile != null;
    final showOfflineUnavailable =
        profile != null && !hasInternet && _cachedLinkedAccounts == null;
    final showRetryState =
        profile != null &&
        hasInternet &&
        linkedAccountsFailed &&
        _cachedLinkedAccounts == null;

    if (hasInternet) {
      ref.listen<AsyncValue<List<MobileLinkedAccount>>>(
        linkedAccountsProvider,
        (previous, next) {
          next.whenData((value) {
            if (!mounted) {
              return;
            }

            setState(() {
              _cachedLinkedAccounts = value;
            });
          });
        },
      );
    }

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false ||
          !next.hasInternet ||
          _cachedLinkedAccounts != null) {
        return;
      }

      ref.invalidate(linkedAccountsProvider);
    });

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, widget.bottomInset),
          children: [
            _LinkedDetailHeader(title: widget.title, subtitle: widget.subtitle),
            const SizedBox(height: 22),
            if (state.errorMessage != null) ...[
              ProfileGlassCard(
                child: Text(
                  mapProfileFeedbackMessage(state.errorMessage!, text),
                  style: TextStyle(
                    color: colors.danger,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            ProfileSectionLabel(label: text.profileDetailsCurrentStatusSection),
            const SizedBox(height: 8),
            if (showOfflineUnavailable) ...[
              PetMagicUnavailableView(
                kind: AppUnavailableKind.offline,
                onRetry: () {
                  if (!ref.read(networkStatusControllerProvider).hasInternet) {
                    return;
                  }

                  ref.invalidate(linkedAccountsProvider);
                },
                padding: EdgeInsets.fromLTRB(8, 20, 8, widget.bottomInset),
              ),
              const SizedBox(height: 12),
            ],
            if (linkedAccountsLoading) ...[
              ProfileGlassCard(
                child: Text(
                  text.profileLinkedAccountsLoading,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (showRetryState) ...[
              ProfileGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.profileLinkedAccountsUnavailable,
                      style: TextStyle(
                        color: colors.danger,
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.invalidate(linkedAccountsProvider),
                      child: Text(text.retryAction),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!showOfflineUnavailable && !showRetryState) ...[
              ProfileGlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LinkedAccountRow(
                      providerLabel: text.authGoogleShortLabel,
                      icon: Icons.g_mobiledata_rounded,
                      account: _findLinkedAccount(
                        linkedAccounts,
                        ExternalAuthProvider.google,
                      ),
                      isBusy: state.isSaving,
                      actionsEnabled: accountActionsEnabled,
                      onConnect: () => ref
                          .read(profileControllerProvider.notifier)
                          .linkExternalAccount(ExternalAuthProvider.google),
                      onDisconnect: () => ref
                          .read(profileControllerProvider.notifier)
                          .unlinkExternalAccount(ExternalAuthProvider.google),
                    ),
                    _LinkedAccountRow(
                      providerLabel: text.authAppleShortLabel,
                      icon: Icons.apple_rounded,
                      account: _findLinkedAccount(
                        linkedAccounts,
                        ExternalAuthProvider.apple,
                      ),
                      isBusy: state.isSaving,
                      actionsEnabled: accountActionsEnabled,
                      onConnect: () => ref
                          .read(profileControllerProvider.notifier)
                          .linkExternalAccount(ExternalAuthProvider.apple),
                      onDisconnect: () => ref
                          .read(profileControllerProvider.notifier)
                          .unlinkExternalAccount(ExternalAuthProvider.apple),
                    ),
                    _LinkedAccountEmailRow(
                      email: profile?.email,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            ProfileSectionLabel(label: text.profileDetailsNextStepSection),
            const SizedBox(height: 8),
            ProfileGlassCard(
              child: Text(
                text.profileDetailsLinkedAccountsNext,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
