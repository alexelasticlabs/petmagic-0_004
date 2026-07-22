import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/application/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/legal_document_list_view.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';

class LegalAcceptanceGatePage extends ConsumerStatefulWidget {
  const LegalAcceptanceGatePage({super.key});

  static const routePath = '/legal-gate';

  @override
  ConsumerState<LegalAcceptanceGatePage> createState() =>
      _LegalAcceptanceGatePageState();
}

class _LegalAcceptanceGatePageState
    extends ConsumerState<LegalAcceptanceGatePage> {
  bool _accepted = false;
  String? _error;
  MobileLegalDocuments? _cachedDocuments;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final state = ref.watch(profileControllerProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final legalDocumentsProvider = currentLegalDocumentsProvider(locale);
    final legalDocumentsAsync = hasInternet
        ? ref.watch(legalDocumentsProvider)
        : null;
    final profile = state.profile;
    final documents =
        switch (legalDocumentsAsync) {
          AsyncData(:final value) => value,
          _ => null,
        } ??
        _cachedDocuments;

    if (hasInternet) {
      ref.listen<AsyncValue<MobileLegalDocuments>>(legalDocumentsProvider, (
        previous,
        next,
      ) {
        next.whenData((value) {
          if (!mounted) {
            return;
          }

          setState(() {
            _cachedDocuments = value;
          });
        });
      });
    }

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false ||
          !next.hasInternet ||
          documents != null) {
        return;
      }

      ref.invalidate(legalDocumentsProvider);
    });

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(text.profileAccountConsentLabel),
        actions: [
          TextButton(
            onPressed: state.isSaving ? null : _logout,
            child: Text(text.profileSignOutAction),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text.profileLegalAcceptanceRequired,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: documents != null
                    ? LegalDocumentListView(
                        documents: [
                          documents.termsOfUse,
                          documents.privacyPolicy,
                        ],
                      )
                    : !hasInternet
                    ? PetMagicUnavailableView(
                        kind: AppUnavailableKind.offline,
                        onRetry: () {
                          if (!ref
                              .read(networkStatusControllerProvider)
                              .hasInternet) {
                            return;
                          }

                          ref.invalidate(legalDocumentsProvider);
                        },
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
                      )
                    : switch (legalDocumentsAsync) {
                        AsyncError() => PetMagicUnavailableView(
                          kind: AppUnavailableKind.serverUnavailable,
                          onRetry: () => ref.invalidate(legalDocumentsProvider),
                          padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
                        ),
                        _ => const Center(child: CircularProgressIndicator()),
                      },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  mapProfileFeedbackMessage(_error!, text),
                  style: TextStyle(color: colors.error),
                ),
              ],
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _accepted,
                onChanged: state.isSaving
                    ? null
                    : (value) => setState(() => _accepted = value ?? false),
                title: Text(text.authAcceptTermsLabel),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: state.isSaving || !_accepted || documents == null
                    ? null
                    : () => _accept(documents),
                child: Text(
                  state.isSaving
                      ? text.profileLoadingAction
                      : text.profileLegalAcceptAction,
                ),
              ),
              if (profile != null &&
                  profile.legalAcceptance.requiresAcceptance == false) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () =>
                      context.appNavigator.go(const TemplatesDestination()),
                  child: Text(text.premiumContinueAction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _accept(MobileLegalDocuments? documents) async {
    if (documents == null) {
      return;
    }

    await ref
        .read(profileControllerProvider.notifier)
        .acceptCurrentLegalDocuments(documents);
    if (!mounted) {
      return;
    }

    final next = ref.read(profileControllerProvider);
    if (next.errorMessage != null) {
      setState(() => _error = next.errorMessage);
      return;
    }

    final profile = next.profile;
    final requires = profile?.legalAcceptance.requiresAcceptance ?? true;
    ref
        .read(appLaunchControllerProvider.notifier)
        .markSignedInWithLegalStatus(requiresLegalAcceptance: requires);
    if (!requires) {
      context.appNavigator.go(const TemplatesDestination());
    }
  }

  Future<void> _logout() async {
    await ref.read(profileControllerProvider.notifier).logout();
    if (!mounted) {
      return;
    }
    context.appNavigator.go(const WelcomeDestination());
  }
}
