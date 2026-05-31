import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final state = ref.watch(profileControllerProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final legalDocumentsAsync = ref.watch(currentLegalDocumentsProvider(locale));
    final profile = state.profile ?? state.session?.user;

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
                child: switch (legalDocumentsAsync) {
                  AsyncData(:final value) => ListView(
                    children: [
                      _LegalDocumentView(document: value.termsOfUse),
                      const SizedBox(height: 16),
                      _LegalDocumentView(document: value.privacyPolicy),
                    ],
                  ),
                  AsyncError() => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(text.profileLegalUnavailable),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () =>
                            ref.invalidate(currentLegalDocumentsProvider(locale)),
                        child: Text(text.retryAction),
                      ),
                    ],
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  mapProfileFeedbackMessage(_error!, text),
                  style: const TextStyle(color: Colors.red),
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
                onPressed: state.isSaving || !_accepted
                    ? null
                    : () => _accept(legalDocumentsAsync.value),
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
                  onPressed: () => context.go(TemplatesPage.routePath),
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

    final profile = next.profile ?? next.session?.user;
    final requires = profile?.legalAcceptance.requiresAcceptance ?? true;
    ref
        .read(appLaunchControllerProvider.notifier)
        .markSignedInWithLegalStatus(requiresLegalAcceptance: requires);
    if (!requires) {
      context.go(TemplatesPage.routePath);
    }
  }

  Future<void> _logout() async {
    await ref.read(profileControllerProvider.notifier).logout();
    if (!mounted) {
      return;
    }
    context.go(GuestWelcomePage.routePath);
  }
}

class _LegalDocumentView extends StatelessWidget {
  const _LegalDocumentView({required this.document});

  final MobileLegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          document.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (document.summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(document.summary, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 12),
        for (final section in document.sections) ...[
          if (section.heading.isNotEmpty) ...[
            Text(
              section.heading,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
          ],
          for (final paragraph in section.paragraphs) ...[
            Text(paragraph, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}
