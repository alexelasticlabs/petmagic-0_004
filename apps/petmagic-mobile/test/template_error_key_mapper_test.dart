import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/template_error_key_mapper.dart';

void main() {
  group('normalizeTemplateErrorKey', () {
    test('maps wrapped economy balance errors to template balance key', () {
      expect(
        normalizeTemplateErrorKey(
          '  AppException: ECONOMY.INSUFFICIENT_BALANCE  ',
        ),
        'templates.insufficient_balance',
      );
    });

    test('extracts safe template transport keys from wrapped messages', () {
      expect(
        normalizeTemplateErrorKey('RuntimeError: templates.connection_timeout'),
        'templates.connection_timeout',
      );
      expect(
        normalizeTemplateErrorKey('Oops: templates.server_unavailable'),
        'templates.server_unavailable',
      );
    });

    test('rejects arbitrary user or backend text', () {
      expect(
        normalizeTemplateErrorKey('FileSystemException: /private/photo.jpg'),
        isNull,
      );
      expect(
        normalizeTemplateErrorKey('Support conversation was not found.'),
        isNull,
      );
    });
  });
}
