import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';

void main() {
  testWidgets('shared non-english locales use polished startup/auth/profile copy', (
    tester,
  ) async {
    Future<AppLocalizations> load(Locale locale) async {
      late AppLocalizations text;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
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
      return text;
    }

    final de = await load(const Locale('de'));
    expect(de.premiumLabel, 'Premium');
    expect(de.profileLoadingAction, 'Wird verarbeitet...');
    expect(de.startupOnboardingActionStart, 'Loslegen');
    expect(de.authRegisterAction, 'Registrieren');
    expect(de.templateTryAction, 'Vorlage ausprobieren');

    final fr = await load(const Locale('fr'));
    expect(fr.premiumLabel, 'Premium');
    expect(fr.profileLoadingAction, 'Chargement...');
    expect(fr.retryAction, 'Réessayer');
    expect(fr.profileAccountCenterTitle, 'Centre du compte');
    expect(fr.profilePetsTitle, 'Mes animaux');

    final it = await load(const Locale('it'));
    expect(it.premiumLabel, 'Premium');
    expect(it.profileLoadingAction, 'Caricamento...');
    expect(it.authRegisterAction, 'Registrati');
    expect(it.profileAccountCenterTitle, 'Centro account');
    expect(it.profileStatOn, 'Attivo');

    final pl = await load(const Locale('pl'));
    expect(pl.premiumLabel, 'Premium');
    expect(pl.profileLoadingAction, 'Trwa ładowanie...');
    expect(pl.retryAction, 'Spróbuj ponownie');
    expect(pl.authRegisterAction, 'Zarejestruj się');
    expect(pl.profilePetsTitle, 'Moje pupile');
  });
}
