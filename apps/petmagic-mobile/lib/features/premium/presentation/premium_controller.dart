import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';

final premiumControllerProvider =
    NotifierProvider<PremiumController, PremiumState>(PremiumController.new);

typedef PremiumRefreshProfile = Future<void> Function();

final premiumRefreshProfileProvider = Provider<PremiumRefreshProfile>((ref) {
  return () => ref.read(profileControllerProvider.notifier).initialize();
});

enum PremiumCheckoutVerificationState {
  idle,
  checking,
  activated,
  pending,
  error,
}

enum PremiumSubscriptionProviderView { stripe, googlePlay, appStore, unknown }

class PremiumSubscriptionSummaryView {
  const PremiumSubscriptionSummaryView({
    required this.isPremium,
    required this.canManageSubscription,
    required this.status,
    required this.manageSubscriptionAction,
    required this.provider,
    this.planName,
    this.currentPeriodStartUtc,
    this.currentPeriodEndUtc,
    this.cancelAtPeriodEnd,
    this.monthlyTokenLimit,
    this.tokensAvailable,
    this.weeklyGrantAmount,
    this.lastTokenGrantAtUtc,
    this.cardBrand,
    this.cardLast4,
    this.billingPeriod,
  });

  final bool isPremium;
  final bool canManageSubscription;
  final String status;
  final String? planName;
  final String? billingPeriod;
  final DateTime? currentPeriodStartUtc;
  final DateTime? currentPeriodEndUtc;
  final DateTime? lastTokenGrantAtUtc;
  final bool? cancelAtPeriodEnd;
  final int? monthlyTokenLimit;
  final int? tokensAvailable;
  final int? weeklyGrantAmount;
  final String? cardBrand;
  final String? cardLast4;
  final String manageSubscriptionAction;
  final PremiumSubscriptionProviderView provider;

  factory PremiumSubscriptionSummaryView.fromStatus(PremiumStatusModel status) {
    final provider = switch (status.provider) {
      PremiumPaymentProvider.stripe => PremiumSubscriptionProviderView.stripe,
      PremiumPaymentProvider.googlePlay =>
        PremiumSubscriptionProviderView.googlePlay,
      PremiumPaymentProvider.appStore =>
        PremiumSubscriptionProviderView.appStore,
      null => PremiumSubscriptionProviderView.unknown,
    };

    return PremiumSubscriptionSummaryView(
      isPremium: status.isPremium,
      canManageSubscription: status.canManageSubscription,
      status: status.status,
      planName: status.planName,
      currentPeriodStartUtc: status.currentPeriodStartUtc,
      currentPeriodEndUtc: status.currentPeriodEndUtc,
      lastTokenGrantAtUtc: status.lastTokenGrantAtUtc,
      cancelAtPeriodEnd: status.cancelAtPeriodEnd,
      monthlyTokenLimit: status.monthlyTokenLimit,
      tokensAvailable: status.tokensAvailable,
      weeklyGrantAmount: status.weeklyGrantAmount,
      cardBrand: status.cardBrand,
      cardLast4: status.cardLast4,
      billingPeriod: status.billingPeriod,
      manageSubscriptionAction: status.manageSubscriptionAction,
      provider: provider,
    );
  }
}

final premiumSubscriptionSummaryProvider =
    FutureProvider.autoDispose<PremiumSubscriptionSummaryView>((ref) async {
      final repository = ref.watch(premiumRepositoryProvider);
      final status = await repository.fetchStatus();
      return PremiumSubscriptionSummaryView.fromStatus(status);
    });

final premiumSubscriptionManagementServiceProvider =
    Provider<PremiumSubscriptionManagementService>((ref) {
      return PremiumSubscriptionManagementService(
        repository: ref.watch(premiumRepositoryProvider),
      );
    });

void _logPremiumCheckoutFailure(
  String stage,
  Object error,
  StackTrace stackTrace,
) {
  developer.Timeline.instantSync(
    'petmagic.premium.checkout.error',
    arguments: {'stage': stage},
  );
  developer.log(
    'PremiumController::$stage failed',
    name: 'PetMagic.Premium.Checkout',
    error: error,
    stackTrace: stackTrace,
  );
}

