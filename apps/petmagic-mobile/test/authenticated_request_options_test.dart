import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';

void main() {
  test('authenticated request options keep JSON calls on default timeouts', () {
    final options = authenticatedRequestOptions(
      'access-token',
      correlationId: 'flow-1',
    );

    expect(
      options.headers?[HttpHeaders.authorizationHeader],
      'Bearer access-token',
    );
    expect(options.headers?['X-Correlation-ID'], 'flow-1');
    expect(options.contentType, isNull);
    expect(options.sendTimeout, isNull);
    expect(options.receiveTimeout, isNull);
  });

  test(
    'authenticated multipart request options use bounded upload timeouts',
    () {
      final options = authenticatedMultipartRequestOptions(
        'access-token',
        correlationId: 'generation-flow-1',
      );

      expect(
        options.headers?[HttpHeaders.authorizationHeader],
        'Bearer access-token',
      );
      expect(options.headers?['X-Correlation-ID'], 'generation-flow-1');
      expect(options.contentType, 'multipart/form-data');
      expect(options.sendTimeout, defaultMultipartSendTimeout);
      expect(options.receiveTimeout, defaultMultipartReceiveTimeout);
      expect(options.sendTimeout, greaterThan(const Duration(seconds: 20)));
      expect(options.receiveTimeout, greaterThan(const Duration(seconds: 25)));
    },
  );

  test('custom request timeouts are explicit when supplied', () {
    final options = authenticatedRequestOptions(
      'access-token',
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 35),
    );

    expect(options.sendTimeout, const Duration(seconds: 30));
    expect(options.receiveTimeout, const Duration(seconds: 35));
  });
}
