import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/subscription_management_page.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

void main() {
  test('subscription management dynamic copy uses localizations', () async {
    final pageSource = await File(
      'lib/features/premium/presentation/subscription_management_page.dart',
    ).readAsString();
    final contentSource = await File(
      'lib/features/premium/presentation/subscription_management_content.part.dart',
    ).readAsString();
    final sectionsSource = await File(
      'lib/features/premium/presentation/subscription_management_sections.part.dart',
    ).readAsString();
    final progressSource = await File(
      'lib/features/premium/presentation/subscription_management_progress.part.dart',
    ).readAsString();
    final source =
        '$pageSource\n$contentSource\n$sectionsSource\n$progressSource';

    const expectedGetters = <String>[
      'subscriptionTokensWeeklyGrantPeriodSuffix',
      'subscriptionGrantCountdownDaysHoursMinutes',
      'subscriptionGrantCountdownHoursMinutesSeconds',
      'subscriptionGrantCountdownMinutesSeconds',
      'subscriptionGrantReadyLabel',
      'subscriptionGrantNextLabel',
      'subscriptionBenefitTokensDescription',
      'subscriptionBenefitFirstBonusDescription',
      'subscriptionBenefitTemplatesDescription',
      'subscriptionBenefitPriorityGenerationDescription',
      'subscriptionBenefitNoWatermarkDescription',
    ];
    const removedLiterals = <String>[
      ' / 7д',
      'Готово к начислению',
      'Следующее начисление',
      'Автоматически каждые 7 дней',
      'Мгновенно при покупке',
      'Все сценарии разблокированы',
      'Ваши задачи в приоритете',
      'Чистый результат',
    ];

    for (final getter in expectedGetters) {
      expect(source, contains(getter));
    }
    for (final literal in removedLiterals) {
      expect(source, isNot(contains(literal)));
    }
    expect(
      sectionsSource,
      contains('summary.planName ?? text.premiumPageTitle'),
    );
    expect(
      sectionsSource,
      isNot(contains("summary.planName ?? 'PetMagic Premium'")),
    );
    expect(
      pageSource,
      contains("part 'subscription_management_content.part.dart';"),
    );
    expect(
      pageSource,
      contains("part 'subscription_management_sections.part.dart';"),
    );
    expect(
      pageSource,
      contains("part 'subscription_management_progress.part.dart';"),
    );
    expect(pageSource, isNot(contains('class _SubscriptionContent')));
    expect(contentSource, contains('class _SubscriptionContent'));
    expect(contentSource, isNot(contains('class _PremiumHeroCard')));
    expect(contentSource, isNot(contains('class _TokensCard')));
    expect(contentSource, isNot(contains('class _BenefitsCard')));
    expect(contentSource, isNot(contains('class _PaymentCard')));
    expect(contentSource, isNot(contains('class _ActionsSection')));
    expect(contentSource, isNot(contains('class _TokenGrantProgressBar')));
    expect(
      sectionsSource,
      contains("part of 'subscription_management_page.dart';"),
    );
    expect(sectionsSource, contains('class _PremiumHeroCard'));
    expect(sectionsSource, contains('class _TokensCard'));
    expect(sectionsSource, contains('class _BenefitsCard'));
    expect(sectionsSource, contains('class _PaymentCard'));
    expect(sectionsSource, contains('class _ActionsSection'));
    expect(sectionsSource, contains('String _resolveStatusLabel'));
    expect(sectionsSource, contains('Color _resolveStatusColor'));
    expect(sectionsSource, contains('final manageColor = colors.gold;'));
    expect(sectionsSource, contains('foregroundColor: colors.on(manageColor)'));
    expect(
      sectionsSource,
      contains('backgroundColor: isLight ? colors.surface : null'),
    );
    expect(
      sectionsSource,
      contains('foregroundColor: isLight ? colors.textStrong : null'),
    );
    expect(
      sectionsSource,
      isNot(contains('const manageColor = Color(0xFFFFC107)')),
    );
    expect(
      sectionsSource,
      isNot(contains('foregroundColor: const Color(0xFF261903)')),
    );
    expect(
      sectionsSource,
      isNot(contains('foregroundColor: isLight ? const Color(0xFF2F3E56)')),
    );
    expect(
      progressSource,
      contains("part of 'subscription_management_page.dart';"),
    );
    expect(progressSource, contains('class _TokenGrantProgressBar'));
  });

  test(
    'subscription management localization keys exist in every locale',
    () async {
      const arbFiles = <String>[
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ru.arb',
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pl.arb',
      ];
      const requiredKeys = <String>[
        'subscriptionTokensWeeklyGrantPeriodSuffix',
        'subscriptionGrantCountdownDaysHoursMinutes',
        'subscriptionGrantCountdownHoursMinutesSeconds',
        'subscriptionGrantCountdownMinutesSeconds',
        'subscriptionGrantReadyLabel',
        'subscriptionGrantNextLabel',
        'subscriptionBenefitTokensDescription',
        'subscriptionBenefitFirstBonusDescription',
        'subscriptionBenefitTemplatesDescription',
        'subscriptionBenefitPriorityGenerationDescription',
        'subscriptionBenefitNoWatermarkDescription',
      ];

      for (final path in arbFiles) {
        final source = await File(path).readAsString();
        for (final key in requiredKeys) {
          expect(source, contains('"$key"'), reason: '$path is missing $key');
        }
      }
    },
  );

  test('subscription grant countdown uses adaptive low-traffic ticker', () async {
    final progressSource = await File(
      'lib/features/premium/presentation/subscription_management_progress.part.dart',
    ).readAsString();

    expect(progressSource, contains('void _scheduleNextTick()'));
    expect(progressSource, contains('Duration? _nextTickInterval()'));
    expect(
      progressSource,
      contains('with SingleTickerProviderStateMixin, WidgetsBindingObserver'),
    );
    expect(
      progressSource,
      contains('WidgetsBinding.instance.addObserver(this)'),
    );
    expect(
      progressSource,
      contains('WidgetsBinding.instance.removeObserver(this)'),
    );
    expect(progressSource, contains('void didChangeAppLifecycleState'));
    expect(progressSource, contains('bool _shouldRunTicker()'));
    expect(progressSource, contains('TickerMode.valuesOf(context).enabled'));
    expect(
      progressSource,
      contains('lifecycle == null || lifecycle == AppLifecycleState.resumed'),
    );
    expect(progressSource, contains('Timer(interval, ()'));
    expect(progressSource, contains('const Duration(minutes: 1)'));
    expect(progressSource, contains('const Duration(hours: 1)'));
    expect(progressSource, contains('_ticker?.cancel();'));
    expect(progressSource, contains('_controller.dispose();'));
    expect(
      progressSource,
      isNot(contains('Timer.periodic(const Duration(seconds: 1)')),
    );
  });

  test('subscription management actions are cancellable on dispose', () async {
    final pageSource = await File(
      'lib/features/premium/presentation/subscription_management_page.dart',
    ).readAsString();
    final controllerSource = await File(
      'lib/features/premium/presentation/premium_controller.dart',
    ).readAsString();
    final repositorySource = await File(
      'lib/features/premium/data/premium_repository.dart',
    ).readAsString();
    final openManageBody = _methodBody(
      pageSource,
      'Future<void> _openManageTarget',
    );
    final cancelBody = _methodBody(
      pageSource,
      'Future<void> _cancelAtPeriodEnd',
    );
    final disposeBody = _methodBody(pageSource, 'void dispose');
    final serviceCreateBody = _methodBody(
      controllerSource,
      'Future<String> createManagementUrl',
    );
    final serviceCancelBody = _methodBody(
      controllerSource,
      'Future<PremiumSubscriptionSummaryView> requestCancelAtPeriodEnd',
    );
    final repositoryPortalBody = _methodBody(
      repositorySource,
      'Future<PremiumBillingPortalModel> createBillingPortal',
    );
    final repositoryCancelBody = _methodBody(
      repositorySource,
      'Future<PremiumStatusModel> cancelSubscription',
    );

    expect(
      pageSource,
      contains('CancelToken? _activeSubscriptionActionCancelToken;'),
    );
    expect(disposeBody, contains('_cancelActiveSubscriptionAction();'));
    expect(openManageBody, contains('final cancelToken ='));
    expect(openManageBody, contains('cancelToken: cancelToken'));
    expect(openManageBody, contains('cancelToken.isCancelled'));
    expect(openManageBody, contains('CancelToken.isCancel(error)'));
    expect(
      openManageBody,
      contains('_completeSubscriptionAction(cancelToken)'),
    );
    expect(cancelBody, contains('final cancelToken ='));
    expect(cancelBody, contains('cancelToken: cancelToken'));
    expect(cancelBody, contains('cancelToken.isCancelled'));
    expect(cancelBody, contains('CancelToken.isCancel(error)'));
    expect(cancelBody, contains('_completeSubscriptionAction(cancelToken)'));
    expect(controllerSource, contains('CancelToken? cancelToken'));
    expect(serviceCreateBody, contains('createBillingPortal('));
    expect(serviceCreateBody, contains('cancelToken: cancelToken'));
    expect(
      controllerSource,
      contains(
        'Future<PremiumSubscriptionSummaryView> requestCancelAtPeriodEnd({',
      ),
    );
    expect(serviceCancelBody, contains('cancelSubscription('));
    expect(serviceCancelBody, contains('cancelToken: cancelToken'));
    expect(
      repositorySource,
      contains('Future<PremiumBillingPortalModel> createBillingPortal({'),
    );
    expect(repositorySource, contains('CancelToken? cancelToken'));
    expect(repositoryPortalBody, contains('cancelToken: cancelToken'));
    expect(
      repositorySource,
      contains('Future<PremiumStatusModel> cancelSubscription({'),
    );
    expect(repositoryCancelBody, contains('cancelToken: cancelToken'));
  });

  testWidgets(
    'subscription management shows auth gate for guests without loading summary',
    (tester) async {
      var summaryReads = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _UnauthenticatedAppLaunchController.new,
            ),
            premiumSubscriptionSummaryProvider.overrideWith((ref) async {
              summaryReads++;
              return const PremiumSubscriptionSummaryView(
                isPremium: true,
                canManageSubscription: true,
                status: 'active',
                manageSubscriptionAction: 'StripeCustomerPortal',
                provider: PremiumSubscriptionProviderView.stripe,
              );
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: const SubscriptionManagementPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(summaryReads, 0);
    },
  );

  testWidgets('subscription summary failure shows retry and reloads safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var loadAttempts = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumSubscriptionSummaryProvider.overrideWith((ref) async {
            loadAttempts++;
            if (loadAttempts == 1) {
              throw StateError('summary unavailable');
            }

            return const PremiumSubscriptionSummaryView(
              isPremium: true,
              canManageSubscription: true,
              status: 'active',
              manageSubscriptionAction: 'StripeCustomerPortal',
              provider: PremiumSubscriptionProviderView.stripe,
              planName: 'PetMagic Premium',
              cancelAtPeriodEnd: false,
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: const SubscriptionManagementPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(SubscriptionManagementPage));
    final text = AppLocalizations.of(context);

    expect(find.text(text.premiumManageFailed), findsOneWidget);
    expect(find.widgetWithText(FilledButton, text.retryAction), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, text.retryAction));
    await tester.pump();
    await tester.pump();

    expect(loadAttempts, 2);
    expect(find.text(text.premiumManageFailed), findsNothing);
    expect(find.text('PetMagic Premium'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'restore completion is ignored after subscription page disposal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final premiumController = _DelayedRestorePremiumController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
            premiumControllerProvider.overrideWith(() => premiumController),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: true,
                canManageSubscription: true,
                status: 'active',
                manageSubscriptionAction: 'StripeCustomerPortal',
                provider: PremiumSubscriptionProviderView.stripe,
                planName: 'PetMagic Premium',
                cancelAtPeriodEnd: false,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: const SubscriptionManagementPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final context = tester.element(find.byType(SubscriptionManagementPage));
      final text = AppLocalizations.of(context);

      final restoreButton = find.widgetWithText(
        OutlinedButton,
        text.premiumRestoreAction,
      );
      await tester.tap(restoreButton);
      await tester.tap(restoreButton);
      await tester.pump();

      expect(premiumController.restoreStarted.isCompleted, isTrue);
      expect(premiumController.restoreCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      premiumController.completeRestore();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('restore failure is handled without surfacing a raw exception', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          premiumControllerProvider.overrideWith(
            () => _FailingRestorePremiumController(),
          ),
          premiumSubscriptionSummaryProvider.overrideWith(
            (ref) async => const PremiumSubscriptionSummaryView(
              isPremium: true,
              canManageSubscription: true,
              status: 'active',
              manageSubscriptionAction: 'StripeCustomerPortal',
              provider: PremiumSubscriptionProviderView.stripe,
              planName: 'PetMagic Premium',
              cancelAtPeriodEnd: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: const SubscriptionManagementPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final context = tester.element(find.byType(SubscriptionManagementPage));
    final text = AppLocalizations.of(context);
    final restoreButton = find.widgetWithText(
      OutlinedButton,
      text.premiumRestoreAction,
    );

    await tester.tap(restoreButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(tester.widget<OutlinedButton>(restoreButton).onPressed, isNotNull);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'subscription page renders canonical canceled status as expired',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
            premiumSubscriptionSummaryProvider.overrideWith(
              (ref) async => const PremiumSubscriptionSummaryView(
                isPremium: true,
                canManageSubscription: true,
                status: 'Canceled',
                manageSubscriptionAction: 'StripeCustomerPortal',
                provider: PremiumSubscriptionProviderView.stripe,
                planName: 'PetMagic Premium',
                cancelAtPeriodEnd: false,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: const SubscriptionManagementPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final context = tester.element(find.byType(SubscriptionManagementPage));
      final text = AppLocalizations.of(context);

      expect(find.text(text.subscriptionStatusExpired), findsOneWidget);
      expect(find.text('PetMagic Premium'), findsWidgets);
    },
  );

  testWidgets(
    'subscription management stays offline without loading and retries on reconnect',
    (tester) async {
      final repository = _CountingSubscriptionManagementRepository();
      final networkController = _TestSubscriptionNetworkStatusController(
        initialHasInternet: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
            premiumRepositoryProvider.overrideWithValue(repository),
            networkStatusControllerProvider.overrideWith(
              () => networkController,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: const [Locale('en')],
            home: const SubscriptionManagementPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text("You're offline"), findsOneWidget);
      expect(repository.fetchStatusCalls, 0);

      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text("You're offline"), findsNothing);
      expect(repository.fetchStatusCalls, 1);
      expect(find.text('PetMagic Premium'), findsWidgets);
    },
  );
}

class _DelayedRestorePremiumController extends PremiumController {
  final restoreStarted = Completer<void>();
  final _restoreCompleter = Completer<void>();
  int restoreCalls = 0;

  @override
  PremiumState build() {
    return const PremiumState();
  }

  @override
  Future<void> restorePurchases() {
    restoreCalls++;
    if (!restoreStarted.isCompleted) {
      restoreStarted.complete();
    }
    return _restoreCompleter.future;
  }

  void completeRestore() {
    if (!_restoreCompleter.isCompleted) {
      _restoreCompleter.complete();
    }
  }
}

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: 'Missing method: $signature');

  final parameterStart = source.indexOf('(', start);
  expect(
    parameterStart,
    isNonNegative,
    reason: 'Missing method parameters: $signature',
  );
  final parameterEnd = _matchingCloseParen(source, parameterStart);
  final braceStart = source.indexOf('{', parameterEnd);
  expect(braceStart, isNonNegative, reason: 'Missing method body: $signature');

  var depth = 0;
  for (var index = braceStart; index < source.length; index += 1) {
    final character = source[index];
    if (character == '{') {
      depth += 1;
    } else if (character == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(braceStart, index + 1);
      }
    }
  }

  fail('Unclosed method body: $signature');
}

int _matchingCloseParen(String source, int openParenIndex) {
  var depth = 0;
  for (var index = openParenIndex; index < source.length; index += 1) {
    final character = source[index];
    if (character == '(') {
      depth += 1;
    } else if (character == ')') {
      depth -= 1;
      if (depth == 0) {
        return index;
      }
    }
  }

  fail('Unclosed method parameters.');
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

class _FailingRestorePremiumController extends PremiumController {
  @override
  PremiumState build() {
    return const PremiumState();
  }

  @override
  Future<void> restorePurchases() async {
    throw StateError('store restore failed');
  }
}

class _CountingSubscriptionManagementRepository extends PremiumRepository {
  _CountingSubscriptionManagementRepository()
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
      planName: 'PetMagic Premium',
    );
  }
}

class _TestSubscriptionNetworkStatusController extends NetworkStatusController {
  _TestSubscriptionNetworkStatusController({required this.initialHasInternet});

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}
