import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';

void main() {
  testWidgets('maps legal acceptance feedback consistently', (tester) async {
    late AppLocalizations text;

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          text = AppLocalizations.of(context);
          return child ?? const SizedBox.shrink();
        },
      ),
    );

    expect(
      isLegalAcceptanceRequiredError(
        'AppException: auth.legal_acceptance_required',
      ),
      isTrue,
    );
    expect(
      mapCommonAuthFeedbackMessage(
        text,
        'AppException: auth.legal_acceptance_required',
      ),
      text.profileLegalAcceptanceRequired,
    );
  });

  testWidgets('maps sign-in and session auth feedback consistently', (
    tester,
  ) async {
    late AppLocalizations text;

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          text = AppLocalizations.of(context);
          return child ?? const SizedBox.shrink();
        },
      ),
    );

    expect(
      mapCommonAuthFeedbackMessage(text, 'auth.sign_in_required'),
      text.authSignInRequired,
    );
    expect(
      mapCommonAuthFeedbackMessage(
        text,
        'auth.sign_in_required',
        preferAuthRequiredMessage: true,
      ),
      text.authRequiredMessage,
    );
    expect(
      mapCommonAuthFeedbackMessage(text, 'AppException: auth.session_expired'),
      text.authSessionExpired,
    );
  });
}
