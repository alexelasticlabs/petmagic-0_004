import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';

void main() {
  test(
    'register marks request anonymous and strips stale authorization',
    () async {
      String? observedAuthorization;
      Object? observedAnonymousFlag;
      final dio =
          Dio(
              BaseOptions(
                baseUrl: 'https://api.petmagic.test',
                headers: const {
                  HttpHeaders.authorizationHeader: 'Bearer stale-token',
                },
              ),
            )
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  removeAuthorizationHeaderForAnonymousRequest(options);
                  observedAuthorization = options
                      .headers[HttpHeaders.authorizationHeader]
                      ?.toString();
                  observedAnonymousFlag =
                      options.extra[anonymousRequestExtraKey];
                  handler.resolve(
                    Response<Map<String, dynamic>>(
                      requestOptions: options,
                      statusCode: 201,
                      data: const {},
                    ),
                  );
                },
              ),
            );
      final repository = ProfileRepository(
        dio: dio,
        sessionStorage: AuthSessionStorage(),
      );

      await repository.register(
        email: 'new@example.com',
        password: 'Password123',
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        termsOfUseVersion: '',
        privacyPolicyVersion: '',
        marketingEmailsEnabled: false,
      );

      expect(observedAnonymousFlag, isTrue);
      expect(observedAuthorization, isNull);
    },
  );
}
