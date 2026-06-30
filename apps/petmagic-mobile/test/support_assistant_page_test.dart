import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/support/presentation/support_assistant_page.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

void main() {
  test('support assistant route preserves scenario query', () {
    final uri = Uri.parse(SupportAssistantPage.location('Payment Refund'));
    expect(uri.path, SupportAssistantPage.routePath);
    expect(
      uri.queryParameters[SupportAssistantPage.scenarioQueryParam],
      'Payment Refund',
    );
    expect(SupportAssistantPage.location('  '), SupportAssistantPage.routePath);
  });

  testWidgets('support assistant shows auth gate for guests', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _UnauthenticatedAppLaunchController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SupportAssistantPage(scenario: 'Other'),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.text('Create support ticket'), findsNothing);
  });
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