void _logPremiumLoadFailure(
  String stage,
  Object error,
  StackTrace stackTrace, {
  Map<String, Object?> context = const {},
}) {
  final payload = <String, Object>{'stage': stage};
  for (final entry in context.entries) {
    final value = entry.value;
    if (value != null) {
      payload[entry.key] = value.toString();
    }
  }

  developer.Timeline.instantSync(
    'petmagic.premium.load.error',
    arguments: payload,
  );
  developer.log(
    'PremiumController::$stage failed',
    name: 'PetMagic.Premium.Load',
    error: error,
    stackTrace: stackTrace,
  );
}

class PremiumSubscriptionManagementService {
  const PremiumSubscriptionManagementService({
    required PremiumRepository repository,
  }) : _repository = repository;

  final PremiumRepository _repository;

  Future<String> createManagementUrl(String manageSubscriptionAction) async {
    switch (manageSubscriptionAction) {
      case 'AppleSettings':
        return 'https://apps.apple.com/account/subscriptions';
      case 'GooglePlaySettings':
        return 'https://play.google.com/store/account/subscriptions';
      case 'StripeCustomerPortal':
        final portal = await _repository.createBillingPortal();
        return portal.portalUrl;
      default:
        throw const AppException('premium.manage_failed');
    }
  }

  Future<PremiumSubscriptionSummaryView> requestCancelAtPeriodEnd() async {
    final status = await _repository.cancelSubscription();
    return PremiumSubscriptionSummaryView.fromStatus(status);
  }
}

class PremiumState {
  const PremiumState({
    this.plans = const [],
    this.paymentMethods = const [],
    this.status,
    this.legalTexts,
    this.selectedPlanCode = 'yearly',
    this.selectedProvider = PremiumPaymentProvider.stripe,
    this.isLoading = false,
    this.isBuying = false,
    this.isManaging = false,
    this.isRestoring = false,
    this.isStoreAvailable = false,
    this.availableStoreProductIds = const <String>{},
    this.errorMessage,
    this.externalUrl,
    this.successMessage,
    this.checkoutVerificationState = PremiumCheckoutVerificationState.idle,
    this.isAwaitingCheckoutVerification = false,
    this.wasPremiumBeforeCheckout = false,
    this.checkoutErrorMessage,
    this.recentlyActivatedPremium = false,
  });

  final List<PremiumPlanModel> plans;
  final List<PremiumPaymentMethodModel> paymentMethods;
  final PremiumStatusModel? status;
  final PremiumLegalTextsModel? legalTexts;
  final String selectedPlanCode;
  final PremiumPaymentProvider selectedProvider;
  final bool isLoading;
  final bool isBuying;
  final bool isManaging;
  final bool isRestoring;
  final bool isStoreAvailable;
  final Set<String> availableStoreProductIds;
  final String? errorMessage;
  final String? externalUrl;
  final String? successMessage;
  final PremiumCheckoutVerificationState checkoutVerificationState;
  final bool isAwaitingCheckoutVerification;
  final bool wasPremiumBeforeCheckout;
  final String? checkoutErrorMessage;
  final bool recentlyActivatedPremium;

  PremiumPlanModel? get selectedPlan {
    for (final plan in plans) {
      if (plan.planCode == selectedPlanCode) {
        return plan;
      }
    }

    return plans.isEmpty ? null : plans.first;
  }

  bool get isPremium => status?.isPremium == true;

  bool get canManageSubscription => status?.canManageSubscription == true;

  bool get isInitialLoading => isLoading && plans.isEmpty;

  PremiumPaymentMethodModel? get selectedPaymentMethod {
    for (final method in paymentMethods) {
      if (method.provider == selectedProvider && method.isEnabled) {
        return method;
      }
    }

    return null;
  }

