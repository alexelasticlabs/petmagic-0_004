import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';

final premiumControllerProvider =
    NotifierProvider<PremiumController, PremiumState>(PremiumController.new);

class PremiumState {
  const PremiumState({
    this.plans = const [],
    this.status,
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
  });

  final List<PremiumPlanModel> plans;
  final PremiumStatusModel? status;
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

  bool get canStartCheckout {
    final plan = selectedPlan;
    if (plan == null) {
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
    if (provider == PremiumPaymentProvider.stripe) {
      return true;
    }

    final plan = selectedPlan;
    final productId = plan?.productIdFor(provider);
    return isStoreAvailable &&
        productId != null &&
        availableStoreProductIds.contains(productId);
  }

  List<PremiumPaymentProvider> get availableProviders {
    final providers = <PremiumPaymentProvider>[PremiumPaymentProvider.stripe];
    if (Platform.isAndroid) {
      providers.add(PremiumPaymentProvider.googlePlay);
    }
    if (Platform.isIOS) {
      providers.add(PremiumPaymentProvider.appStore);
    }
    return providers;
  }

  PremiumState copyWith({
    List<PremiumPlanModel>? plans,
    PremiumStatusModel? status,
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
    bool clearError = false,
    bool clearExternalUrl = false,
    bool clearSuccess = false,
  }) {
    return PremiumState(
      plans: plans ?? this.plans,
      status: status ?? this.status,
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
        _repository.fetchPlans(),
        _repository.fetchStatus(),
      ]);

      final plans = results[0] as List<PremiumPlanModel>;
      final status = results[1] as PremiumStatusModel;
      final storeProvider = _platformStoreProvider();
      var storeAvailable = false;
      var availableStoreProductIds = <String>{};

      if (storeProvider != null) {
        try {
          final availability = await _repository.fetchStoreAvailability(
            plans,
            storeProvider,
          );
          storeAvailable = availability.isAvailable;
          availableStoreProductIds = availability.productIds;
        } catch (_) {
          storeAvailable = false;
          availableStoreProductIds = <String>{};
        }
      }

      final selectedPlanCode =
          plans.any((plan) => plan.planCode == state.selectedPlanCode)
          ? state.selectedPlanCode
          : plans.isEmpty
          ? state.selectedPlanCode
          : plans.last.planCode;

      state = state.copyWith(
        plans: plans,
        status: status,
        selectedPlanCode: selectedPlanCode,
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

  Future<void> startCheckout() async {
    final plan = state.selectedPlan;
    if (plan == null) {
      return;
    }

    state = state.copyWith(
      isBuying: true,
      clearError: true,
      clearExternalUrl: true,
      clearSuccess: true,
    );

    try {
      if (state.selectedProvider == PremiumPaymentProvider.stripe) {
        final checkout = await _repository.createStripeCheckout(plan);
        state = state.copyWith(
          isBuying: false,
          externalUrl: checkout.checkoutUrl,
        );
        return;
      }

      if (!state.canStartCheckout) {
        state = state.copyWith(
          isBuying: false,
          errorMessage: 'premium.store_product_unavailable',
        );
        return;
      }

      await _repository.startStoreCheckout(plan, state.selectedProvider);
    } catch (error) {
      state = state.copyWith(isBuying: false, errorMessage: error.toString());
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
      final portal = await _repository.createBillingPortal();
      state = state.copyWith(isManaging: false, externalUrl: portal.portalUrl);
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

  void clearExternalUrl() {
    state = state.copyWith(clearExternalUrl: true);
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
