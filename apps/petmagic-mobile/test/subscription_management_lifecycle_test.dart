import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/subscription_management_page.dart';
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
      await tester.pump(const Duration(milliseconds: 50));

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
