part of 'profile_page.dart';

extension _ProfilePageView on _ProfilePageState {
  Widget _buildProfilePage(BuildContext context) {
    final state = ref.watch(
      profileControllerProvider.select(
        (state) => (
          isLoading: state.isLoading,
          isAuthenticated: state.isAuthenticated,
          isSaving: state.isSaving,
          profile: state.profile,
        ),
      ),
    );
    final wallet = ref.watch(
      walletControllerProvider.select((walletState) => walletState.wallet),
    );
    final walletIsLoading = ref.watch(
      walletControllerProvider.select((walletState) => walletState.isLoading),
    );
    final controller = ref.read(profileControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomNavInset = petMagicScrollableBottomInset(context);
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final unavailableKind = !state.isLoading && state.profile == null
        ? classifyAppUnavailable(
            raw: ref.watch(
              profileControllerProvider.select((state) => state.errorMessage),
            ),
            hasInternet: hasInternet,
          )
        : null;
    final subscriptionSummary = state.isAuthenticated && state.profile != null
        ? ref.watch(
            premiumSubscriptionSummaryProvider.select(
              (summary) => summary.value,
            ),
          )
        : null;

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false || !next.hasInternet) {
        return;
      }

      final profileState = ref.read(profileControllerProvider);
      final walletState = ref.read(walletControllerProvider);
      if (profileState.isAuthenticated &&
          profileState.profile != null &&
          _shouldPreloadWalletSnapshot(walletState, forceRefresh: true)) {
        _preloadWalletIfNeeded(forceRefresh: true);
      }

      final currentUnavailableKind =
          !profileState.isLoading && profileState.profile == null
          ? classifyAppUnavailable(
              raw: profileState.errorMessage,
              hasInternet: next.hasInternet,
            )
          : null;
      if (currentUnavailableKind == null) {
        return;
      }

      unawaited(_reloadProfile(invalidatePremiumSummary: true));
    });

    if (!state.isLoading && !state.isAuthenticated && unavailableKind == null) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomNavInset),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: ProfilePage.routePath,
              ),
            ),
          ),
        ),
      );
    }

    if (unavailableKind != null) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: PetMagicUnavailableView(
            kind: unavailableKind,
            onRetry: () =>
                unawaited(_reloadProfile(invalidatePremiumSummary: true)),
            padding: EdgeInsets.fromLTRB(28, 36, 28, bottomNavInset),
          ),
        ),
      );
    }

    final profile = state.profile;
    final summaryPremium = subscriptionSummary?.isPremium;
    final shouldShowSubscriptionCard = summaryPremium == true;
    final shouldShowPremiumCta =
        summaryPremium == false ||
        (summaryPremium == null && profile?.isPremium != true);
    final legalStatus = profile?.legalAcceptance.isCurrentAccepted == true
        ? text.profileLegalShortcutAccepted
        : text.profileLegalShortcutPending;

    ref.listen(profileControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      final previousError = previous?.errorMessage;
      if (next.errorMessage != null && next.errorMessage != previousError) {
        PetMagicToast.show(
          context,
          message: mapProfileFeedbackMessage(next.errorMessage!, text),
          tone: PetMagicToastTone.warning,
        );
      }

      final previousSuccess = previous?.successMessage;
      if (next.successMessage != null &&
          next.successMessage != previousSuccess) {
        final message = mapProfileSuccessMessage(next.successMessage!, text);
        if (message != null) {
          PetMagicToast.show(
            context,
            message: message,
            tone: PetMagicToastTone.success,
          );
        }
      }
    });

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator.adaptive(
                onRefresh: () async {
                  await _reloadProfile(invalidatePremiumSummary: true);
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, bottomNavInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    MotionEntrance(
                      delay: const Duration(milliseconds: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text.profileTitle,
                                  style: TextStyle(
                                    color: colors.textStrong,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _HeaderActionIcon(
                            icon: Icons.settings_outlined,
                            onTap: () => context.appNavigator.push(
                              const ProfileSettingsDestination(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (profile != null) ...[
                      MotionEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: _ProfileHeroCard(profile: profile),
                      ),
                      const SizedBox(height: 12),
                      MotionEntrance(
                        delay: const Duration(milliseconds: 150),
                        child: _WalletHighlightCard(
                          wallet: wallet,
                          isWalletLoading: walletIsLoading,
                          onTap: () => context.appNavigator.push(
                            const WalletDestination(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      MotionEntrance(
                        delay: const Duration(milliseconds: 170),
                        child: _GamificationHighlightsWrapper(),
                      ),
                      const SizedBox(height: 12),
                      if (shouldShowPremiumCta) ...[
                        MotionEntrance(
                          delay: const Duration(milliseconds: 200),
                          child: _PremiumBannerCard(
                            onTap: () => _handlePremiumTap(subscriptionSummary),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (shouldShowSubscriptionCard) ...[
                        MotionEntrance(
                          delay: const Duration(milliseconds: 240),
                          child: _SubscriptionSummaryCard(
                            summary: subscriptionSummary!,
                            isOpening: _isOpeningSubscription,
                            onManageTap: () =>
                                _handleSubscriptionAction(subscriptionSummary),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      MotionEntrance(
                        delay: const Duration(milliseconds: 280),
                        child: ProfileGlassCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              ProfileSettingsRow(
                                icon: Icons.pets_rounded,
                                title: text.profilePetsTitle,
                                subtitle: text.profilePetsSubtitle,
                                iconColor: colors.accent,
                                onTap: () => context.appNavigator.push(
                                  const PetsDestination(),
                                ),
                              ),
                              ProfileSettingsRow(
                                key: const ValueKey('profile_legal_shortcut'),
                                icon: Icons.privacy_tip_outlined,
                                title: text.profileLegalShortcutTitle,
                                subtitle: legalStatus,
                                iconColor: colors.accent,
                                onTap: () => context.appNavigator.push(
                                  ProfileSettingsDetailDestination(
                                    ProfileSettingsDetailKind.terms.slug,
                                  ),
                                ),
                              ),
                              ProfileSettingsRow(
                                icon: Icons.support_agent_rounded,
                                title: text.profileSupportTitle,
                                subtitle: text.profileSupportCompactSubtitle,
                                iconColor: colors.blue,
                                onTap: () => context.appNavigator.push(
                                  const SupportChatDestination(),
                                ),
                              ),
                              ProfileSettingsRow(
                                icon: Icons.settings_outlined,
                                title: text.profileSettingsShortcutTitle,
                                subtitle: text.profileSettingsCompactSubtitle,
                                showDivider: false,
                                onTap: () => context.appNavigator.push(
                                  const ProfileSettingsDestination(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      MotionEntrance(
                        delay: const Duration(milliseconds: 320),
                        child: OutlinedButton.icon(
                          onPressed: state.isSaving ? null : controller.logout,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: colors.danger,
                            side: BorderSide(
                              color: colors.danger.withValues(alpha: 0.3),
                            ),
                            backgroundColor: colors.danger.withValues(
                              alpha: 0.08,
                            ),
                          ),
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(text.profileSignOutAction),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
