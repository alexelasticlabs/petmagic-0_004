import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';

void main() {
  testWidgets('spanish locale uses polished production copy', (tester) async {
    late AppLocalizations text;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            text = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(text.premiumLabel, 'Premium');
    expect(text.profileLoadingAction, 'Procesando...');
    expect(text.retryAction, 'Reintentar');
    expect(text.startupOnboardingActionStart, 'Empezar');
    expect(text.startupMiniFeatureFastStart, 'Inicio rápido');
    expect(text.authRegisterAction, 'Registrarse');
    expect(text.templateTryAction, 'Probar plantilla');
    expect(text.profileAccountCenterTitle, 'Centro de cuenta');
    expect(text.profileStatOn, 'Activado');
    expect(text.profilePetsTitle, 'Mis mascotas');
  });
}
