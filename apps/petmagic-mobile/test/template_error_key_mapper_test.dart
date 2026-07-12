import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/application/template_error_key_mapper.dart';

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

    test('maps backend generation contract codes to localized keys', () {
      expect(
        normalizeTemplateErrorKey('ProblemDetails: templates.premium_required'),
        'templates.premium_required',
      );
      expect(
        normalizeTemplateErrorKey('ACTIVE_GENERATION_LIMIT_REACHED'),
        'templates.generation_already_started',
      );
      expect(
        normalizeTemplateErrorKey('GENERATION_WAIT_TOO_LONG'),
        'templates.generation_wait_too_long',
      );
      expect(
        normalizeTemplateErrorKey('GENERATION_QUEUE_OVERLOADED'),
        'templates.server_unavailable',
      );
      expect(
        normalizeTemplateErrorKey('PROVIDER_CAPACITY_UNAVAILABLE'),
        'templates.server_unavailable',
      );
      expect(
        normalizeTemplateErrorKey('templates.ai_provider_timed_out'),
        'templates.server_timeout',
      );
      expect(
        normalizeTemplateErrorKey('templates.ai_provider_failed'),
        'templates.server_unavailable',
      );
      expect(
        normalizeTemplateErrorKey('ProblemDetails: feedback.rate_limited'),
        'templates.request_failed',
      );
    });

    test('maps pet photo contract codes without exposing backend prose', () {
      expect(
        normalizeTemplateErrorKey('ProblemDetails: pets.photo_required'),
        'pets.photo_required',
      );
      expect(
        normalizeTemplateErrorKey('ProblemDetails: pets.photo_not_found'),
        'pets.photo_not_found',
      );
      expect(
        normalizeTemplateErrorKey('ProblemDetails: pets.not_found'),
        'templates.template_unavailable',
      );
      expect(
        normalizeTemplateErrorKey('templates.source_media_unavailable'),
        'templates.generation_failed',
      );
      expect(
        normalizeTemplateErrorKey(
          'ValidationProblem: templates.source_image_empty',
        ),
        'templates.generation_failed',
      );
      expect(
        normalizeTemplateErrorKey(
          'ValidationProblem: templates.source_image_type_not_allowed',
        ),
        'pets.photo_type_not_allowed',
      );
      expect(
        normalizeTemplateErrorKey(
          'ValidationProblem: templates.source_image_too_large',
        ),
        'templates.generation_failed',
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
