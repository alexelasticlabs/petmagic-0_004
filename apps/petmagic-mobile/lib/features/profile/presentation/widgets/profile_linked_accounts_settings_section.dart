import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:petmagic_mobile/features/profile/application/external_auth_gateway.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_page.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';

part 'profile_linked_accounts_widgets.part.dart';

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
    final appleSignInAvailable = ref.watch(
      appRuntimeInfoProvider.select(
        (runtimeInfo) => runtimeInfo.platform == AppRuntimePlatform.ios,
      ),
    );
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
            _LinkedDetailHeader(
              title: widget.title,
              subtitle: appleSignInAvailable
                  ? text.profileDetailsLinkedAccountsBodyIos
                  : widget.subtitle,
            ),
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
                    if (appleSignInAvailable)
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
