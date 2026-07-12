import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';
import 'package:petmagic_mobile/features/premium/application/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';

void main() {
  test(
    'premium subscription summary cancels status request on dispose',
    () async {
      final repository = _CancellablePremiumStatusRepository();
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          networkStatusControllerProvider.overrideWith(
            () => _TestNetworkStatusController(initialHasInternet: true),
          ),
        ],
      );

      final future = container.read(premiumSubscriptionSummaryProvider.future);
      final cancelToken = await repository.statusStarted.future;
      expect(cancelToken.isCancelled, isFalse);

      container.dispose();

      expect(cancelToken.isCancelled, isTrue);
      await expectLater(future, throwsA(isA<RequestCancelledException>()));
    },
  );

  test(
    'premium subscription summary keeps warm cache across short detach',
    () async {
      final repository = _CountingPremiumStatusRepository();
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          networkStatusControllerProvider.overrideWith(
            () => _TestNetworkStatusController(initialHasInternet: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container
          .listen<AsyncValue<PremiumSubscriptionSummaryView>>(
            premiumSubscriptionSummaryProvider,
            (_, __) {},
          );

      await container.read(premiumSubscriptionSummaryProvider.future);
      expect(repository.fetchStatusCalls, 1);

      subscription.close();
      expect(container.exists(premiumSubscriptionSummaryProvider), isTrue);

      await container.read(premiumSubscriptionSummaryProvider.future);
      expect(repository.fetchStatusCalls, 1);
    },
  );

  test(
    'premium subscription summary skips private status fetch after sign out',
    () async {
      final repository = _CountingPremiumStatusRepository();
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _UnauthenticatedAppLaunchController.new,
          ),
          premiumRepositoryProvider.overrideWithValue(repository),
          networkStatusControllerProvider.overrideWith(
            () => _TestNetworkStatusController(initialHasInternet: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container
          .listen<AsyncValue<PremiumSubscriptionSummaryView>>(
            premiumSubscriptionSummaryProvider,
            (_, _) {},
            fireImmediately: true,
          );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);

      expect(
        subscription.read().error,
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'auth.session_expired',
        ),
      );
      expect(repository.fetchStatusCalls, 0);
    },
  );

  test('linked accounts provider cancels request on dispose', () async {
    final repository = _CancellableProfileProviderRepository();
    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _AuthenticatedAppLaunchController.new,
        ),
        profileRepositoryProvider.overrideWithValue(repository),
        networkStatusControllerProvider.overrideWith(
          () => _TestNetworkStatusController(initialHasInternet: true),
        ),
      ],
    );

    final future = container.read(linkedAccountsProvider.future);
    final cancelToken = await repository.linkedAccountsStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    container.dispose();

    expect(cancelToken.isCancelled, isTrue);
    await expectLater(future, throwsA(isA<RequestCancelledException>()));
  });

  test(
    'linked accounts provider keeps warm cache across short detach',
    () async {
      final repository = _CountingProfileProviderRepository();
      final container = ProviderContainer(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          profileRepositoryProvider.overrideWithValue(repository),
          networkStatusControllerProvider.overrideWith(
            () => _TestNetworkStatusController(initialHasInternet: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container
          .listen<AsyncValue<List<MobileLinkedAccount>>>(
            linkedAccountsProvider,
            (_, __) {},
          );

      await container.read(linkedAccountsProvider.future);
      expect(repository.linkedAccountsFetchCount, 1);

      subscription.close();
      expect(container.exists(linkedAccountsProvider), isTrue);

      await container.read(linkedAccountsProvider.future);
      expect(repository.linkedAccountsFetchCount, 1);
    },
  );

  test('linked accounts provider skips private fetch after sign out', () async {
    final repository = _CountingProfileProviderRepository();
    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _UnauthenticatedAppLaunchController.new,
        ),
        profileRepositoryProvider.overrideWithValue(repository),
        networkStatusControllerProvider.overrideWith(
          () => _TestNetworkStatusController(initialHasInternet: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container
        .listen<AsyncValue<List<MobileLinkedAccount>>>(
          linkedAccountsProvider,
          (_, _) {},
          fireImmediately: true,
        );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    expect(
      subscription.read().error,
      isA<AppException>().having(
        (error) => error.message,
        'message',
        'auth.session_expired',
      ),
    );
    expect(repository.linkedAccountsFetchCount, 0);
  });

  test('current legal documents provider cancels request on dispose', () async {
    final repository = _CancellableProfileProviderRepository();
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        networkStatusControllerProvider.overrideWith(
          () => _TestNetworkStatusController(initialHasInternet: true),
        ),
      ],
    );

    final future = container.read(currentLegalDocumentsProvider('en').future);
    final cancelToken = await repository.legalDocumentsStarted.future;
    expect(cancelToken.isCancelled, isFalse);

    container.dispose();

    expect(cancelToken.isCancelled, isTrue);
    await expectLater(future, throwsA(isA<RequestCancelledException>()));
  });
}

class _CancellablePremiumStatusRepository extends PremiumRepository {
  _CancellablePremiumStatusRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<CancelToken> statusStarted = Completer<CancelToken>();

  @override
  Future<PremiumStatusModel> fetchStatus({CancelToken? cancelToken}) async {
    final token = cancelToken ?? CancelToken();
    if (!statusStarted.isCompleted) {
      statusStarted.complete(token);
    }
    await token.whenCancel;
    throw const RequestCancelledException();
  }
}

class _CountingPremiumStatusRepository extends PremiumRepository {
  _CountingPremiumStatusRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int fetchStatusCalls = 0;

  @override
  Future<PremiumStatusModel> fetchStatus({CancelToken? cancelToken}) async {
    fetchStatusCalls++;
    return const PremiumStatusModel(
      isPremium: true,
      canManageBilling: true,
      paymentProvider: 'stripe',
      purchaseChannel: 'external_checkout',
      status: 'Active',
      cancelAtPeriodEnd: false,
      monthlyTokenLimit: 500,
      tokensAvailable: 240,
      canManageSubscription: true,
      manageSubscriptionAction: 'StripeCustomerPortal',
    );
  }
}

class _CancellableProfileProviderRepository extends ProfileRepository {
  _CancellableProfileProviderRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<CancelToken> linkedAccountsStarted = Completer<CancelToken>();
  final Completer<CancelToken> legalDocumentsStarted = Completer<CancelToken>();

  @override
  Future<List<MobileLinkedAccount>> fetchLinkedAccounts({
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    if (!linkedAccountsStarted.isCompleted) {
      linkedAccountsStarted.complete(token);
    }
    await token.whenCancel;
    throw const RequestCancelledException();
  }

  @override
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    if (!legalDocumentsStarted.isCompleted) {
      legalDocumentsStarted.complete(token);
    }
    await token.whenCancel;
    throw const RequestCancelledException();
  }
}

class _CountingProfileProviderRepository extends ProfileRepository {
  _CountingProfileProviderRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int linkedAccountsFetchCount = 0;

  @override
  Future<List<MobileLinkedAccount>> fetchLinkedAccounts({
    CancelToken? cancelToken,
  }) async {
    linkedAccountsFetchCount++;
    return const [
      MobileLinkedAccount(
        provider: 'Google',
        displayName: 'pet@example.com',
        canDisconnect: true,
      ),
    ];
  }
}

class _TestNetworkStatusController extends NetworkStatusController {
  _TestNetworkStatusController({required this.initialHasInternet});

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }
}

class _AuthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _UnauthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}
