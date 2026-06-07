import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/subscription_management_page.dart';

void main() {
  testWidgets(
    'restore completion is ignored after subscription page disposal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final premiumController = _DelayedRestorePremiumController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
