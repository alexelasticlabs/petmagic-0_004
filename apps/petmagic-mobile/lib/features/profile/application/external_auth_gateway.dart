import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';

enum ExternalAuthProvider {
  google('Google'),
  apple('Apple');

  const ExternalAuthProvider(this.apiValue);
  final String apiValue;
}

final externalAuthRepositoryProvider = Provider<ExternalAuthRepository>((ref) {
  throw StateError(
    'ExternalAuthRepository is not bound. Add the app composition overrides.',
  );
});

abstract interface class ExternalAuthRepository {
  Future<AuthSession> authenticate(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  });
  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  });
  Future<void> clearSession(ExternalAuthProvider provider);
}
