import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('localized payment and verification labels avoid broken machine copy', () {
    final es = File('lib/l10n/app_es.arb').readAsStringSync();
    final fr = File('lib/l10n/app_fr.arb').readAsStringSync();
    final de = File('lib/l10n/app_de.arb').readAsStringSync();
    final pl = File('lib/l10n/app_pl.arb').readAsStringSync();
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    final ru = File('lib/l10n/app_ru.arb').readAsStringSync();

    expect(es, isNot(contains('"premiumPaymentGooglePlay": "GooglePlay"')));
    expect(
      es,
      isNot(contains('"subscriptionPaymentProviderGooglePlay": "GooglePlay"')),
    );
    expect(es, isNot(contains('"walletStripeWalletsLabel": "Pago de Apple')));
    expect(
      es,
      isNot(contains('"emailVerificationWorkingLabel": "Laboral..."')),
    );

    expect(
      fr,
      isNot(contains('"emailVerificationWorkingLabel": "Fonctionnement..."')),
    );
    expect(
      de,
      isNot(contains('"emailVerificationWorkingLabel": "Arbeiten..."')),
    );
    expect(
      pl,
      isNot(contains('"emailVerificationWorkingLabel": "Pracujący..."')),
    );
    expect(
      en,
      isNot(
        contains(
          '"premiumStoreVerificationUnavailable": "Server-side store verification is not configured yet."',
        ),
      ),
    );
    expect(
      ru,
      isNot(
        contains(
          '"premiumStoreVerificationUnavailable": "Серверная проверка подписки магазина еще не настроена."',
        ),
      ),
    );
    expect(
      es,
      isNot(
        contains(
          '"premiumStoreVerificationUnavailable": "La verificación del store en el servidor aún no está configurada."',
        ),
      ),
    );
    expect(
      fr,
      isNot(
        contains(
          '"premiumStoreVerificationUnavailable": "La vérification store côté serveur n\'est pas encore configurée."',
        ),
      ),
    );
    expect(
      de,
      isNot(
        contains(
          '"premiumStoreVerificationUnavailable": "Die serverseitige Store-Verifizierung ist noch nicht konfiguriert."',
        ),
      ),
    );
    expect(
      pl,
      isNot(
        contains(
          '"premiumStoreVerificationUnavailable": "Weryfikacja sklepu po stronie serwera nie jest jeszcze skonfigurowana."',
        ),
      ),
    );
  });
}
