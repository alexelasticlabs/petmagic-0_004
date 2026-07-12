import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'premium_controller_test_source.dart';
import 'wallet_controller_test_source.dart';

void main() {
  test('payment and generation controllers do not expose raw exceptions', () {
    final sources = [
      readPremiumControllerLibrarySource(),
      File(
        'lib/features/premium/presentation/premium_page.dart',
      ).readAsStringSync(),
      readWalletControllerLibrarySource(),
      [
        'lib/features/templates/application/generation_history_controller.dart',
        'lib/features/templates/application/generation_history_controller_cache.part.dart',
        'lib/features/templates/application/generation_history_controller_lifecycle.part.dart',
        'lib/features/templates/application/generation_history_controller_sync.part.dart',
      ].map((p) => File(p).readAsStringSync()).join('\n'),
      File(
        'lib/features/templates/presentation/template_generation_controller.dart',
      ).readAsStringSync(),
      File(
        'lib/features/gamification/presentation/achievements_page.dart',
      ).readAsStringSync(),
      File(
        'lib/features/profile/presentation/profile_page_gamification.part.dart',
      ).readAsStringSync(),
      File(
        'lib/features/pets/presentation/my_pets_page.dart',
      ).readAsStringSync(),
      File(
        'lib/features/templates/presentation/generations_gallery_page_states_and_actions.dart',
      ).readAsStringSync(),
    ];

    for (final source in sources) {
      expect(source, isNot(contains('error.toString()')));
      expect(source, isNot(contains('exception.toString()')));
    }

    expect(sources[0], contains('_premiumErrorMessage(error,'));
    expect(sources[0], contains('normalizePremiumErrorKey(error.message)'));
    expect(sources[1], isNot(contains('result.errorMessage?.trim()')));
    expect(sources[1], isNot(contains('message: failureMessage')));
    expect(sources[1], contains('mapCommonAuthFeedbackMessage(text, value)'));
    expect(sources[2], contains('_errorMessage(error)'));
    expect(sources[2], contains('normalizeWalletErrorKey(error.message)'));
    expect(sources[3], contains('_historyLoadErrorMessage(error)'));
    expect(sources[3], contains('normalizeTemplateErrorKey(error.message)'));
    expect(sources[4], contains('normalizeTemplateErrorKey(error.message)'));
    expect(sources[5], contains('achievementsErrorMessage('));
    expect(sources[6], contains('achievementsErrorMessage('));
    expect(sources[7], contains('_petsErrorMessage('));
    expect(sources[8], contains('normalizeTemplateErrorKey(raw)'));
    expect(sources[8], isNot(contains('=> raw')));
  });
}
