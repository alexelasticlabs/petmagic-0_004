import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';

void main() {
  group('classifyAppUnavailable', () {
    test('preserves a specific email validation error', () {
      expect(
        classifyAppUnavailable(
          raw: 'ValidationProblem: auth.email_invalid',
          hasInternet: true,
        ),
        isNull,
      );
    });

    test('preserves a Google sign-in configuration error', () {
      expect(
        classifyAppUnavailable(
          raw: 'AppException: auth.external_invalid',
          hasInternet: true,
        ),
        isNull,
      );
    });

    test('still reports a genuine backend outage', () {
      expect(
        classifyAppUnavailable(
          raw: 'templates.server_unavailable',
          hasInternet: true,
        ),
        AppUnavailableKind.serverUnavailable,
      );
    });
  });
}
