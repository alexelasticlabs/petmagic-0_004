import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth entry page normalizes consent, email, and success keys', () {
    final source = File(
      'lib/features/profile/presentation/auth_entry_page.dart',
    ).readAsStringSync();
    final content = File(
      'lib/features/profile/presentation/auth_entry_content.part.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('normalizeProfileFeedbackKey(nextState.errorMessage)'),
    );
    expect(
      source,
      contains('normalizeProfileSuccessKey(nextState.successMessage)'),
    );
    expect(
      source,
      contains('normalizeProfileFeedbackKey(_consentErrorMessage)'),
    );
    expect(
      source,
      isNot(contains("nextState.errorMessage == 'auth.email_not_confirmed'")),
    );
    expect(
      source,
      isNot(
        contains(
          "nextState.successMessage == 'auth.registration_pending_verification'",
        ),
      ),
    );
    expect(
      content,
      contains("page._hasConsentErrorCode('auth.accept_terms_required')"),
    );
    expect(
      content,
      isNot(
        contains("page._consentErrorMessage == 'auth.accept_terms_required'"),
      ),
    );
  });
}
