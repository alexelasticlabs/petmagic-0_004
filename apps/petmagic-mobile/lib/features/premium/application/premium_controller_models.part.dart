part of 'premium_controller.dart';

final premiumControllerProvider =
    NotifierProvider<PremiumController, PremiumState>(PremiumController.new);

typedef PremiumRefreshProfile = Future<void> Function();

final premiumRefreshProfileProvider = Provider<PremiumRefreshProfile>((ref) {
  return () => ref.read(profileControllerProvider.notifier).initialize();
});

final premiumPurchaseUpdatesProvider =
    StreamProvider.autoDispose<List<StorePurchaseDetails>>((ref) {
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

const _premiumProviderCacheTtl = Duration(minutes: 5);

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
      if (!ref.watch(
        appLaunchControllerProvider.select((state) => state.isAuthenticated),
      )) {
        throw const AppException('auth.session_expired');
      }

      if (!ref.read(networkStatusControllerProvider).hasInternet) {
        throw const AppException('templates.network_unavailable');
      }

      final link = ref.keepAlive();
      Timer? disposeTimer;
      ref.onCancel(() {
        disposeTimer?.cancel();
        disposeTimer = Timer(_premiumProviderCacheTtl, link.close);
      });
      ref.onResume(() {
        disposeTimer?.cancel();
        disposeTimer = null;
      });
      final repository = ref.watch(premiumRepositoryProvider);
      final cancelToken = RequestCancellation();
      ref.onDispose(() {
        disposeTimer?.cancel();
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('premium_summary_cancelled');
        }
      });
      final status = await repository.fetchStatus(cancelToken: cancelToken);
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
    required PremiumRepositoryPort repository,
  }) : _repository = repository;

  final PremiumRepositoryPort _repository;

  Future<String> createManagementUrl(
    String manageSubscriptionAction, {
    RequestCancellation? cancelToken,
  }) async {
    switch (manageSubscriptionAction) {
      case 'AppleSettings':
        return 'https://apps.apple.com/account/subscriptions';
      case 'GooglePlaySettings':
        return 'https://play.google.com/store/account/subscriptions';
      case 'StripeCustomerPortal':
        final portal = await _repository.createBillingPortal(
          cancelToken: cancelToken,
        );
        return portal.portalUrl;
      default:
        throw const AppException('premium.manage_failed');
    }
  }

  Future<PremiumSubscriptionSummaryView> requestCancelAtPeriodEnd({
    RequestCancellation? cancelToken,
  }) async {
    final status = await _repository.cancelSubscription(
      cancelToken: cancelToken,
    );
    return PremiumSubscriptionSummaryView.fromStatus(status);
  }
}
