import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_models.dart';
import 'package:petmagic_mobile/features/templates/data/generation_repository_error_mapper.dart';
import 'package:petmagic_mobile/features/templates/data/pet_dto_mapper.dart';

/// Owns pet profile REST transport used by the generation flow.
final class PetProfileRemoteDataSource {
  const PetProfileRemoteDataSource({
    required Dio dio,
    required AuthSessionCoordinator authSessionCoordinator,
    required GenerationRepositoryErrorMapper errorMapper,
  }) : _dio = dio,
       _authSessionCoordinator = authSessionCoordinator,
       _errorMapper = errorMapper;

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;
  final GenerationRepositoryErrorMapper _errorMapper;

  Future<List<PetProfile>> fetchPets({RequestCancellation? cancelToken}) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/pets',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );
    return (response.data ?? const [])
        .whereType<Map>()
        .map((item) => mapPetProfileDto(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/pets',
        data: {'name': name, 'type': type, 'breed': ?breed},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
    return mapPetProfileDto(response.data ?? const {});
  }

  Future<PetProfile> updatePet({
    required String petId,
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.put<Map<String, dynamic>>(
        '/api/pets/${Uri.encodeComponent(petId)}',
        data: {'name': name, 'type': type, 'breed': ?breed},
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
    return mapPetProfileDto(response.data ?? const {});
  }

  Future<void> deletePet(String petId, {RequestCancellation? cancelToken}) {
    return _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/pets/${Uri.encodeComponent(petId)}',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request, {
    bool retryTransientFailures = true,
  }) {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _errorMapper.map,
      requestFailedMessage: 'templates.generation_failed',
      sessionExpiredMessage: 'auth.session_expired',
      transientRetryAttempts: retryTransientFailures ? 2 : 1,
    );
  }
}