  bool get canStartCheckout {
    if (isPremium || recentlyActivatedPremium) {
      return false;
    }

    final plan = selectedPlan;
    if (plan == null) {
      return false;
    }

    final paymentMethod = selectedPaymentMethod;
    if (paymentMethod == null) {
      return false;
    }

    if (selectedProvider == PremiumPaymentProvider.stripe) {
      return plan.stripeCheckoutEnabled;
    }

    final productId = plan.productIdFor(selectedProvider);
    return isStoreAvailable &&
        productId != null &&
        availableStoreProductIds.contains(productId);
  }

  bool isProviderAvailable(PremiumPaymentProvider provider) {
    final paymentMethod = paymentMethods.where(
      (method) => method.provider == provider,
    );
    if (paymentMethod.isEmpty) {
      return false;
    }

    if (provider == PremiumPaymentProvider.stripe) {
      return paymentMethod.any((method) => method.isEnabled);
    }

    final plan = selectedPlan;
    final productId = plan?.productIdFor(provider);
    return isStoreAvailable &&
        productId != null &&
        availableStoreProductIds.contains(productId);
  }

  List<PremiumPaymentProvider> get availableProviders {
    final providers = <PremiumPaymentProvider>[];
    for (final method in paymentMethods) {
      if (method.isEnabled && !providers.contains(method.provider)) {
        providers.add(method.provider);
      }
    }

    return providers;
  }

  bool get showsExternalCheckoutWarning =>
      selectedProvider != PremiumPaymentProvider.stripe &&
      selectedPaymentMethod?.requiresExternalWarning == true;

  String get legalNotice {
    final paymentMethod = selectedPaymentMethod;
    if (legalTexts == null || paymentMethod == null) {
      return '';
    }

    if (paymentMethod.isStoreNative) {
      return legalTexts!.storeNotice;
    }

    return paymentMethod.provider == PremiumPaymentProvider.stripe
        ? legalTexts!.stripeNotice
        : legalTexts!.externalCheckoutNotice;
  }

  PremiumState copyWith({
    List<PremiumPlanModel>? plans,
    List<PremiumPaymentMethodModel>? paymentMethods,
    PremiumStatusModel? status,
    PremiumLegalTextsModel? legalTexts,
    String? selectedPlanCode,
    PremiumPaymentProvider? selectedProvider,
    bool? isLoading,
    bool? isBuying,
    bool? isManaging,
    bool? isRestoring,
    bool? isStoreAvailable,
    Set<String>? availableStoreProductIds,
    String? errorMessage,
    String? externalUrl,
    String? successMessage,
    PremiumCheckoutVerificationState? checkoutVerificationState,
    bool? isAwaitingCheckoutVerification,
    bool? wasPremiumBeforeCheckout,
    String? checkoutErrorMessage,
    bool? recentlyActivatedPremium,
    bool clearError = false,
    bool clearExternalUrl = false,
    bool clearSuccess = false,
    bool clearCheckoutError = false,
  }) {
    return PremiumState(
      plans: plans ?? this.plans,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      status: status ?? this.status,
      legalTexts: legalTexts ?? this.legalTexts,
      selectedPlanCode: selectedPlanCode ?? this.selectedPlanCode,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      isLoading: isLoading ?? this.isLoading,
      isBuying: isBuying ?? this.isBuying,
      isManaging: isManaging ?? this.isManaging,
      isRestoring: isRestoring ?? this.isRestoring,
      isStoreAvailable: isStoreAvailable ?? this.isStoreAvailable,
      availableStoreProductIds:
          availableStoreProductIds ?? this.availableStoreProductIds,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      externalUrl: clearExternalUrl ? null : externalUrl ?? this.externalUrl,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
      checkoutVerificationState:
          checkoutVerificationState ?? this.checkoutVerificationState,
      isAwaitingCheckoutVerification:
          isAwaitingCheckoutVerification ?? this.isAwaitingCheckoutVerification,
      wasPremiumBeforeCheckout:
          wasPremiumBeforeCheckout ?? this.wasPremiumBeforeCheckout,
      checkoutErrorMessage: clearCheckoutError
          ? null
          : checkoutErrorMessage ?? this.checkoutErrorMessage,
      recentlyActivatedPremium:
          recentlyActivatedPremium ?? this.recentlyActivatedPremium,
    );
  }
}

