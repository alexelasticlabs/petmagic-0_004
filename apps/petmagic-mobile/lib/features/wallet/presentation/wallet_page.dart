import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/all_transactions_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/payments/payment_method_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';

part 'widgets/wallet_page_activity_widgets.dart';
part 'widgets/wallet_page_overview_widgets.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  static const routePath = '/wallet';
  static const legacyRoutePath = '/profile/wallet';

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage>
    with WidgetsBindingObserver {
  bool _shouldReloadOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(walletControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldReloadOnResume) {
      _shouldReloadOnResume = false;
      unawaited(() async {
        final controller = ref.read(walletControllerProvider.notifier);
        await controller.verifyCheckoutStatus();

        final verificationState = ref
            .read(walletControllerProvider)
            .checkoutVerificationState;
        if (verificationState != WalletCheckoutVerificationState.succeeded) {
          await controller.verifyStripeCheckout(null);
        }
      }());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final hasShell =
        context.findAncestorWidgetOfExactType<PetMagicShell>() != null;
    final bottomNavInset = hasShell
        ? petMagicScrollableBottomInset(
            context,
            extraSpacing: kPetMagicBottomContentInsetRelaxed,
          )
        : MediaQuery.viewPaddingOf(context).bottom +
              kPetMagicBottomContentInsetCompact;
    final checkoutStatusMessage = _checkoutStatusMessage(text, state);
    final checkoutCheckingMessage = _checkoutCheckingMessage(text, state);

    return ProfileScreenBackground(
      child: SafeArea(
        child: state.isInitialLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
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
                    if (state.checkoutVerificationState ==
                        WalletCheckoutVerificationState.checking) ...[
                      const SizedBox(height: 16),
                      ProfileProgressCard(
                        title: text.externalCheckoutCheckingTitle,
                        message: checkoutCheckingMessage,
                        tone: colors.accent,
                        isLoading: true,
                      ),
                    ],
                    if (checkoutStatusMessage != null) ...[
                      const SizedBox(height: 16),
                      ProfileMessageCard(
                        message: checkoutStatusMessage,
                        tone:
                            state.checkoutVerificationState ==
                                WalletCheckoutVerificationState.error
                            ? colors.gold
                            : colors.accent,
                      ),
                    ],
                    if (state.wallet == null) ...[
                      const SizedBox(height: 22),
                      _WalletUnavailableCard(
                        message: _friendlyError(
                          text,
                          state.errorMessage ??
                              text.walletDataUnavailableFallback,
                        ),
                        onRetry: () => controller.load(refresh: true),
                      ),
                    ] else ...[
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        ProfileMessageCard(
                          message: _friendlyError(text, state.errorMessage!),
                          tone: colors.gold,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _BalanceCard(
                        wallet: state.wallet,
                        onRefresh: () => controller.load(refresh: true),
                      ),
                      const SizedBox(height: 16),
                      _PacksSection(
                        packs: state.packs,
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
                            await _handleCheckout(checkout);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _RewardsOverviewCard(
                        wallet: state.wallet,
                        isClaimingAd: state.isClaimingAd,
                        onClaimAd: controller.claimAdReward,
                      ),
                      const SizedBox(height: 16),
                      _LedgerSection(
                        items: state.ledger,
                        onViewAll: () =>
                            context.pushNamed(AllTransactionsPage.routeName),
                      ),
                      const SizedBox(height: 16),
                      _PurchasesSection(
                        items: state.purchases,
                        highlightedOrderId: state.highlightedPurchaseOrderId,
                      ),
                      if (state.purchases.isNotEmpty)
                        const SizedBox(height: 16),
                      const _WalletCompanionHero(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _handleCheckout(PurchaseCheckoutModel checkout) async {
    final text = AppLocalizations.of(context);
    developer.log(
      'Checkout dispatch (order=${checkout.orderId}, usesPaymentSheet=${checkout.usesPaymentSheet}, provider=${checkout.paymentProvider}, urlLength=${checkout.checkoutUrl.length}, hasClientSecret=${(checkout.paymentIntentClientSecret?.isNotEmpty ?? false)}, hasPublishableKey=${(checkout.publishableKey?.isNotEmpty ?? false)})',
      name: 'PetMagic.Wallet.Checkout',
    );

    if (!checkout.usesPaymentSheet) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.walletPaymentGatewayUnavailableError)),
      );
      return;
    }

    await _presentStripePaymentSheet(checkout);
  }

  Future<void> _presentStripePaymentSheet(
    PurchaseCheckoutModel checkout,
  ) async {
    final text = AppLocalizations.of(context);
    final clientSecret = checkout.paymentIntentClientSecret;
    final publishableKey = checkout.publishableKey;
    if (clientSecret == null ||
        clientSecret.isEmpty ||
        publishableKey == null ||
        publishableKey.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.walletPaymentGatewayUnavailableError)),
      );
      return;
    }

    try {
      developer.log(
        'PaymentSheet init start (order=${checkout.orderId})',
        name: 'PetMagic.Wallet.Checkout',
      );

      Stripe.publishableKey = publishableKey;
      Stripe.urlScheme = 'petmagicstripe';
      await Stripe.instance.applySettings();

      developer.log(
        'PaymentSheet settings applied (order=${checkout.orderId})',
        name: 'PetMagic.Wallet.Checkout',
      );

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'PetMagic',
          customerId: checkout.customerId,
          customerEphemeralKeySecret: checkout.customerEphemeralKeySecret,
          returnURL: 'petmagicstripe://redirect',
        ),
      );

      developer.log(
        'PaymentSheet initialized (order=${checkout.orderId})',
        name: 'PetMagic.Wallet.Checkout',
      );

      _shouldReloadOnResume = true;
      await Stripe.instance.presentPaymentSheet();

      developer.log(
        'PaymentSheet completed (order=${checkout.orderId})',
        name: 'PetMagic.Wallet.Checkout',
      );

      if (!mounted) {
        return;
      }

      final controller = ref.read(walletControllerProvider.notifier);
      await controller.verifyStripeCheckout(checkout.externalPaymentId);

      // Fallback polling keeps UX resilient when direct verification is delayed.
      final verificationState = ref
          .read(walletControllerProvider)
          .checkoutVerificationState;
      if (verificationState != WalletCheckoutVerificationState.succeeded) {
        await controller.verifyCheckoutStatus();
      }
      _shouldReloadOnResume = false;
    } on StripeException catch (error) {
      developer.log(
        'PaymentSheet StripeException (order=${checkout.orderId})',
        name: 'PetMagic.Wallet.Checkout',
        error: error,
      );

      if (!mounted) {
        return;
      }

      final message = error.error.localizedMessage;
      _shouldReloadOnResume = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (message == null || message.isEmpty)
                ? text.walletPaymentGatewayUnavailableError
                : message,
          ),
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'PaymentSheet unexpected error (order=${checkout.orderId})',
        name: 'PetMagic.Wallet.Checkout',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      final platformMessage = switch (error) {
        PlatformException(:final message) => message,
        Exception() => error.toString(),
        _ => null,
      };
      _shouldReloadOnResume = false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (platformMessage == null || platformMessage.isEmpty)
                ? text.walletPaymentGatewayUnavailableError
                : platformMessage,
          ),
        ),
      );
    }
  }

}

