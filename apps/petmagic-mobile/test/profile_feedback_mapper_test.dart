import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';

void main() {
  testWidgets(
    'unknown profile errors map to generic copy without raw details',
    (tester) async {
      late AppLocalizations text;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              text = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      const raw =
          'Failed for /private/var/mobile/avatar.jpg '
          'Authorization: Bearer raw-token '
          'https://cdn.petmagic.ai/file.jpg?signature=secret';

      final mapped = mapProfileFeedbackMessage(raw, text);

      expect(mapped, text.authRequestFailed);
      expect(mapped, isNot(contains('/private/var/mobile')));
      expect(mapped, isNot(contains('raw-token')));
      expect(mapped, isNot(contains('signature=secret')));
    },
  );

  testWidgets('profile network errors map to localized retryable copy', (
    tester,
  ) async {
    late AppLocalizations text;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) {
            text = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final mapped = mapProfileFeedbackMessage('network.unavailable', text);

    expect(mapped, text.templateFlowNetworkError);
  });

  testWidgets('avatar validation codes map to localized avatar copy', (
    tester,
  ) async {
    late AppLocalizations text;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) {
            text = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      mapProfileFeedbackMessage(
        'ValidationProblem: users.avatar_content_type_not_allowed',
        text,
      ),
      text.profileAvatarCropError,
    );
    expect(
      mapProfileFeedbackMessage('users.avatar_file_required', text),
      text.profileAvatarCropError,
    );
  });

  testWidgets(
    'email confirmation errors map to localized copy instead of generic fallback',
    (tester) async {
      late AppLocalizations text;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              text = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final mapped = mapProfileFeedbackMessage(
        ' AUTH.EMAIL_NOT_CONFIRMED ',
        text,
      );

      expect(mapped, text.profileEmailPending);
      expect(mapped, isNot(text.authRequestFailed));
    },
  );

  testWidgets(
    'credential errors map to login copy instead of generic fallback',
    (tester) async {
      late AppLocalizations text;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) {
              text = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      for (final code in const [
        'auth.invalid_credentials',
        'auth.account_locked',
      ]) {
        expect(mapProfileFeedbackMessage(code, text), text.authLoginFailed);
      }
    },
  );

  test('normalizes wrapped profile auth feedback keys', () {
    expect(
      normalizeProfileFeedbackKey(' AppException: AUTH.ACCEPT_TERMS_REQUIRED '),
      'auth.accept_terms_required',
    );
    expect(
      normalizeProfileFeedbackKey('RuntimeError: auth.email_not_confirmed'),
      'auth.email_not_confirmed',
    );
    expect(
      normalizeProfileFeedbackKey('Failure: auth.legal_documents_unavailable'),
      'auth.legal_documents_unavailable',
    );
    expect(
      normalizeProfileFeedbackKey('ProblemDetails: auth.invalid_credentials'),
      'auth.invalid_credentials',
    );
    expect(
      normalizeProfileFeedbackKey('FileSystemException: /private/user.jpg'),
      isNull,
    );
  });

  test('normalizes wrapped profile success keys', () {
    expect(
      normalizeProfileSuccessKey(' AppException: AUTH.PASSWORD_RESET_SUCCESS '),
      'auth.password_reset_success',
    );
    expect(
      normalizeProfileSuccessKey(
        'RuntimeError: auth.registration_pending_verification',
      ),
      'auth.registration_pending_verification',
    );
    expect(
      normalizeProfileSuccessKey('Result: profile.account_deleted'),
      'profile.account_deleted',
    );
    expect(
      normalizeProfileSuccessKey('FileSystemException: /private/user.jpg'),
      isNull,
    );
  });

  testWidgets('wrapped profile success keys map to localized success copy', (
    tester,
  ) async {
    late AppLocalizations text;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) {
            text = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      mapProfileSuccessMessage(
        ' AppException: auth.password_reset_success ',
        text,
      ),
      text.authPasswordResetSuccess,
    );
    expect(
      mapProfileSuccessMessage('profile.account_deleted', text),
      text.profileAccountDeleted,
    );
    expect(
      mapProfileSuccessMessage(
        'Failure: auth.registration_pending_verification',
        text,
      ),
      isNull,
    );
    expect(mapProfileSuccessMessage('unknown_success', text), isNull);
  });
}
