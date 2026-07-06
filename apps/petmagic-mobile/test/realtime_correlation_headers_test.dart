import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/request_identity.dart';

void main() {
  test('request identity creates mobile request and flow identifiers', () {
    expect(RequestIdentity.createRequestId(), startsWith('m-'));
    expect(RequestIdentity.createCorrelationId(), startsWith('flow-'));
  });

  test('realtime clients send request and correlation headers', () async {
    final sseSource = await File(
      'lib/core/realtime/realtime_client.dart',
    ).readAsString();
    final supportSource = await File(
      'lib/features/support/data/support_chat_realtime_client.dart',
    ).readAsString();

    expect(sseSource, contains("request.headers.set('X-Request-ID'"));
    expect(sseSource, contains("request.headers.set('X-Correlation-ID'"));
    expect(sseSource, contains('RequestIdentity.createRequestId()'));
    expect(sseSource, contains('RequestIdentity.createCorrelationId()'));

    expect(supportSource, contains("headers.setHeaderValue('X-Request-ID'"));
    expect(supportSource, contains("'X-Correlation-ID'"));
    expect(supportSource, contains('RequestIdentity.createRequestId()'));
    expect(supportSource, contains('RequestIdentity.createCorrelationId()'));
  });

  test(
    'request identity reports secure-random fallback instead of swallowing it',
    () async {
      final requestIdentitySource = await File(
        'lib/core/network/request_identity.dart',
      ).readAsString();

      expect(requestIdentitySource, contains('developer.log('));
      expect(
        requestIdentitySource,
        contains('Secure random unavailable; falling back to Random.'),
      );
      expect(
        requestIdentitySource,
        contains('error: kDebugMode ? error : error.runtimeType.toString()'),
      );
      expect(
        requestIdentitySource,
        contains('stackTrace: kDebugMode ? stackTrace : null'),
      );
      expect(requestIdentitySource, isNot(contains('} catch (_) {')));
    },
  );

  test('haptics report unsupported devices only once', () async {
    final hapticsSource = await File(
      'lib/shared/widgets/petmagic_haptics.dart',
    ).readAsString();

    expect(hapticsSource, contains('AppLogger.warn('));
    expect(hapticsSource, contains("feature: 'Shared.Haptics'"));
    expect(hapticsSource, contains('static bool _loggedUnavailable = false;'));
    expect(hapticsSource, isNot(contains('} catch (_) {')));
  });
}
