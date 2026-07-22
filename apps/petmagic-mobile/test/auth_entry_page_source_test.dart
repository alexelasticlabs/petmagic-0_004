import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';

void main() {
  test('auth redirect paths are constrained to safe internal routes', () {
    expect(normalizeAuthRedirectPath('/profile/wallet'), '/profile/wallet');
    expect(
      normalizeAuthRedirectPath('/templates?category=Magic Pets'),
      '/templates?category=Magic Pets',
    );
    expect(normalizeAuthRedirectPath('https://evil.test'), isNull);
    expect(normalizeAuthRedirectPath('//evil.test/path'), isNull);
    expect(normalizeAuthRedirectPath('/profile\\wallet'), isNull);
    expect(normalizeAuthRedirectPath('/profile\u0000wallet'), isNull);
    expect(
      normalizeAuthRedirectPath('/${List.filled(1100, 'x').join()}'),
      isNull,
    );
  });

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
    expect(source, contains('normalizeAuthRedirectPath(widget.redirectPath)'));
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

  test('auth entry page loads legal documents only for sign up flow', () {
    final source = File(
      'lib/features/profile/presentation/auth_entry_page.dart',
    ).readAsStringSync();
    final content = File(
      'lib/features/profile/presentation/auth_entry_content.part.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'final legalDocumentsAsync = _isSignUp && hasInternet\n'
        '        ? ref.watch(currentLegalDocumentsProvider(locale))\n'
        '        : null;',
      ),
    );
    expect(
      source,
      contains(
        "if (legalDocuments == null) {\n"
        "        setState(() {\n"
        "          _consentErrorMessage = 'auth.legal_documents_unavailable';\n"
        "        });\n"
        "        return;\n"
        "      }",
      ),
    );
    expect(
      content,
      contains('final AsyncValue<MobileLegalDocuments>? legalDocumentsAsync;'),
    );
    expect(content, contains('legalDocumentsAsync?.isLoading == true'));
  });
}