Future<void> _showPackDetailSheet(
  BuildContext context,
  List<CurrencyPackModel> packs, {
  required List<WalletPaymentMethodModel> paymentMethods,
  required CurrencyPackModel initialPack,
  required bool isBuying,
  required Future<PurchaseCheckoutModel?> Function(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod,
  )
  onBuy,
  required Future<void> Function(PurchaseCheckoutModel checkout)
  onCheckoutReady,
}) async {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  final sortedPacks = packs.toList(growable: false)
    ..sort((left, right) {
      final bySpark = left.totalSpark.compareTo(right.totalSpark);
      if (bySpark != 0) {
        return bySpark;
      }

      return left.priceAmount.compareTo(right.priceAmount);
    });

  if (sortedPacks.isEmpty) {
    return;
  }

  final enabledMethods = paymentMethods
      .where((method) => method.isEnabled)
      .toList(growable: false);
  if (enabledMethods.isEmpty) {
    return;
  }

  final bestOfferPack = sortedPacks.last;
  final popularPack = sortedPacks.length >= 3
      ? sortedPacks[(sortedPacks.length - 1) ~/ 2]
      : null;
  var selectedPack = sortedPacks.firstWhere(
    (pack) => pack.packId == initialPack.packId,
    orElse: () => sortedPacks.first,
  );
  var selectedMethod = enabledMethods
      .where((method) => method.isSelectedByDefault)
      .cast<WalletPaymentMethodModel?>()
      .firstOrNull ??
      enabledMethods
          .where((method) => method.isRecommended)
          .cast<WalletPaymentMethodModel?>()
          .firstOrNull ??
      enabledMethods.first;

  List<PaymentMethodSheetOption> buildMethodOptions() {
    return enabledMethods
        .map(
          (method) => PaymentMethodSheetOption(
            id: method.provider,
            title: _walletProviderLabel(text, method),
            icon: _walletProviderIcon(method),
            subtitle: method.displaySubtitle,
            badge: method.isRecommended
                ? text.premiumPaymentRecommendedBadge
                : (method.isSelectedByDefault
                      ? text.premiumPaymentDefaultBadge
                      : null),
            warningTitle: method.warningTitle,
            warningMessage: method.warningMessage,
            notes: method.notes,
            isEnabled: method.isEnabled,
          ),
        )
        .toList(growable: false);
  }

  final selectedOption = await showPaymentMethodSheet(
    context: context,
    title: text.premiumPaymentTitle,
    subtitle: text.premiumSecurePaymentSubtitle,
    continueLabel: text.premiumContinueAction,
    options: buildMethodOptions(),
  );
  if (selectedOption == null || !context.mounted) {
    return;
  }

  for (final method in enabledMethods) {
    if (method.provider == selectedOption.id) {
      selectedMethod = method;
      break;
    }
  }

  await showPetMagicModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext, _) {
      final safeBottom = MediaQuery.viewPaddingOf(sheetContext).bottom;
      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          final selectedPrice = _formatPrice(selectedPack);
          final photosApprox = (selectedPack.totalSpark / _kPhotoCostSpark)
              .floor();
          final videosApprox = (selectedPack.totalSpark / _kVideoCostSpark)
              .floor();
          final usageSummary = videosApprox > 0
              ? '${text.walletApproxPhotos(photosApprox)} • ${text.walletApproxVideos(videosApprox)}'
              : text.walletApproxPhotos(photosApprox);

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, safeBottom + 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: colors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _walletProviderLabel(text, selectedMethod),
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedMethod.displaySubtitle?.trim().isNotEmpty ==
                                        true
                                    ? selectedMethod.displaySubtitle!.trim()
                                    : text.premiumSecurePaymentSubtitle,
                                style: TextStyle(
                                  color: colors.textSoft,
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CheckoutTrustPill(
                          icon: Icons.verified_user_rounded,
                          label: text.premiumSecurePaymentTitle,
                        ),
                        _CheckoutTrustPill(
                          icon: _walletProviderIcon(selectedMethod),
                          label: _walletProviderLabel(text, selectedMethod),
                        ),
                        if (selectedMethod.isStripe)
                          const _CheckoutTrustPill(
                            icon: Icons.payment_rounded,
                            label: 'Visa • Mastercard',
                          ),
                        if (selectedMethod.isStripe)
                          const _CheckoutTrustPill(
                            icon: Icons.phone_iphone_rounded,
                            label: 'Apple Pay • Google Pay',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceStrong.withValues(alpha: 0.44),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text.premiumPaymentTitle,
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _walletProviderLabel(text, selectedMethod),
                                  style: TextStyle(
                                    color: colors.textStrong,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final selected = await showPaymentMethodSheet(
                                context: sheetContext,
                                title: text.premiumPaymentTitle,
                                subtitle: text.premiumSecurePaymentSubtitle,
                                continueLabel: text.premiumContinueAction,
                                options: buildMethodOptions(),
                              );
                              if (selected == null || !sheetContext.mounted) {
                                return;
                              }

                              WalletPaymentMethodModel? matched;
                              for (final method in enabledMethods) {
                                if (method.provider == selected.id) {
                                  matched = method;
                                  break;
                                }
                              }

                              if (matched == null) {
                                return;
                              }

                              setModalState(() => selectedMethod = matched!);
                            },
                            child: Text(text.externalCheckoutContinueAction),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (
                      var index = 0;
                      index < sortedPacks.length;
                      index++
                    ) ...[
                      _CheckoutPackOptionTile(
                        pack: sortedPacks[index],
                        price: _formatPrice(sortedPacks[index]),
                        isSelected:
                            sortedPacks[index].packId == selectedPack.packId,
                        isBestValue:
                            bestOfferPack.packId == sortedPacks[index].packId,
                        isPopular:
                            popularPack?.packId == sortedPacks[index].packId &&
                            bestOfferPack.packId != sortedPacks[index].packId,
                        onTap: () => setModalState(
                          () => selectedPack = sortedPacks[index],
                        ),
                      ),
                      if (index != sortedPacks.length - 1)
                        const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceStrong.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selectedPack.totalSpark} PawSpark Tokens',
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedPack.bonusSpark > 0
                                ? text.walletPackBreakdown(
                                    selectedPack.grantedSpark,
                                    selectedPack.bonusSpark,
                                  )
                                : 'Used for photo and video generations',
                            style: TextStyle(
                              color: colors.textSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${text.walletWhatYouCanCreateTitle} $usageSummary',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceStrong.withValues(alpha: 0.44),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          _CheckoutSummaryRow(
                            label: '${selectedPack.totalSpark} PawSpark',
                            value: selectedPrice,
                          ),
                          const SizedBox(height: 6),
                          const _CheckoutSummaryRow(
                            label: 'Tax',
                            value: 'Included',
                          ),
                          const Divider(height: 16),
                          _CheckoutSummaryRow(
                            label: 'Total',
                            value: selectedPrice,
                            isEmphasized: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isBuying
                            ? null
                            : () async {
                                debugPrint(
                                  'PETMAGIC_WALLET_CHECKOUT buy_tapped pack=${selectedPack.code}',
                                );
                                final checkout = await onBuy(
                                  selectedPack,
                                  selectedMethod,
                                );
                                if (!sheetContext.mounted) {
                                  return;
                                }

                                if (checkout == null) {
                                  if (selectedMethod.isStoreNative) {
                                    Navigator.of(sheetContext).pop();
                                    return;
                                  }

                                  debugPrint(
                                    'PETMAGIC_WALLET_CHECKOUT buy_result empty_checkout',
                                  );
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        text.walletPaymentUnavailableError,
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.of(sheetContext).pop();
                                await onCheckoutReady(checkout);
                              },
                        icon: Icon(
                          isBuying
                              ? Icons.hourglass_top_rounded
                              : Icons.credit_card_rounded,
                        ),
                        label: Text('Pay $selectedPrice'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedMethod.isStripe
                          ? text.premiumSecurePaymentSubtitle
                          : (selectedMethod.warningMessage?.trim().isNotEmpty ==
                                    true
                                ? selectedMethod.warningMessage!.trim()
                                : text.walletCheckoutHint),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _CheckoutPackOptionTile extends StatelessWidget {
  const _CheckoutPackOptionTile({
    required this.pack,
    required this.price,
    required this.isSelected,
    required this.isBestValue,
    required this.isPopular,
    required this.onTap,
  });

  final CurrencyPackModel pack;
  final String price;
  final bool isSelected;
  final bool isBestValue;
  final bool isPopular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final borderColor = isSelected ? colors.accent : colors.border;
    final badgeLabel = isBestValue
        ? text.walletBestValueBadge
        : (isPopular ? text.walletPopularBadge : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? colors.accent.withValues(alpha: 0.12)
                : colors.surfaceStrong.withValues(alpha: 0.34),
            border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? colors.accent : colors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pack.totalSpark} PawSpark Tokens',
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (badgeLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          color: isBestValue ? colors.gold : colors.accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                price,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutTrustPill extends StatelessWidget {
  const _CheckoutTrustPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.surfaceStrong.withValues(alpha: 0.46),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSummaryRow extends StatelessWidget {
  const _CheckoutSummaryRow({
    required this.label,
    required this.value,
    this.isEmphasized = false,
  });

  final String label;
  final String value;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final valueColor = isEmphasized ? colors.accent : colors.textStrong;
    final valueWeight = isEmphasized ? FontWeight.w900 : FontWeight.w800;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: valueWeight,
          ),
        ),
      ],
    );
  }
}

String _formatPrice(CurrencyPackModel pack) {
  return NumberFormat.simpleCurrency(
    name: pack.currencyCode,
  ).format(pack.priceAmount);
}

String _walletProviderLabel(
  AppLocalizations text,
  WalletPaymentMethodModel method,
) {
  final provider = method.provider.trim().toLowerCase();
  final customLabel = method.displayLabel?.trim();
  if (customLabel != null && customLabel.isNotEmpty) {
    return customLabel;
  }

  return switch (provider) {
    'stripe' => text.premiumPaymentStripe,
    'google_play' => text.premiumPaymentGooglePlay,
    'app_store' => text.premiumPaymentApple,
    _ => method.provider,
  };
}

IconData _walletProviderIcon(WalletPaymentMethodModel method) {
  final provider = method.provider.trim().toLowerCase();
  return switch (provider) {
    'stripe' => Icons.credit_card_rounded,
    'google_play' => Icons.android_rounded,
    'app_store' => Icons.apple_rounded,
    _ => Icons.payments_rounded,
  };
}

String _valuePerCurrencyLabel(CurrencyPackModel pack) {
  if (pack.priceAmount <= 0) {
    return '-';
  }

  final sparkPerUnit = pack.totalSpark / pack.priceAmount;
  final formatted = NumberFormat('0.0').format(sparkPerUnit);
  return '$formatted PawSpark / ${pack.currencyCode}1';
}

String _formatDate(BuildContext context, DateTime? value) {
  if (value == null) {
    return AppLocalizations.of(context).walletPending;
  }

  return DateFormat.MMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(value.toLocal());
}

String _sourceLabel(AppLocalizations text, String source) {
  return switch (source) {
    'pack_purchase' => text.walletSourcePackPurchase,
    'generation_spend' => text.walletSourceGenerationSpend,
    'generation_refund' => text.walletSourceGenerationRefund,
    'weekly_grant' => text.walletSourceWeeklyGrant,
    'ad_reward' => text.walletSourceAdReward,
    'promo_redeem' || 'redeem_code' => text.walletSourcePromoCode,
    'admin_grant' => text.walletSourceAdminGrant,
    'admin_debit' => text.walletSourceAdminDebit,
    _ => source,
  };
}

IconData _sourceIcon(String source) {
  return switch (source) {
    'pack_purchase' => Icons.account_balance_wallet_rounded,
    'generation_spend' => Icons.auto_awesome_rounded,
    'generation_refund' => Icons.undo_rounded,
    'weekly_grant' => Icons.card_giftcard_rounded,
    'ad_reward' => Icons.play_circle_fill_rounded,
    'promo_redeem' || 'redeem_code' => Icons.confirmation_number_rounded,
    'admin_grant' => Icons.support_agent_rounded,
    'admin_debit' => Icons.remove_circle_outline_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

String _purchaseStatusLabel(AppLocalizations text, String status) {
  return switch (status) {
    'succeeded' => text.walletPurchaseCompleted,
    'failed' => text.walletPurchaseFailed,
    _ => text.walletPending,
  };
}

Color _purchaseStatusColor(String status, PetMagicColors colors) {
  return switch (status) {
    'succeeded' => colors.accent,
    'failed' => colors.danger,
    _ => colors.gold,
  };
}

Color _ledgerTone(WalletLedgerItem item, PetMagicColors colors) {
  return switch (item.source) {
    'generation_spend' || 'admin_debit' => colors.danger,
    'generation_refund' => colors.textMuted,
    _ => item.delta >= 0 ? colors.accent : colors.danger,
  };
}

String? _checkoutStatusMessage(AppLocalizations text, WalletState state) {
  return switch (state.checkoutVerificationState) {
    WalletCheckoutVerificationState.idle => null,
    WalletCheckoutVerificationState.checking => null,
    WalletCheckoutVerificationState.succeeded => text.walletCheckoutSucceeded(
      state.checkoutGrantedSpark ?? 0,
    ),
    WalletCheckoutVerificationState.pending =>
      text.externalCheckoutPendingVerificationMessage,
    WalletCheckoutVerificationState.error => _friendlyError(
      text,
      state.checkoutErrorMessage ??
          state.errorMessage ??
          text.walletDataUnavailableFallback,
    ),
  };
}

String _checkoutCheckingMessage(AppLocalizations text, WalletState state) {
  final progressMessage = state.checkoutProgressMessage;
  final startedAt = state.checkoutVerificationStartedAt;
  final elapsed = startedAt == null
      ? null
      : DateTime.now().toUtc().difference(startedAt);
  final elapsedLabel = elapsed == null
      ? null
      : '${elapsed.isNegative ? 0 : elapsed.inSeconds}s';

  if (progressMessage == null || progressMessage.isEmpty) {
    if (elapsedLabel == null) {
      return text.externalCheckoutCheckingMessage;
    }

    return '${text.externalCheckoutCheckingMessage} ($elapsedLabel)';
  }

  if (elapsedLabel == null) {
    return progressMessage;
  }

  return '$progressMessage ($elapsedLabel)';
}

String _friendlyError(AppLocalizations text, String value) {
  if (value.contains('auth.sign_in_required')) {
    return text.authRequiredMessage;
  }

  if (value.contains('auth.session_expired')) {
    return text.authExternalSessionExpired;
  }

  if (value.contains('wallet.ledger_failed') ||
      value.contains('wallet.packs_failed') ||
      value.contains('wallet.purchases_failed')) {
    return text.walletPartialActivityUnavailable;
  }

  if (value.contains('payment_gateway_failed')) {
    return text.walletPaymentGatewayUnavailableError;
  }

  if (value.contains('wallet.payment_unavailable')) {
    return text.walletPaymentUnavailableError;
  }

  if (value.contains('economy.pack_not_found')) {
    return text.walletPackUnavailableError;
  }

  if (value.contains('redeem_code_not_found')) {
    return text.walletRedeemCodeNotFoundError;
  }

  if (value.contains('redeem_code_already_used')) {
    return text.walletRedeemCodeAlreadyUsedError;
  }

  if (value.contains('redeem_code_expired')) {
    return text.walletRedeemCodeExpiredError;
  }

  if (value.contains('redeem_code_inactive')) {
    return text.walletRedeemCodeInactiveError;
  }

  if (value.contains('redeem_code_exhausted')) {
    return text.walletRedeemCodeExhaustedError;
  }

  if (value.contains('redeem_code_user_limit_reached')) {
    return text.walletRedeemCodeUserLimitError;
  }

  if (value.contains('economy.insufficient_balance')) {
    return text.walletInsufficientBalanceError;
  }

  if (value.contains('wallet.network_unavailable')) {
    return text.walletRedeemOfflineError;
  }

  if (value.contains('wallet.server_unavailable')) {
    return text.walletRedeemServerError;
  }

  if (value.contains('AppException(500)') ||
      value.contains('processing your request')) {
    return text.walletRedeemServerError;
  }

  return value;
}
