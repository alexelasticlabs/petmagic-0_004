import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _legacyArbEntry(String key, List<String> valueParts) =>
    '"$key": "${valueParts.join(' ')}"';

String _legacyPhrase(List<String> words) => words.join(' ');

void main() {
  test(
    'localized payment and verification labels avoid broken machine copy',
    () {
      final es = File('lib/l10n/app_es.arb').readAsStringSync();
      final fr = File('lib/l10n/app_fr.arb').readAsStringSync();
      final de = File('lib/l10n/app_de.arb').readAsStringSync();
      final it = File('lib/l10n/app_it.arb').readAsStringSync();
      final pl = File('lib/l10n/app_pl.arb').readAsStringSync();
      final en = File('lib/l10n/app_en.arb').readAsStringSync();
      final ru = File('lib/l10n/app_ru.arb').readAsStringSync();

      expect(es, isNot(contains('"premiumPaymentGooglePlay": "GooglePlay"')));
      expect(
        es,
        isNot(
          contains('"subscriptionPaymentProviderGooglePlay": "GooglePlay"'),
        ),
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
            _legacyArbEntry('premiumStoreVerificationUnavailable', [
              'Server-side store verification is',
              'not',
              'configured',
              'yet.',
            ]),
          ),
        ),
      );
      expect(
        ru,
        isNot(
          contains(
            _legacyArbEntry('premiumStoreVerificationUnavailable', [
              'Серверная проверка подписки магазина',
              'еще',
              'не',
              'настроена.',
            ]),
          ),
        ),
      );
      expect(
        es,
        isNot(
          contains(
            _legacyArbEntry('premiumStoreVerificationUnavailable', [
              'La verificación del store en el servidor',
              'aún',
              'no',
              'está configurada.',
            ]),
          ),
        ),
      );
      expect(
        fr,
        isNot(
          contains(
            _legacyArbEntry('premiumStoreVerificationUnavailable', [
              'La vérification store côté serveur',
              'n\'est',
              'pas',
              'encore configurée.',
            ]),
          ),
        ),
      );
      expect(
        de,
        isNot(
          contains(
            _legacyArbEntry('premiumStoreVerificationUnavailable', [
              'Die serverseitige Store-Verifizierung ist',
              'noch',
              'nicht',
              'konfiguriert.',
            ]),
          ),
        ),
      );
      expect(
        pl,
        isNot(
          contains(
            _legacyArbEntry('premiumStoreVerificationUnavailable', [
              'Weryfikacja sklepu po stronie serwera',
              'nie',
              'jest',
              'jeszcze',
              'skonfigurowana.',
            ]),
          ),
        ),
      );
      expect(es, isNot(contains('"walletBalanceAfter": "Balón. {count}"')));
      expect(de, isNot(contains('"walletBalanceAfter": "Gut. {count}"')));
      expect(fr, isNot(contains('"walletBalanceAfter": "Bal. {count}"')));
      expect(it, isNot(contains('"walletBalanceAfter": "Bal. {count}"')));
      expect(pl, isNot(contains('"walletBalanceAfter": "Bal. {count}"')));
      expect(ru, isNot(contains('"startupMiniFeaturePetFirst": "Pet-first"')));

      final unfinishedAvailabilityPattern = RegExp(
        [
          _legacyPhrase(['not', 'available', 'yet']),
          _legacyPhrase(['not', 'configured', 'yet']),
          _legacyPhrase(['noch', 'nicht']),
          _legacyPhrase(['aún', 'no']),
          _legacyPhrase(['pas', 'encore']),
          _legacyPhrase(['non', 'è', 'ancora']),
          'jeszcze',
          _legacyPhrase(['пока', 'недоступно']),
          _legacyPhrase(['еще', 'не']),
        ].join('|'),
        caseSensitive: false,
      );
      final productionSafeAvailabilityKeys = [
        'premiumManageFailed',
        'premiumCheckoutFailed',
        'premiumStoreVerificationUnavailable',
        'templateFlowResultUnavailable',
        'generationStatusDeleteSoonMessage',
        'generationStatusResultUnavailableForSave',
        'generationStatusResultUnavailableForShare',
      ];
      final arbFiles = [
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ru.arb',
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pl.arb',
      ];
      for (final path in arbFiles) {
        final arb =
            jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
        for (final key in productionSafeAvailabilityKeys) {
          expect(
            arb[key],
            isNot(matches(unfinishedAvailabilityPattern)),
            reason: '$path $key should be production-safe availability copy.',
          );
        }
      }
    },
  );

  test('polish core templates copy keeps production diacritics', () {
    final pl =
        jsonDecode(File('lib/l10n/app_pl.arb').readAsStringSync())
            as Map<String, Object?>;

    expect(pl['createMagicTitle'], 'Stwórz magię');
    expect(pl['searchTemplates'], 'Szukaj szablonów');
    expect(pl['profileSignInAction'], 'Zaloguj się');
    expect(pl['templatesErrorTitle'], 'Nie załadowano szablonów');
    expect(pl['emptyTemplatesTitle'], 'Nie ma jeszcze szablonów');
    expect(
      pl['emptyTemplatesMessage'],
      'Spróbuj innego filtra albo odśwież katalog.',
    );
    expect(pl['appUnavailableServerTitle'], 'Serwer niedostępny');
    expect(
      pl['appUnavailableServerMessage'],
      'PetMagic jest chwilowo niedostępny. Spróbuj ponownie za moment.',
    );

    final brokenFragments = [
      'Stworz magie',
      'Szukaj szablonow',
      'Sprobuj',
      'odswiez',
      'Zalogować się',
      'Nie zaladowano szablonow',
      'nie moze teraz polaczyc sie',
    ];
    final plSource = File('lib/l10n/app_pl.arb').readAsStringSync();
    for (final fragment in brokenFragments) {
      expect(plSource, isNot(contains(fragment)));
    }
  });

  test('french core app copy keeps production accents', () {
    final fr =
        jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
            as Map<String, Object?>;

    expect(fr['navTemplates'], 'Modèles');
    expect(fr['createMagicTitle'], 'Créer de la magie');
    expect(fr['searchTemplates'], 'Rechercher des modèles');
    expect(fr['magicLoadingPreparing'], 'Préparation de la magie...');
    expect(fr['magicLoadingAlmostReady'], 'Presque prêt...');
    expect(fr['generationStatusVideoReady'], 'La vidéo est prête');
    expect(fr['generationStatusSectionReady'], 'Prêt');
    expect(
      fr['generationStatusEmptyMessage'],
      'Choisissez un modèle, téléversez une photo de votre animal et '
      'créez votre première création magique.',
    );
    expect(
      fr['profileNotificationsPushPhotoReadySubtitle'],
      'Quand une photo IA est prête à être consultée',
    );
    expect(fr['subscriptionGrantReadyLabel'], 'Prêt à être crédité !');

    final brokenFragments = [
      'Modeles',
      'Creer la magie',
      'Rechercher des modeles',
      'Preparation de la magie',
      'Presque pret',
      'La video est prete',
      'a ameliorer',
      'televersez',
      'premiere creation',
      'prete a etre consultee',
      'Pret a etre credite',
      'Reessayez',
    ];
    final frSource = File('lib/l10n/app_fr.arb').readAsStringSync();
    for (final fragment in brokenFragments) {
      expect(frSource, isNot(contains(fragment)));
    }
  });

  test('german core app copy keeps production umlauts', () {
    final de =
        jsonDecode(File('lib/l10n/app_de.arb').readAsStringSync())
            as Map<String, Object?>;

    expect(de['pickTemplateSubtitle'], 'Wähle eine Vorlage für dein Haustier');
    expect(de['addTokensTooltip'], 'PawSpark hinzufügen');
    expect(de['profileAccountDeleted'], 'Ihr Konto wurde gelöscht.');
    expect(de['generationStatusDeleteAction'], 'Löschen');
    expect(
      de['generationStatusResultUnavailableForSave'],
      'Das Ergebnis ist derzeit nicht zum Speichern verfügbar.',
    );
    expect(
      de['generationStatusBackgroundHint'],
      'Die Generierung läuft auf dem Server weiter. Wir zeigen das Ergebnis '
      'in der Galerie, sobald es fertig ist.',
    );
    expect(de['appUnavailableServerTitle'], 'Server nicht verfügbar');
    expect(
      de['profileNotificationsPushNewTemplatesSubtitle'],
      'Neue Stile und Vorlagen für Generierungen',
    );
    expect(de['subscriptionGrantNextLabel'], 'Nächste Gutschrift: {countdown}');

    final brokenFragments = [
      'Waehle',
      'fuer dein Haustier',
      'hinzufuegen',
      'geloescht',
      'verfugbar',
      'Loschen',
      'zuruckerstattet',
      'lauft',
      'Moechtest',
      'Prufe',
      'Fuhre',
      'fuer Generierungen',
      'Naechste Gutschrift',
      'Prioritaet',
      'koennen kuerzer',
    ];
    final deSource = File('lib/l10n/app_de.arb').readAsStringSync();
    for (final fragment in brokenFragments) {
      expect(deSource, isNot(contains(fragment)));
    }
  });

  test('spanish core app copy keeps production accents', () {
    final es =
        jsonDecode(File('lib/l10n/app_es.arb').readAsStringSync())
            as Map<String, Object?>;

    expect(
      es['templateFlowResultUnavailable'],
      'El resultado no está disponible temporalmente',
    );
    expect(es['generationStatusTitle'], 'Estado de generación');
    expect(es['generationStatusFeedbackTitle'], '¿Qué tal el resultado?');
    expect(es['generationStatusVideoReady'], 'El vídeo está listo');
    expect(
      es['generationStatusBackgroundHint'],
      'La generación continúa en el servidor. Mostraremos el resultado '
      'en la Galería cuando esté listo.',
    );
    expect(es['generationStatusEmptyTitle'], 'Tus resultados aparecerán aquí');
    expect(es['templateFlowCompletedPremiumHeadline'], '¿Quieres crear más?');
    expect(es['appUnavailableOfflineTitle'], 'Sin conexión');
    expect(
      es['profileNotificationsPushPhotoReadySubtitle'],
      'Cuando una foto de IA está lista para ver',
    );
    expect(es['generationStatusQueuePosition'], 'Posición en cola #{position}');

    final brokenFragments = [
      'El resultado no esta disponible',
      'Estado de generacion',
      'Que tal el resultado',
      'El video esta listo',
      'generacion continua',
      'Galeria cuando este listo',
      'apareceran aqui',
      'obra magica',
      'Quieres crear mas',
      'exportacion sin marca',
      'Sin conexion',
      'compilacion de depuracion',
      'Que te impidio',
      'Cuentanos que haria',
      'Posicion en cola',
      'video suele tardar mas',
      'servicio esta ocupado',
    ];
    final esSource = File('lib/l10n/app_es.arb').readAsStringSync();
    for (final fragment in brokenFragments) {
      expect(esSource, isNot(contains(fragment)));
    }
  });

  test('italian core app copy keeps production accents', () {
    final it =
        jsonDecode(File('lib/l10n/app_it.arb').readAsStringSync())
            as Map<String, Object?>;

    expect(it['profileAccountDeleted'], 'Il tuo account è stato eliminato.');
    expect(it['magicLoadingCutestAngle'], "Cerchiamo l'angolo più tenero...");
    expect(
      it['templateFlowResultUnavailable'],
      'Il risultato è temporaneamente non disponibile',
    );
    expect(it['generationStatusFeedbackTitle'], "Com'è il risultato?");
    expect(it['generationStatusVideoReady'], 'Il video è pronto');
    expect(
      it['generationStatusBackgroundHint'],
      'La generazione continua sul server. Mostreremo il risultato nella '
      'Galleria quando sarà pronto.',
    );
    expect(it['templateFlowCompletedPremiumHeadline'], 'Vuoi creare di più?');
    expect(
      it['profileNotificationsPushPhotoReadySubtitle'],
      'Quando una foto AI è pronta da vedere',
    );
    expect(it['subscriptionGrantReadyLabel'], "Pronto per l'accredito!");
    expect(
      it['subscriptionBenefitPriorityGenerationDescription'],
      'Le tue richieste hanno priorità',
    );

    final brokenFragments = [
      'Il tuo account e stato',
      'piu tenero',
      'Il risultato e temporaneamente',
      "Com'e il risultato",
      'Il video e pronto',
      'quando sara pronto',
      'qualita e',
      'generazione e ancora',
      'e gia iniziata',
      'non puo essere',
      'Vuoi creare di piu',
      'Premium ti da',
      'dall abbonarti',
      'l elaborazione',
      'l app',
      'l accredito',
      'hanno priorita',
      'richieste Premium hanno priorita',
      'puo impiegare',
      'servizio e molto',
    ];
    final itSource = File('lib/l10n/app_it.arb').readAsStringSync();
    for (final fragment in brokenFragments) {
      expect(itSource, isNot(contains(fragment)));
    }
  });

  test('support chat copy preserves product brand and natural phrasing', () {
    final de =
        jsonDecode(File('lib/l10n/app_de.arb').readAsStringSync())
            as Map<String, Object?>;
    final es =
        jsonDecode(File('lib/l10n/app_es.arb').readAsStringSync())
            as Map<String, Object?>;
    final fr =
        jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
            as Map<String, Object?>;
    final it =
        jsonDecode(File('lib/l10n/app_it.arb').readAsStringSync())
            as Map<String, Object?>;
    final pl =
        jsonDecode(File('lib/l10n/app_pl.arb').readAsStringSync())
            as Map<String, Object?>;

    expect(de['supportChatTeamTitle'], 'PetMagic-Support');
    expect(es['supportChatTeamTitle'], 'Soporte de PetMagic');
    expect(es['supportHomeTopicPremiumIssue'], 'Problema con Premium');
    expect(
      fr['supportChatResolvedStatusHint'],
      'Cette demande a été marquée comme résolue. Vous pouvez la rouvrir pendant 7 jours.',
    );
    expect(
      it['supportChatSecureTitle'],
      "La tua conversazione è protetta. La usiamo solo per l'assistenza.",
    );
    expect(it['supportChatRecentMediaTitle'], 'Media recenti');
    expect(it['supportChatVideoLabel'], 'Video di supporto');
    expect(it['supportHomeTopicPremiumIssue'], 'Problema con Premium');
    expect(
      pl['supportChatSecureTitle'],
      'Twoja rozmowa jest chroniona. Używamy jej wyłącznie do obsługi zgłoszenia.',
    );
    expect(pl['supportChatRecentMediaTitle'], 'Ostatnie media');
    expect(pl['supportChatVideoLabel'], 'Film w czacie wsparcia');
    expect(pl['supportHomeTopicPremiumIssue'], 'Problem z Premium');

    final arbSources = [
      File('lib/l10n/app_de.arb').readAsStringSync(),
      File('lib/l10n/app_es.arb').readAsStringSync(),
      File('lib/l10n/app_fr.arb').readAsStringSync(),
      File('lib/l10n/app_it.arb').readAsStringSync(),
      File('lib/l10n/app_pl.arb').readAsStringSync(),
    ];
    final brokenFragments = [
      'PetMagic-Unterstützung',
      'Soporte para mascotas mágicas',
      'emisión premium',
      'Puedes reabrirlo',
      'Vous pouvez le rouvrir',
      'Lo usiamo solo come supporto',
      'Supporta il video',
      'Mezzi recenti',
      'Emissione premium',
      'Używamy go wyłącznie jako wsparcia',
      'Możesz go ponownie otworzyć',
      'Wsparcie wideo',
      'Wydanie premium',
    ];
    for (final source in arbSources) {
      for (final fragment in brokenFragments) {
        expect(source, isNot(contains(fragment)));
      }
    }
  });
}
