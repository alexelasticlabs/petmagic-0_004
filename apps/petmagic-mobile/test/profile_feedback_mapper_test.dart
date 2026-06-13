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
}
