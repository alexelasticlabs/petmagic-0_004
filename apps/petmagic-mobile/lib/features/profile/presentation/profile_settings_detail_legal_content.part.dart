part of 'profile_settings_detail_page.dart';

class _ProfileSettingsLegalDetailContent extends ConsumerWidget {
  const _ProfileSettingsLegalDetailContent({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.profile,
    required this.bottomInset,
    required this.locale,
    required this.localeTag,
    required this.legalDocumentsAsync,
    required this.documents,
    required this.hasInternet,
    required this.requiresAcceptance,
  });

  final ProfileSettingsDetailKind kind;
  final String title;
  final String subtitle;
  final ProfileState state;
  final MobileUserProfile? profile;
  final double bottomInset;
  final Locale locale;
  final String localeTag;
  final AsyncValue<MobileLegalDocuments>? legalDocumentsAsync;
  final MobileLegalDocuments? documents;
  final bool hasInternet;
  final bool requiresAcceptance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
          children: [
            _DetailHeader(title: title, subtitle: subtitle),
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
            ProfileGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _InfoRow(
                    label: text.profileAccountConsentLabel,
                    value: profile?.legalAcceptance.isCurrentAccepted == true
                        ? text.profileLegalAcceptanceCurrent
                        : text.profileLegalAcceptanceRequired,
                  ),
                  _InfoRow(
                    label: text.profileLegalVersionLabel,
                    value:
                        _documentFromValueOrNull(kind, documents)?.version ??
                        '—',
                  ),
                  _InfoRow(
                    label: text.profileLegalPublishedLabel,
                    value: _formatDate(
                      _documentFromValueOrNull(kind, documents)?.publishedAtUtc,
                      locale,
                    ),
                  ),
                  _InfoRow(
                    label: text.profileLegalAcceptedVersionLabel,
                    value: kind == ProfileSettingsDetailKind.terms
                        ? (profile?.legalAcceptance.termsOfUseAcceptedVersion ??
                              '—')
                        : (profile
                                  ?.legalAcceptance
                                  .privacyPolicyAcceptedVersion ??
                              '—'),
                  ),
                  _InfoRow(
                    label: text.profileLegalAcceptedAtLabel,
                    value: _formatDate(
                      kind == ProfileSettingsDetailKind.terms
                          ? profile?.legalAcceptance.termsOfUseAcceptedAtUtc
                          : profile?.legalAcceptance.privacyPolicyAcceptedAtUtc,
                      locale,
                    ),
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (documents == null && !hasInternet) ...[
              PetMagicUnavailableView(
                kind: AppUnavailableKind.offline,
                onRetry: () {
                  if (!ref.read(networkStatusControllerProvider).hasInternet) {
                    return;
                  }

                  ref.invalidate(currentLegalDocumentsProvider(localeTag));
                },
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
              ),
            ] else
              ...switch (legalDocumentsAsync) {
                AsyncLoading() when documents == null => [
                  ProfileGlassCard(
                    child: Text(
                      text.profileLegalLoading,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                AsyncError() when documents == null => [
                  ProfileGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.profileLegalUnavailable,
                          style: TextStyle(
                            color: colors.danger,
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            currentLegalDocumentsProvider(localeTag),
                          ),
                          child: Text(text.retryAction),
                        ),
                      ],
                    ),
                  ),
                ],
                _ when documents != null => [
                  ProfileSectionLabel(label: text.profileLegalDocumentSection),
                  ProfileGlassCard(
                    padding: EdgeInsets.zero,
                    child: LegalDocumentListView(
                      documents: [_documentFromValue(kind, documents!)],
                      includeDocumentTitles: false,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ProfileGlassCard(
                    child: profile != null && requiresAcceptance
                        ? SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: state.isSaving
                                  ? null
                                  : () => ref
                                        .read(
                                          profileControllerProvider.notifier,
                                        )
                                        .acceptCurrentLegalDocuments(
                                          documents!,
                                        ),
                              child: Text(
                                state.isSaving
                                    ? text.profileLoadingAction
                                    : text.profileLegalAcceptAction,
                              ),
                            ),
                          )
                        : Text(
                            profile == null
                                ? text.profileLegalAcceptanceGuestHint
                                : text.profileLegalCurrentAcceptedHint,
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ],
                _ => const <Widget>[],
              },
          ],
        ),
      ),
    );
  }
}
