import 'dart:async';
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
    this.currentPeriodEndUtc,
    this.cancelAtPeriodEnd,
    this.monthlyTokenLimit,
    this.tokensAvailable,
  });

  final bool isPremium;
  final bool canManageSubscription;
  final String status;
  final String? planName;
  final DateTime? currentPeriodEndUtc;
  final bool? cancelAtPeriodEnd;
  final int? monthlyTokenLimit;
  final int? tokensAvailable;
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
      currentPeriodEndUtc: status.currentPeriodEndUtc,
      cancelAtPeriodEnd: status.cancelAtPeriodEnd,
      monthlyTokenLimit: status.monthlyTokenLimit,
      tokensAvailable: status.tokensAvailable,
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

    return plans.isEmpty ? null : plans.last;
  }

  bool get isPremium => status?.isPremium == true;

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
    final plan = selectedPlan;
    if (plan == null) {
      return false;
    }

    final paymentMethod = selectedPaymentMethod;
    if (paymentMethod == null) {
      return false;
    }

    if (selectedProvider == PremiumPaymentProvider.stripe) {
      return true;
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
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  PremiumState build() {
    _repository = ref.watch(premiumRepositoryProvider);
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
      final plans = config.plans;
      const storeAvailable = false;
      const availableStoreProductIds = <String>{};

      final selectedPlanCode =
          plans.any((plan) => plan.planCode == config.recommendedPlanCode)
          ? config.recommendedPlanCode!
          : plans.any((plan) => plan.planCode == state.selectedPlanCode)
          ? state.selectedPlanCode
          : plans.isEmpty
          ? state.selectedPlanCode
          : plans.last.planCode;

      final enabledMethods = config.paymentMethods
          .where((method) => method.isEnabled)
          .toList(growable: false);
      final configuredProviders = enabledMethods
          .map((method) => method.provider)
          .toList(growable: false);
        final stripeIsEnabled = configuredProviders.contains(
        PremiumPaymentProvider.stripe,
        );
      final defaultProvider = enabledMethods
          .where((method) => method.isSelectedByDefault)
          .map((method) => method.provider)
          .cast<PremiumPaymentProvider?>()
          .firstOrNull;

      final selectedProvider =
          stripeIsEnabled
          ? PremiumPaymentProvider.stripe
          : configuredProviders.contains(state.selectedProvider)
          ? state.selectedProvider
          : defaultProvider ??
                (configuredProviders.isEmpty
                    ? state.selectedProvider
                    : configuredProviders.first);

      state = state.copyWith(
        plans: plans,
        paymentMethods: config.paymentMethods,
        status: status,
        legalTexts: config.legalTexts,
        selectedPlanCode: selectedPlanCode,
        selectedProvider: selectedProvider,
        isStoreAvailable: storeAvailable,
        availableStoreProductIds: availableStoreProductIds,
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
    );
  }

  void selectProvider(PremiumPaymentProvider provider) {
    state = state.copyWith(
      selectedProvider: provider,
      clearError: true,
      clearSuccess: true,
    );
  }

  Future<PremiumCheckoutModel?> startCheckout() async {
    final plan = state.selectedPlan;
    if (plan == null) {
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
        if (checkout.usesPaymentSheet) {
          state = state.copyWith(isBuying: false);
          return checkout;
        }

        final checkoutUrl = checkout.checkoutUrl.trim();
        if (checkoutUrl.isEmpty) {
          state = state.copyWith(
            isBuying: false,
            errorMessage: 'premium.checkout_failed',
          );
          return null;
        }

        state = state.copyWith(isBuying: false, externalUrl: checkoutUrl);
        return null;
      }

      if (!state.canStartCheckout) {
        state = state.copyWith(
          isBuying: false,
          errorMessage: 'premium.store_product_unavailable',
        );
        return null;
      }

      await _repository.startStoreCheckout(plan, state.selectedProvider);
    } catch (error) {
      state = state.copyWith(isBuying: false, errorMessage: error.toString());
    }

    return null;
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

    await ref.read(profileControllerProvider.notifier).initialize();
    await load(refresh: true);

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

  Future<void> verifyCheckoutStatus() async {
    if (!state.isAwaitingCheckoutVerification) {
      return;
    }

    state = state.copyWith(
      checkoutVerificationState: PremiumCheckoutVerificationState.checking,
      clearCheckoutError: true,
      recentlyActivatedPremium: false,
    );

    const maxAttempts = 4;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await ref.read(profileControllerProvider.notifier).initialize();
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
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyStorePurchase(purchase);
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _repository.completePurchase(purchase);
          }

          state = state.copyWith(
            isBuying: false,
            isRestoring: false,
            errorMessage: purchase.error?.message ?? 'premium.checkout_failed',
          );
        case PurchaseStatus.canceled:
          state = state.copyWith(
            isBuying: false,
            isRestoring: false,
            errorMessage: 'premium.purchase_cancelled',
          );
      }
    }
  }

  Future<void> _verifyStorePurchase(PurchaseDetails purchase) async {
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
      await _repository.verifyStorePurchase(
        plan: matchedPlan,
        provider: provider,
        purchase: purchase,
      );

      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
      }

      await ref.read(profileControllerProvider.notifier).initialize();
      await load(refresh: true);

      state = state.copyWith(
        isBuying: false,
        isRestoring: false,
        successMessage: 'premium.purchase_activated',
      );
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
}
