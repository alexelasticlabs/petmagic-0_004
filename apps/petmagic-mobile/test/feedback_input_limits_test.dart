import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile feedback message inputs match the API maximum length', () {
    final profileFeedback = File(
      'lib/features/profile/presentation/profile_settings_feedback.part.dart',
    ).readAsStringSync();
    final paywallFeedback = File(
      'lib/features/premium/presentation/premium_page_feedback.part.dart',
    ).readAsStringSync();
    final generationFeedback = File(
      'lib/features/templates/presentation/generation_status_page_feedback.part.dart',
    ).readAsStringSync();

    expect(profileFeedback, contains('maxLength: 2000'));
    expect(paywallFeedback, contains('maxLength: 2000'));
    expect(generationFeedback, contains('maxLength: 2000'));
    expect(
      RegExp(r'maxLength: 2000').allMatches(generationFeedback),
      hasLength(2),
    );
  });
}
