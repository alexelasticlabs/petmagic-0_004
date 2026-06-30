import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