class PremiumController extends Notifier<PremiumState> {
  late final PremiumRepository _repository;
  late final PremiumRefreshProfile _refreshProfile;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  PremiumState build() {
    _repository = ref.watch(premiumRepositoryProvider);
    _refreshProfile = ref.watch(premiumRefreshProfileProvider);
    _purchaseSubscription?.cancel();
    _purchaseSubscription = _repository.purchaseUpdates.listen(
      _handlePurchaseUpdates,
    );
    ref.onDispose(() {
      unawaited(_purchaseSubscription?.cancel());
    });
    return const PremiumState(isLoading: true);
  }

  Future<void> load({bool refresh = false}) async {
    state = state.copyWith(
      isLoading: !refresh,
      clearError: true,
      clearExternalUrl: true,
      clearSuccess: true,
    );

    try {
      final results = await Future.wait<Object>([
        _repository.fetchPaywallConfig(
          locale: WidgetsBinding.instance.platformDispatcher.locale,
        ),
        _repository.fetchStatus(),
      ]);

      final config = results[0] as PremiumPaywallConfigModel;
      final status = results[1] as PremiumStatusModel;
      final plans = _normalizePlans(config.plans);

      final enabledMethods = config.paymentMethods
          .where((method) => method.isEnabled)
          .toList(growable: false);
      final configuredProviders = _extractProviders(enabledMethods);
      final storeAvailability = await _resolveStoreAvailability(
        plans,
        configuredProviders,
      );

      final selectedPlanCode = _selectPlanCode(
        plans,
        preferredPlanCode: config.recommendedPlanCode,
        currentPlanCode: state.selectedPlanCode,
      );

      final selectedProvider = _selectProvider(
        enabledMethods: enabledMethods,
        configuredProviders: configuredProviders,
        currentProvider: state.selectedProvider,
        storeAvailable: storeAvailability.isAvailable,
        availableStoreProductIds: storeAvailability.productIds,
        plans: plans,
        selectedPlanCode: selectedPlanCode,
      );

      state = state.copyWith(
        plans: plans,
        paymentMethods: config.paymentMethods,
        status: status,
        legalTexts: config.legalTexts,
        selectedPlanCode: selectedPlanCode,
        selectedProvider: selectedProvider,
        isStoreAvailable: storeAvailability.isAvailable,
        availableStoreProductIds: storeAvailability.productIds,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void selectPlan(String planCode) {
    state = state.copyWith(
      selectedPlanCode: planCode,
      clearError: true,
      clearSuccess: true,
      clearCheckoutError: true,
    );
  }

  void selectProvider(PremiumPaymentProvider provider) {
    state = state.copyWith(
      selectedProvider: provider,
      clearError: true,
      clearSuccess: true,
      clearCheckoutError: true,
    );
  }

  Future<PremiumCheckoutModel?> startCheckout() async {
    final plan = state.selectedPlan;
    if (plan == null) {
      return null;
    }

    if (!state.canStartCheckout) {
      state = state.copyWith(errorMessage: 'premium.store_product_unavailable');
      return null;
    }

    state = state.copyWith(
      isBuying: true,
      clearError: true,
      clearExternalUrl: true,
      clearSuccess: true,
      checkoutVerificationState: PremiumCheckoutVerificationState.idle,
      isAwaitingCheckoutVerification: false,
      clearCheckoutError: true,
      recentlyActivatedPremium: false,
    );

    try {
      if (state.selectedProvider == PremiumPaymentProvider.stripe) {
        final checkout = await _repository.createStripeCheckout(
          plan,
          WidgetsBinding.instance.platformDispatcher.locale,
        );
        if (!checkout.usesPaymentSheet) {
          state = state.copyWith(
            isBuying: false,
            errorMessage: 'premium.checkout_failed',
          );
          return null;
        }

        state = state.copyWith(isBuying: false);
        return checkout;
      }

      await _repository.startStoreCheckout(plan, state.selectedProvider);
      return null;
    } catch (error) {
      state = state.copyWith(isBuying: false, errorMessage: error.toString());
      return null;
    }
  }

  Future<void> manageBilling() async {
    state = state.copyWith(
      isManaging: true,
      clearError: true,
      clearExternalUrl: true,
      clearSuccess: true,
    );

    try {
      final status = state.status;
      if (status == null) {
        state = state.copyWith(
          isManaging: false,
          errorMessage: 'premium.manage_failed',
        );
        return;
      }

      final managementUrl = await _repository.createManagementUrl(status);
      state = state.copyWith(isManaging: false, externalUrl: managementUrl);
    } catch (error) {
      state = state.copyWith(isManaging: false, errorMessage: error.toString());
    }
  }

  Future<void> restorePurchases() async {
    if (state.selectedProvider != PremiumPaymentProvider.stripe) {
      state = state.copyWith(
        isRestoring: true,
        clearError: true,
        clearSuccess: true,
      );

      try {
        await _repository.restoreStorePurchases();
        await _refreshProfile();
        await load(refresh: true);
        ref.invalidate(premiumSubscriptionSummaryProvider);
        state = state.copyWith(
          isRestoring: false,
          successMessage: 'premium.restore_started',
        );
      } catch (error) {
        state = state.copyWith(
          isRestoring: false,
          errorMessage: error.toString(),
        );
      }

      return;
    }

    state = state.copyWith(
      isRestoring: true,
      clearError: true,
      clearSuccess: true,
    );

    await _refreshProfile();
    await load(refresh: true);
    ref.invalidate(premiumSubscriptionSummaryProvider);

    state = state.copyWith(
      isRestoring: false,
      successMessage: 'premium.restore_started',
    );
  }

  void consumeExternalUrl() {
    state = state.copyWith(clearExternalUrl: true);
  }

  void markCheckoutOpened({required bool wasPremiumBeforeCheckout}) {
    state = state.copyWith(
      isAwaitingCheckoutVerification: true,
      wasPremiumBeforeCheckout: wasPremiumBeforeCheckout,
      checkoutVerificationState: PremiumCheckoutVerificationState.idle,
      clearCheckoutError: true,
      recentlyActivatedPremium: false,
    );
  }

  Future<void> verifyCheckoutStatus({
    String? stripePlanCode,
    String? stripeExternalSubscriptionId,
  }) async {
    if (!state.isAwaitingCheckoutVerification) {
      return;
    }

    final normalizedPlanCode = stripePlanCode?.trim();
    final normalizedSubscriptionId = stripeExternalSubscriptionId?.trim();
    if ((normalizedPlanCode?.isNotEmpty ?? false) &&
        (normalizedSubscriptionId?.isNotEmpty ?? false)) {
      try {
        await _repository.verifyStripeSubscriptionCheckout(
          planCode: normalizedPlanCode!,
          externalSubscriptionId: normalizedSubscriptionId!,
        );
      } catch (error, stackTrace) {
        _logPremiumCheckoutFailure(
          'verify_stripe_subscription_checkout',
          error,
          stackTrace,
        );
        // Keep polling fallback even when explicit Stripe verification fails.
      }
    }

    state = state.copyWith(
      checkoutVerificationState: PremiumCheckoutVerificationState.checking,
      clearCheckoutError: true,
      recentlyActivatedPremium: false,
    );

    const maxAttempts = 4;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await _refreshProfile();
      await load(refresh: true);

      final updatedState = state;
      if (updatedState.errorMessage != null) {
        state = state.copyWith(
          checkoutVerificationState: PremiumCheckoutVerificationState.error,
          checkoutErrorMessage: updatedState.errorMessage,
          isAwaitingCheckoutVerification: false,
          recentlyActivatedPremium: false,
        );
        return;
      }

      final recentlyActivated =
          !updatedState.wasPremiumBeforeCheckout && updatedState.isPremium;
      if (recentlyActivated) {
        state = state.copyWith(
          checkoutVerificationState: PremiumCheckoutVerificationState.activated,
          isAwaitingCheckoutVerification: false,
          recentlyActivatedPremium: true,
          clearCheckoutError: true,
        );
        return;
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    state = state.copyWith(
      checkoutVerificationState: PremiumCheckoutVerificationState.pending,
      isAwaitingCheckoutVerification: false,
      recentlyActivatedPremium: false,
      clearCheckoutError: true,
    );
  }

  PremiumPaymentProvider? _platformStoreProvider() {
    if (Platform.isAndroid) {
      return PremiumPaymentProvider.googlePlay;
    }

    if (Platform.isIOS) {
      return PremiumPaymentProvider.appStore;
    }

    return null;
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(
            isBuying: true,
            clearError: true,
            clearSuccess: true,
          );
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyStorePurchase(purchase);
          break;
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _repository.completePurchase(purchase);
          }

          state = state.copyWith(
            isBuying: false,
            isRestoring: false,
            errorMessage: purchase.error?.message ?? 'premium.checkout_failed',
          );
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(
            isBuying: false,
            isRestoring: false,
            errorMessage: 'premium.purchase_cancelled',
          );
          break;
      }
    }
  }

  Future<void> _verifyStorePurchase(PurchaseDetails purchase) async {
    final wasPremiumBeforeCheckout = state.isPremium;
    final provider = _platformStoreProvider();
    if (provider == null) {
      state = state.copyWith(
        isBuying: false,
        isRestoring: false,
        errorMessage: 'premium.store_unavailable',
      );
      return;
    }

    PremiumPlanModel? matchedPlan;
    for (final plan in state.plans) {
      if (plan.productIdFor(provider) == purchase.productID) {
        matchedPlan = plan;
        break;
      }
    }

    if (matchedPlan == null) {
      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
      }

      state = state.copyWith(
        isBuying: false,
        isRestoring: false,
        errorMessage: 'premium.store_product_unavailable',
      );
      return;
    }

    try {
      final verified = await _repository.verifyStorePurchase(
        plan: matchedPlan,
        provider: provider,
        purchase: purchase,
      );

      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
      }

      await _refreshProfile();
      await load(refresh: true);

      if (verified.isActive) {
        final recentlyActivated = !wasPremiumBeforeCheckout && state.isPremium;
        state = state.copyWith(
          isBuying: false,
          isRestoring: false,
          successMessage: 'premium.purchase_activated',
          checkoutVerificationState: recentlyActivated
              ? PremiumCheckoutVerificationState.activated
              : PremiumCheckoutVerificationState.idle,
          isAwaitingCheckoutVerification: false,
          recentlyActivatedPremium: recentlyActivated,
          clearCheckoutError: true,
        );
        return;
      }

      state = state.copyWith(isBuying: false, isRestoring: false);
      markCheckoutOpened(wasPremiumBeforeCheckout: wasPremiumBeforeCheckout);
      await verifyCheckoutStatus();
    } catch (error) {
      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
      }

