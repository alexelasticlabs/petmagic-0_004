import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ru localization does not keep English UI fallback labels', () {
    final ru = _readArb('lib/l10n/app_ru.arb');

    expect(ru['randomTemplateAccessPremium'], 'Премиум');
    expect(ru['premiumPremiumColumn'], 'Премиум');
    expect(ru['profileEmailLabel'], 'Эл. почта');
    expect(ru['profileNotificationsEmailSection'], 'Эл. почта');
    expect(ru['supportChatTeamTitle'], 'Поддержка PetMagic');
  });

  test('selected non-English UI labels avoid machine fallback copy', () {
    final de = _readArb('lib/l10n/app_de.arb');
    final es = _readArb('lib/l10n/app_es.arb');
    final fr = _readArb('lib/l10n/app_fr.arb');
    final it = _readArb('lib/l10n/app_it.arb');
    final pl = _readArb('lib/l10n/app_pl.arb');

    expect(de['profilePremiumOpenAction'], 'Upgraden');
    expect(de['emailVerificationCodeLabel'], 'Bestätigungscode');
    expect(de['gamificationLevel'], 'Stufe {level}');

    expect(es['profilePremiumOpenAction'], 'Mejorar');
    expect(es['profileStatBalanceLabel'], 'Saldo');
    expect(es['supportChatArchiveAction'], 'Archivar');

    expect(fr['profileStatBalanceLabel'], 'Solde');
    expect(fr['supportChatArchiveAction'], 'Archiver');

    expect(it['profilePremiumOpenAction'], 'Aggiorna');
    expect(it['profileStatBalanceLabel'], 'Saldo');
    expect(it['supportChatArchiveAction'], 'Archivia');
    expect(it['emailVerificationWorkingLabel'], 'Elaborazione...');

    expect(pl['profilePremiumOpenAction'], 'Ulepsz');
    expect(pl['profileStatBalanceLabel'], 'Saldo');
    expect(pl['supportChatArchiveAction'], 'Archiwizuj');
    expect(pl['achievementTrendsetter'], 'Kreator trendów');
  });

  test('es and pl localizations preserve critical diacritics in account flows', () async {
    final esSource = await File('lib/l10n/app_es.arb').readAsString();
    final plSource = await File('lib/l10n/app_pl.arb').readAsString();

    expect(esSource, contains('"rewardsYourReferralCode": "tu código"'));
    expect(
      esSource,
      contains(
        '"profileNotificationsPushNewTemplatesSubtitle": "Nuevos estilos y plantillas de generación"',
      ),
    );
    expect(
      esSource,
      contains(
        '"profileNotificationsPushPurchasesAndSubscriptionsSubtitle": "Confirmaciones de pago y estado de suscripción"',
      ),
    );
    expect(
      esSource,
      contains('"passwordChangeStepRequestCode": "Solicitar código"'),
    );
    expect(
      esSource,
      contains('"passwordChangeStepNewPassword": "Nueva contraseña"'),
    );
    expect(
      esSource,
      contains('"subscriptionGrantReadyLabel": "¡Listo para acreditar!"'),
    );
    expect(
      esSource,
      contains(
        '"subscriptionGrantNextLabel": "Próxima acreditación: {countdown}"',
      ),
    );
    expect(
      esSource,
      contains(
        '"subscriptionBenefitTokensDescription": "Automáticamente cada 7 días"',
      ),
    );

    expect(
      plSource,
      contains(
        '"profileNotificationsPushPurchasesAndSubscriptionsSubtitle": "Potwierdzenia płatności i status subskrypcji"',
      ),
    );
    expect(
      plSource,
      contains(
        '"profileNotificationsEmailAccountAlertsSubtitle": "Alerty bezpieczeństwa i zmiany konta"',
      ),
    );
    expect(
      plSource,
      contains('"passwordChangeStepRequestCode": "Poproś o kod"'),
    );
    expect(plSource, contains('"passwordChangeStepNewPassword": "Nowe hasło"'));
    expect(
      plSource,
      contains(
        '"subscriptionGrantNextLabel": "Następne przyznanie: {countdown}"',
      ),
    );
    expect(
      plSource,
      contains(
        '"subscriptionBenefitPriorityGenerationDescription": "Twoje zadania mają priorytet"',
      ),
    );
  });

  test(
    'all supported localizations preserve English placeholder contracts',
    () {
      final base = _readArb('lib/l10n/app_en.arb');
      final baseKeys = _messageKeys(base);
      const localeFiles = [
        'lib/l10n/app_ru.arb',
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pl.arb',
      ];

      for (final path in localeFiles) {
        final locale = _readArb(path);

        expect(
          _messageKeys(locale),
          baseKeys,
          reason: '$path must keep the same localization keys as app_en.arb',
        );

        for (final key in baseKeys) {
          expect(
            _placeholders(locale[key]),
            _placeholders(base[key]),
            reason: '$path must preserve placeholders for $key',
          );
        }
      }
    },
  );
}

Map<String, Object?> _readArb(String path) {
  return (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>)
      .cast<String, Object?>();
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}

Set<String> _placeholders(Object? value) {
  if (value is! String) {
    return const {};
  }

  return RegExp(
    r'\{[A-Za-z][A-Za-z0-9_]*\}',
  ).allMatches(value).map((match) => match.group(0)!).toSet();
}
