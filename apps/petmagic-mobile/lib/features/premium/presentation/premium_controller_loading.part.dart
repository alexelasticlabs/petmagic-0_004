part of 'premium_controller.dart';

mixin _PremiumControllerLoading
    on _PremiumControllerBase, _PremiumControllerLifecycle {
  @override
  Future<void> load({bool refresh = false}) async {
    final inFlight = _loadInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final loadCancelToken = _startLoadCancelToken();
    final isAuthenticated = ref
        .read(appLaunchControllerProvider)
        .isAuthenticated;
    final operation = () async {
      _updateStateIfMounted(
        (state) => state.copyWith(
          isLoading: !refresh,
          clearError: true,
          clearExternalUrl: true,
          clearSuccess: true,
        ),
      );

      try {
        final results = await Future.wait<Object>([
          _repository.fetchPaywallConfig(
            locale: WidgetsBinding.instance.platformDispatcher.locale,
            cancelToken: loadCancelToken,
          ),
          if (isAuthenticated)
            _repository.fetchStatus(cancelToken: loadCancelToken)
          else
            Future<PremiumStatusModel>.value(_guestPremiumStatus),
        ]);
        if (!ref.mounted || loadCancelToken.isCancelled) {
          return;
        }

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
        if (!ref.mounted || loadCancelToken.isCancelled) {
          return;
        }

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

        _updateStateIfMounted(
          (state) => state.copyWith(
            plans: plans,
            paymentMethods: config.paymentMethods,
            status: status,
            legalTexts: config.legalTexts,
            selectedPlanCode: selectedPlanCode,
            selectedProvider: selectedProvider,
            isStoreAvailable: storeAvailability.isAvailable,
            availableStoreProductIds: storeAvailability.productIds,
            storeProductPrices: storeAvailability.productPrices,
            isLoading: false,
            clearError: true,
          ),
        );
      } on RequestCancelledException {
        return;
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) {
          return;
        }
        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoading: false,
            errorMessage: _premiumErrorMessage(error, 'premium.plans_failed'),
          ),
        );
      } catch (error) {
        _updateStateIfMounted(
          (state) => state.copyWith(
            isLoading: false,
            errorMessage: _premiumErrorMessage(error, 'premium.plans_failed'),
          ),
        );
      } finally {
        _clearActiveLoad(loadCancelToken);
      }
    }();

    _loadInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_loadInFlight, operation)) {
        _loadInFlight = null;
      }
    }
  }

  @override
  void selectPlan(String planCode) {
    state = state.copyWith(
      selectedPlanCode: planCode,
      clearError: true,
      clearSuccess: true,
      clearCheckoutError: true,
    );
  }

  @override
  void selectProvider(PremiumPaymentProvider provider) {
    state = state.copyWith(
      selectedProvider: provider,
      clearError: true,
      clearSuccess: true,
      clearCheckoutError: true,
    );
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

  Future<
    ({
      bool isAvailable,
      Set<String> productIds,
      Map<String, String> productPrices,
    })
  >
  _resolveStoreAvailability(
    List<PremiumPlanModel> plans,
    List<PremiumPaymentProvider> providers,
  ) async {
    var isAvailable = false;
    final productIds = <String>{};
    final productPrices = <String, String>{};

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
        productPrices.addAll(availability.productPrices);
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

    return (
      isAvailable: isAvailable,
      productIds: productIds,
      productPrices: productPrices,
    );
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