      state = state.copyWith(
        isBuying: false,
        isRestoring: false,
        errorMessage: error.toString(),
      );
    }
  }

  List<PremiumPlanModel> _normalizePlans(List<PremiumPlanModel> plans) {
    final filtered = <PremiumPlanModel>[];
    for (final plan in plans) {
      final key = _billingPeriodKey(plan);
      if (key == _BillingPeriod.monthly || key == _BillingPeriod.yearly) {
        filtered.add(plan);
      }
    }

    filtered.sort((left, right) {
      final byOrder = left.sortOrder.compareTo(right.sortOrder);
      if (byOrder != 0) {
        return byOrder;
      }

      return left.planCode.compareTo(right.planCode);
    });

    return filtered;
  }

  List<PremiumPaymentProvider> _extractProviders(
    List<PremiumPaymentMethodModel> methods,
  ) {
    final providers = <PremiumPaymentProvider>[];
    for (final method in methods) {
      if (!providers.contains(method.provider)) {
        providers.add(method.provider);
      }
    }

    return providers;
  }

  Future<({bool isAvailable, Set<String> productIds})>
  _resolveStoreAvailability(
    List<PremiumPlanModel> plans,
    List<PremiumPaymentProvider> providers,
  ) async {
    var isAvailable = false;
    final productIds = <String>{};

    for (final provider in providers) {
      if (provider == PremiumPaymentProvider.stripe) {
        continue;
      }

      try {
        final availability = await _repository.fetchStoreAvailability(
          plans,
          provider,
        );
        isAvailable = isAvailable || availability.isAvailable;
        productIds.addAll(availability.productIds);
      } catch (error, stackTrace) {
        _logPremiumLoadFailure(
          'fetch_store_availability',
          error,
          stackTrace,
          context: {'provider': provider.name},
        );
        // Store products can be temporarily unavailable; keep paywall usable.
      }
    }

    return (isAvailable: isAvailable, productIds: productIds);
  }

  String _selectPlanCode(
    List<PremiumPlanModel> plans, {
    required String? preferredPlanCode,
    required String currentPlanCode,
  }) {
    if (plans.isEmpty) {
      return currentPlanCode;
    }

    if (preferredPlanCode != null) {
      for (final plan in plans) {
        if (plan.planCode == preferredPlanCode) {
          return preferredPlanCode;
        }
      }
    }

    for (final plan in plans) {
      if (plan.planCode == currentPlanCode) {
        return currentPlanCode;
      }
    }

    return plans.first.planCode;
  }

  PremiumPaymentProvider _selectProvider({
    required List<PremiumPaymentMethodModel> enabledMethods,
    required List<PremiumPaymentProvider> configuredProviders,
    required PremiumPaymentProvider currentProvider,
    required bool storeAvailable,
    required Set<String> availableStoreProductIds,
    required List<PremiumPlanModel> plans,
    required String selectedPlanCode,
  }) {
    if (configuredProviders.isEmpty) {
      return currentProvider;
    }

    PremiumPaymentProvider? defaultProvider;
    for (final method in enabledMethods) {
      if (method.isSelectedByDefault) {
        defaultProvider = method.provider;
        break;
      }
    }

    PremiumPaymentProvider? recommendedProvider;
    for (final method in enabledMethods) {
      if (method.isRecommended) {
        recommendedProvider = method.provider;
        break;
      }
    }

    final candidates = <PremiumPaymentProvider>[
      currentProvider,
      ?defaultProvider,
      ?recommendedProvider,
      ...configuredProviders,
    ];

    for (final candidate in candidates) {
      if (!configuredProviders.contains(candidate)) {
        continue;
      }

      if (_providerIsCheckoutReady(
        candidate,
        plans,
        selectedPlanCode,
        storeAvailable,
        availableStoreProductIds,
      )) {
        return candidate;
      }
    }

    return configuredProviders.first;
  }

  bool _providerIsCheckoutReady(
    PremiumPaymentProvider provider,
    List<PremiumPlanModel> plans,
    String selectedPlanCode,
    bool storeAvailable,
    Set<String> availableStoreProductIds,
  ) {
    PremiumPlanModel? selectedPlan;
    for (final plan in plans) {
      if (plan.planCode == selectedPlanCode) {
        selectedPlan = plan;
        break;
      }
    }

    selectedPlan ??= plans.isEmpty ? null : plans.first;
    if (selectedPlan == null) {
      return false;
    }

    if (provider == PremiumPaymentProvider.stripe) {
      return selectedPlan.stripeCheckoutEnabled;
    }

    final productId = selectedPlan.productIdFor(provider);
    return storeAvailable &&
        productId != null &&
        availableStoreProductIds.contains(productId);
  }

  _BillingPeriod _billingPeriodKey(PremiumPlanModel plan) {
    final value = '${plan.billingInterval}:${plan.planCode}'.toLowerCase();
    if (value.contains('year') || value.contains('annual')) {
      return _BillingPeriod.yearly;
    }

    if (value.contains('month')) {
      return _BillingPeriod.monthly;
    }

    return _BillingPeriod.other;
  }
}

enum _BillingPeriod { monthly, yearly, other }
