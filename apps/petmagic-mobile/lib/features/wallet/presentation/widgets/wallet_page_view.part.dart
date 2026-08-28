part of 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

extension _WalletPageView on _WalletPageState {
  Widget _buildWalletPage(BuildContext context) {
    final state = ref.watch(
      walletControllerProvider.select(
        (state) => (
          isInitialLoading: state.isInitialLoading,
          wallet: state.wallet,
          errorMessage: state.errorMessage,
          packs: state.packs,
          paymentMethods: state.paymentMethods,
          storeProductPrices: state.storeProductPrices,
          isBuying: state.isBuying,
          isClaimingAd: state.isClaimingAd,
          ledger: state.ledger,
          purchases: state.purchases,
          highlightedPurchaseOrderId: state.highlightedPurchaseOrderId,
        ),
      ),
    );
    final controller = ref.read(walletControllerProvider.notifier);
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final unavailableKind = state.wallet == null && !state.isInitialLoading
        ? classifyAppUnavailable(
            raw: state.errorMessage,
            hasInternet: hasInternet,
          )
        : null;
    final legalAcceptanceRequired = isLegalAcceptanceRequiredError(
      state.errorMessage,
    );
    final hasShell = PetMagicShellScope.isPresent(context);
    final bottomNavInset = hasShell
        ? petMagicScrollableBottomInset(
            context,
            extraSpacing: kPetMagicBottomContentInsetRelaxed,
          )
        : MediaQuery.viewPaddingOf(context).bottom +
              kPetMagicBottomContentInsetCompact;

    if (!isAuthenticated) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomNavInset),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: WalletPage.routePath,
              ),
            ),
          ),
        ),
      );
    }

    if (state.wallet == null &&
        !state.isInitialLoading &&
        legalAcceptanceRequired) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomNavInset),
            child: _WalletUnavailableCard(
              message:
                  mapCommonAuthFeedbackMessage(
                    text,
                    state.errorMessage,
                    preferAuthRequiredMessage: true,
                  ) ??
                  text.profileLegalAcceptanceRequired,
              onAction: () =>
                  context.appNavigator.go(const LegalAcceptanceDestination()),
              actionLabel: text.profileLegalAcceptAction,
            ),
          ),
        ),
      );
    }

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false || !next.hasInternet) {
        return;
      }

      if (!isAuthenticated) {
        return;
      }

      final currentState = ref.read(walletControllerProvider);
      final currentUnavailableKind =
          currentState.wallet == null && !currentState.isInitialLoading
          ? classifyAppUnavailable(
              raw: currentState.errorMessage,
              hasInternet: next.hasInternet,
            )
          : null;
      if (_shouldReloadOnResume) {
        unawaited(
          _resumePendingCheckoutVerification().whenComplete(
            _scheduleNextAutoRefresh,
          ),
        );
        return;
      }

      if (currentUnavailableKind != null) {
        unawaited(
          controller.load(refresh: true).whenComplete(_scheduleNextAutoRefresh),
        );
        return;
      }

      unawaited(
        _refreshVisibleWalletData(
          forceRefresh: true,
        ).whenComplete(_scheduleNextAutoRefresh),
      );
    });

    ref.listen(walletControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      final previousState =
          previous?.checkoutVerificationState ??
          WalletCheckoutVerificationState.idle;
      final nextState = next.checkoutVerificationState;
      if (previousState == nextState) {
        return;
      }

      if (nextState == WalletCheckoutVerificationState.succeeded) {
        final grantedSpark = next.checkoutGrantedSpark ?? 0;
        PetMagicToast.show(
          context,
          message: text.walletCheckoutSucceeded(grantedSpark),
          tone: PetMagicToastTone.success,
        );
        return;
      }

      if (nextState == WalletCheckoutVerificationState.pending) {
        PetMagicToast.show(
          context,
          message: text.externalCheckoutPendingVerificationMessage,
          tone: PetMagicToastTone.info,
        );
        return;
      }

      if (nextState == WalletCheckoutVerificationState.error) {
        PetMagicToast.show(
          context,
          message: _friendlyError(
            text,
            next.checkoutErrorMessage ??
                next.errorMessage ??
                text.walletDataUnavailableFallback,
          ),
          tone: PetMagicToastTone.warning,
        );
      }
    });

    ref.listen(walletControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }

      final previousError = previous?.errorMessage?.trim();
      final nextError = next.errorMessage?.trim();
      if (nextError == null ||
          nextError.isEmpty ||
          nextError == previousError) {
        return;
      }

      // Keep full-page unavailable card for hard failures when wallet is absent.
      if (next.wallet == null) {
        return;
      }

      if (_isWalletPartialError(nextError)) {
        return;
      }

      PetMagicToast.show(
        context,
        message: _friendlyError(text, nextError),
        tone: PetMagicToastTone.warning,
      );
    });

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isInitialLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : unavailableKind != null
            ? PetMagicUnavailableView(
                kind: unavailableKind,
                onRetry: () => unawaited(controller.load(refresh: true)),
                padding: EdgeInsets.fromLTRB(28, 36, 28, bottomNavInset),
              )
            : RefreshIndicator.adaptive(
                onRefresh: () async {
                  await PetMagicHaptics.medium();
                  await controller.load(refresh: true);
                },
                color: colors.accent,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, bottomNavInset),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _WalletHeader(
                      title: text.walletPageTitle,
                      subtitle: text.walletPageSubtitle,
                    ),
                    if (state.wallet == null) ...[
                      const SizedBox(height: 22),
                      _WalletUnavailableCard(
                        message: _friendlyError(
                          text,
                          state.errorMessage ??
                              text.walletDataUnavailableFallback,
                        ),
                        onAction: () => controller.load(refresh: true),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _BalanceCard(wallet: state.wallet),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        ProfileMessageCard(
                          message: _friendlyError(text, state.errorMessage!),
                          tone: colors.gold,
                        ),
                      ],
                      if (isAuthenticated &&
                          !(state.wallet?.isPremium ?? false)) ...[
                        const SizedBox(height: 14),
                        _PremiumUpsellCard(
                          onOpenPremium: () => context.appNavigator.push(
                            const PremiumDestination(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _PacksSection(
                        packs: state.packs,
                        storeProductPrices: state.storeProductPrices,
                        isBuying: state.isBuying,
                        onSelect: (pack) => _showPackDetailSheet(
                          context,
                          state.packs,
                          paymentMethods: state.paymentMethods,
                          initialPack: pack,
                          isBuying: state.isBuying,
                          onBuy: (selectedPack, selectedPaymentMethod) =>
                              controller.buyPack(
                                selectedPack,
                                selectedPaymentMethod,
                              ),
                          onCheckoutReady: (checkout) async {
                            controller.resetCheckoutVerification();
                            controller.consumeCheckoutUrl();
                            return _handleCheckout(checkout);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LedgerSection(
                        items: state.ledger,
                        onViewAll: () => context.appNavigator.push(
                          const AllTransactionsDestination(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PurchasesSection(
                        items: state.purchases,
                        highlightedOrderId: state.highlightedPurchaseOrderId,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
