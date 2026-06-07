import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/logging/log_correlation_context.dart';

void main() {
  test('sanitizes sensitive context values by key', () {
    final sanitized = AppLogger.sanitizeContextForTesting({
      'phone': 15551234567,
      'cardNumber': 4242424242424242,
      'paymentIntentClientSecret': 'pi_secret_123',
      'receipt': 'store-receipt',
      'authTicket': 'external-auth-ticket',
      'sessionId': 'checkout-session',
      'checkoutSessionId': 'cs_test_checkoutSession123',
      'email': 'pet.parent@example.com',
      'provider': 'stripe',
      'status': 200,
    });

    expect(sanitized['phone'], '***');
    expect(sanitized['cardNumber'], '***');
    expect(sanitized['paymentIntentClientSecret'], '***');
    expect(sanitized['receipt'], '***');
    expect(sanitized['authTicket'], '***');
    expect(sanitized['sessionId'], '***');
    expect(sanitized['checkoutSessionId'], '***');
    expect(sanitized['email'], 'p***@example.com');
    expect(sanitized['provider'], 'stripe');
    expect(sanitized['status'], 200);
    expect(sanitized.toString(), isNot(contains('external-auth-ticket')));
    expect(sanitized.toString(), isNot(contains('checkout-session')));
    expect(sanitized.toString(), isNot(contains('cs_test_checkoutSession123')));
  });

  test('masks email context fields without leaking raw addresses', () {
    final sanitized = AppLogger.sanitizeContextForTesting({
      'email': 'pet.parent@gmail.com',
      'contactEmail': 'billing.owner@example.co.uk',
      'recoveryEmail': 'not-an-email',
    });

    expect(sanitized['email'], 'p***@gmail.com');
    expect(sanitized['contactEmail'], 'b***@example.co.uk');
    expect(sanitized['recoveryEmail'], '***');
    expect(sanitized.toString(), isNot(contains('pet.parent@gmail.com')));
    expect(sanitized.toString(), isNot(contains('billing.owner')));
  });

  test('redacts raw user data fields by key', () {
    final sanitized = AppLogger.sanitizeContextForTesting({
      'displayName': 'Pet Parent',
      'username': 'pet-parent-42',
      'senderDisplayName': 'Support Agent Alice',
      'firstName': 'Alice',
      'lastName': 'Peterson',
      'fullAddress': '123 Magic Lane',
      'city': 'Austin',
      'country': 'United States',
      'region': 'Texas',
      'postalCode': '90210',
      'provider': 'stripe',
    });

    expect(sanitized['displayName'], '***');
    expect(sanitized['username'], '***');
    expect(sanitized['senderDisplayName'], '***');
    expect(sanitized['firstName'], '***');
    expect(sanitized['lastName'], '***');
    expect(sanitized['fullAddress'], '***');
    expect(sanitized['city'], '***');
    expect(sanitized['country'], '***');
    expect(sanitized['region'], '***');
    expect(sanitized['postalCode'], '***');
    expect(sanitized['provider'], 'stripe');
    expect(sanitized.toString(), isNot(contains('Pet Parent')));
    expect(sanitized.toString(), isNot(contains('pet-parent-42')));
    expect(sanitized.toString(), isNot(contains('Support Agent Alice')));
    expect(sanitized.toString(), isNot(contains('Magic Lane')));
    expect(sanitized.toString(), isNot(contains('Austin')));
    expect(sanitized.toString(), isNot(contains('United States')));
    expect(sanitized.toString(), isNot(contains('Texas')));
  });

  test('sanitizes sensitive patterns embedded in text', () {
    final sanitized = AppLogger.sanitizeContextForTesting({
      'message':
          'Authorization: Bearer abc.def user pet.parent@example.com '
          'url https://cdn.petmagic.ai/file.jpg?signature=secret '
          'key sk_live_123456789 phone +1 (555) 123-4567',
    });

    final message = sanitized['message'] as String;
    expect(message, contains('Bearer ***'));
    expect(message, contains('p***@example.com'));
    expect(message, contains('https://cdn.petmagic.ai/file.jpg?***'));
    expect(message, isNot(contains('abc.def')));
    expect(message, isNot(contains('sk_live_123456789')));
    expect(message, isNot(contains('555')));
  });

  test('sanitizes top-level log messages before developer log output', () {
    final message = AppLogger.sanitizeMessageForTesting(
      'Unhandled exception Authorization: Bearer raw.jwt.token '
      'email pet.parent@example.com '
      'signed https://cdn.petmagic.ai/file.jpg?signature=secret '
      'paymentIntentClientSecret=pi_secret_123 phone +1 555 123 4567',
    );

    expect(message, contains('Bearer ***'));
    expect(message, contains('p***@example.com'));
    expect(message, contains('https://cdn.petmagic.ai/file.jpg?***'));
    expect(message, contains('paymentIntentClientSecret=***'));
    expect(message, isNot(contains('raw.jwt.token')));
    expect(message, isNot(contains('signature=secret')));
    expect(message, isNot(contains('pi_secret_123')));
    expect(message, isNot(contains('555')));
  });

  test('masks standalone Stripe client secrets embedded in text', () {
    final message = AppLogger.sanitizeMessageForTesting(
      'Stripe failed with pi_3Nabc123_secret_clientSecret '
      'setup seti_1Setup234_secret_setupSecret '
      'ephemeral ek_test_ephemeralSecret123',
    );

    expect(message, contains('Stripe failed with ***'));
    expect(message, contains('setup ***'));
    expect(message, contains('ephemeral ***'));
    expect(message, isNot(contains('pi_3Nabc123_secret_clientSecret')));
    expect(message, isNot(contains('seti_1Setup234_secret_setupSecret')));
    expect(message, isNot(contains('ek_test_ephemeralSecret123')));
  });

  test('masks standalone JWT-like tokens embedded in text', () {
    final message = AppLogger.sanitizeMessageForTesting(
      'Provider rejected token '
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyLTEifQ.aVeryLongSignatureValue',
    );

    expect(message, contains('Provider rejected token ***'));
    expect(message, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    expect(message, isNot(contains('eyJzdWIiOiJ1c2VyLTEifQ')));
    expect(message, isNot(contains('aVeryLongSignatureValue')));
  });

  test('masks non-bearer authorization and cookies embedded in text', () {
    final message = AppLogger.sanitizeMessageForTesting(
      'Authorization: Basic basic-secret '
      'authorization=custom-secret '
      'Cookie: sessionId=raw-session '
      'Set-Cookie: refresh=raw-refresh '
      '{"authorization":"Basic json-secret","cookie":"raw-cookie"}',
    );

    expect(message, contains('Authorization: ***'));
    expect(message, contains('Authorization= ***'));
    expect(message, contains('Cookie: ***'));
    expect(message, contains('Set-Cookie: ***'));
    expect(message, contains('"authorization":"***"'));
    expect(message, contains('"cookie":"***"'));
    expect(message, isNot(contains('basic-secret')));
    expect(message, isNot(contains('custom-secret')));
    expect(message, isNot(contains('raw-session')));
    expect(message, isNot(contains('raw-refresh')));
    expect(message, isNot(contains('json-secret')));
    expect(message, isNot(contains('raw-cookie')));
  });

  test('sanitizes sensitive key value pairs inside nested text', () {
    final sanitized = AppLogger.sanitizeContextForTesting({
      'payload': {
        'accessToken': 'plain-access-token',
        'refresh_token': 'plain-refresh-token',
        'password': 'hunter2',
        'signedUrl': 'https://cdn.petmagic.ai/file.jpg?signature=secret',
        'ticket': 'external-auth-ticket',
        'session_id': 'checkout-session',
        'displayName': 'Pet Parent',
        'fullAddress': '123 Magic Lane',
        'city': 'Austin',
        'country': 'United States',
        'postalCode': '90210',
        'status': 'failed',
      },
      'json':
          '{"paymentIntentClientSecret":"pi_secret_123","apiKey":"fal-key",'
          '"checkoutSessionId":"cs_test_checkoutSession123",'
          '"username":"pet-parent-42"}',
    });

    final payload = sanitized['payload'] as String;
    final json = sanitized['json'] as String;

    expect(payload, contains('accessToken: ***'));
    expect(payload, contains('refresh_token: ***'));
    expect(payload, contains('password: ***'));
    expect(payload, contains('signedUrl: ***'));
    expect(payload, contains('ticket: ***'));
    expect(payload, contains('session_id: ***'));
    expect(payload, contains('displayName: ***'));
    expect(payload, contains('fullAddress: ***'));
    expect(payload, contains('city: ***'));
    expect(payload, contains('country: ***'));
    expect(payload, contains('postalCode: ***'));
    expect(payload, contains('status: failed'));
    expect(payload, isNot(contains('plain-access-token')));
    expect(payload, isNot(contains('plain-refresh-token')));
    expect(payload, isNot(contains('hunter2')));
    expect(payload, isNot(contains('external-auth-ticket')));
    expect(payload, isNot(contains('checkout-session')));
    expect(payload, isNot(contains('Pet Parent')));
    expect(payload, isNot(contains('Magic Lane')));
    expect(payload, isNot(contains('Austin')));
    expect(payload, isNot(contains('United States')));
    expect(payload, isNot(contains('90210')));
    expect(payload, isNot(contains('signature=secret')));
    expect(json, contains('"paymentIntentClientSecret":"***"'));
    expect(json, contains('"apiKey":"***"'));
    expect(json, contains('"checkoutSessionId":"***"'));
    expect(json, contains('"username":"***"'));
    expect(json, isNot(contains('pi_secret_123')));
    expect(json, isNot(contains('fal-key')));
    expect(json, isNot(contains('cs_test_checkoutSession123')));
    expect(json, isNot(contains('pet-parent-42')));
  });

  test('masks standalone checkout session ids embedded in text', () {
    final message = AppLogger.sanitizeMessageForTesting(
      'Payment callback returned checkout session cs_test_checkoutSession123 '
      'and ticket=external-auth-ticket',
    );

    expect(message, contains('checkout session ***'));
    expect(message, contains('ticket=***'));
    expect(message, isNot(contains('cs_test_checkoutSession123')));
    expect(message, isNot(contains('external-auth-ticket')));
  });

  test('strips query strings from endpoint context values', () {
    final sanitized = AppLogger.sanitizeContextForTesting({
      'path': '/api/templates/generations?token=abc&signature=secret',
      'endpoint': 'https://api.petmagic.app/api/wallet?receipt=secret',
      'route': '/checkout?paymentIntentClientSecret=pi_secret_123',
    });

    expect(sanitized['path'], '/api/templates/generations');
    expect(sanitized['endpoint'], 'https://api.petmagic.app/api/wallet');
    expect(sanitized['route'], '/checkout');
    expect(sanitized.toString(), isNot(contains('token=abc')));
    expect(sanitized.toString(), isNot(contains('signature=secret')));
    expect(sanitized.toString(), isNot(contains('receipt=secret')));
    expect(sanitized.toString(), isNot(contains('pi_secret_123')));
  });

  test('redacts local file path context without redacting API endpoints', () {
    final sanitized = AppLogger.sanitizeContextForTesting({
      'filePath': '/var/mobile/Containers/Data/Application/app/source.jpg',
      'sourcePath': '/data/user/0/app/cache/source.png',
      'localPath': 'file:///private/var/mobile/photo.heic',
      'path': '/api/templates/generations?token=abc',
      'endpoint': 'https://api.petmagic.app/api/profile?signature=secret',
    });

    expect(sanitized['filePath'], '***');
    expect(sanitized['sourcePath'], '***');
    expect(sanitized['localPath'], '***');
    expect(sanitized['path'], '/api/templates/generations');
    expect(sanitized['endpoint'], 'https://api.petmagic.app/api/profile');
    expect(sanitized.toString(), isNot(contains('/var/mobile')));
    expect(sanitized.toString(), isNot(contains('/data/user')));
    expect(sanitized.toString(), isNot(contains('file:///private')));
  });

  test('redacts local file paths embedded in log text', () {
    final message = AppLogger.sanitizeMessageForTesting(
      'Upload failed filePath=/tmp/petmagic/source.jpg '
      'sourcePath: /storage/emulated/0/DCIM/pet.png '
      'avatarPath=file:///private/var/mobile/avatar.heic',
    );

    expect(message, contains('filePath=***'));
    expect(message, contains('sourcePath: ***'));
    expect(message, contains('avatarPath=***'));
    expect(message, isNot(contains('/tmp/petmagic')));
    expect(message, isNot(contains('/storage/emulated')));
    expect(message, isNot(contains('file:///private')));
  });

  test('sanitizes DioException without leaking headers body or query', () {
    final error = DioException(
      requestOptions: RequestOptions(
        path: '/api/templates/generations?signature=secret&token=abc',
        method: 'POST',
        headers: const {'Authorization': 'Bearer plain-token'},
        data: const {
          'password': 'hunter2',
          'signedUrl': 'https://cdn.petmagic.ai/file.jpg?signature=secret',
        },
      ),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/unused'),
        statusCode: 500,
        data: null,
      ),
      type: DioExceptionType.badResponse,
    );

    final sanitized = AppLogger.sanitizeErrorForTesting(error);
    final text = sanitized.toString();

    expect(text, contains('DioException'));
    expect(text, contains('POST'));
    expect(text, contains('/api/templates/generations'));
    expect(text, contains('500'));
    expect(text, isNot(contains('signature=secret')));
    expect(text, isNot(contains('plain-token')));
    expect(text, isNot(contains('hunter2')));
    expect(text, isNot(contains('signedUrl')));
  });

  test(
    'builds structured payload with correlation id separate from trace id',
    () {
      final payload = AppLogger.buildPayloadForTesting(
        feature: 'Network',
        operation: 'request_failed',
        requestId: 'request-1',
        correlationId: 'flow-1',
        traceId: 'trace-1',
        context: const {
          'endpoint': '/api/templates/generations?token=secret',
          'authorization': 'Bearer raw-token',
          'status': 502,
        },
      );

      expect(payload['request_id'], 'request-1');
      expect(payload['correlation_id'], 'flow-1');
      expect(payload['trace_id'], 'trace-1');
      expect(payload['endpoint'], '/api/templates/generations');
      expect(payload['authorization'], 'Bearer ***');
      expect(payload['status'], 502);
      expect(payload.toString(), isNot(contains('raw-token')));
      expect(payload.toString(), isNot(contains('token=secret')));
    },
  );

  test('uses ambient flow correlation id in structured payloads', () {
    final payload = LogCorrelationContext.runWithCorrelationId(
      'flow-zone-1',
      () => AppLogger.buildPayloadForTesting(
        feature: 'Generation',
        operation: 'job_completed',
      ),
    );

    expect(payload['correlation_id'], 'flow-zone-1');
  });
}
