import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

part 'premium_controller_checkout.part.dart';
part 'premium_controller_errors.part.dart';
part 'premium_controller_lifecycle.part.dart';
part 'premium_controller_loading.part.dart';

final premiumControllerProvider =
    NotifierProvider<PremiumController, PremiumState>(PremiumController.new);

typedef PremiumRefreshProfile = Future<void> Function();

final premiumRefreshProfileProvider = Provider<PremiumRefreshProfile>((ref) {
  return () => ref.read(profileControllerProvider.notifier).initialize();
});

final premiumPurchaseUpdatesProvider =
    StreamProvider.autoDispose<List<PurchaseDetails>>((ref) {
      return ref.watch(premiumRepositoryProvider).purchaseUpdates;
    });

enum PremiumCheckoutVerificationState {
  idle,
  checking,
  activated,
  pending,
  error,
}

enum PremiumSubscriptionProviderView { stripe, googlePlay, appStore, unknown }

const PremiumStatusModel _guestPremiumStatus = PremiumStatusModel(
  isPremium: false,
  canManageBilling: false,
  status: 'None',
  cancelAtPeriodEnd: false,
  monthlyTokenLimit: 0,
  tokensAvailable: 0,
  canManageSubscription: false,
  manageSubscriptionAction: '',
);

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
  AppLogger.error(
    feature: 'Premium',
    operation: stage,
    message: 'Premium checkout step failed',
    context: {'stage': stage},
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
  AppLogger.warn(
    feature: 'Premium',
    operation: stage,
    message: 'Premium load step failed',
    context: {'stage': stage, ...context},
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
    this.storeProductPrices = const <String, String>{},
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
  final Map<String, String> storeProductPrices;
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
    if (isBuying || isPremium || recentlyActivatedPremium) {
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

  String? storePriceFor(PremiumPlanModel plan) {
    if (selectedProvider == PremiumPaymentProvider.stripe) {
      return null;
    }

    final productId = plan.productIdFor(selectedProvider);
    if (productId == null || productId.isEmpty) {
      return null;
    }

    return storeProductPrices[productId];
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
    Map<String, String>? storeProductPrices,
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
      storeProductPrices: storeProductPrices ?? this.storeProductPrices,
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

abstract class _PremiumControllerBase extends Notifier<PremiumState> {
  late PremiumRepository _repository;
  late PremiumRefreshProfile _refreshProfile;
  Future<void>? _loadInFlight;
  CancelToken? _activeLoadCancelToken;
  bool _premiumLifecycleStarted = false;

  Future<void> load({bool refresh = false});

  void selectPlan(String planCode);

  void selectProvider(PremiumPaymentProvider provider);

  Future<PremiumCheckoutModel?> startCheckout();

  Future<void> manageBilling();

  Future<void> restorePurchases();

  void consumeExternalUrl();

  void markCheckoutOpened({required bool wasPremiumBeforeCheckout});

  Future<void> verifyCheckoutStatus({
    String? stripePlanCode,
    String? stripeExternalSubscriptionId,
  });

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases);
}

class PremiumController extends _PremiumControllerBase
    with
        _PremiumControllerLifecycle,
        _PremiumControllerLoading,
        _PremiumControllerCheckout {
  @override
  PremiumState build() {
    _repository = ref.watch(premiumRepositoryProvider);
    _refreshProfile = ref.watch(premiumRefreshProfileProvider);
    _ensurePremiumLifecycleStarted();
    return const PremiumState(isLoading: true);
  }
}

enum _BillingPeriod { monthly, yearly, other }
