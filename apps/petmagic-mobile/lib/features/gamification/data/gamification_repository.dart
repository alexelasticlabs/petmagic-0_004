export 'package:petmagic_mobile/features/gamification/application/gamification_repository.dart'
    show GamificationRepository, gamificationRepositoryProvider;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/features/gamification/application/gamification_repository.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_dto_mapper.dart';
import 'package:petmagic_mobile/features/gamification/domain/gamification_models.dart';

final dioGamificationRepositoryProvider = Provider<GamificationRepository>((
  ref,
) {
  return DioGamificationRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
  );
});

final class DioGamificationRepository implements GamificationRepository {
  DioGamificationRepository({
    required Dio dio,
    required AuthSessionStore sessionStorage,
    AuthSessionCoordinator? authSessionCoordinator,
  }) : _dio = dio,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;

  @override
  Future<GamificationSummaryModel> fetchSummary({
    RequestCancellation? cancellation,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/gamification/summary',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancellation.toDioCancelToken(),
      ),
    );
    return mapGamificationSummaryDto(response.data ?? const {});
  }

  @override
  Future<List<AchievementModel>> fetchAchievements({
    RequestCancellation? cancellation,
  }) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/gamification/achievements',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancellation.toDioCancelToken(),
      ),
    );
    return (response.data ?? [])
        .map((e) => mapAchievementDto(e as Map<String, dynamic>))
        .toList();
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request,
  ) async {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _mapDioException,
      requestFailedMessage: 'gamification.request_failed',
      sessionExpiredMessage: 'auth.session_expired',
    );
  }

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    if (NetworkErrorMapper.isConnectivityIssue(error)) {
      return NetworkErrorMapper.fromMessage(
        error,
        'gamification.network_unavailable',
      );
    }

    if (NetworkErrorMapper.isServerError(error)) {
      return NetworkErrorMapper.fromMessage(
        error,
        'gamification.server_unavailable',
      );
    }

    final payload = NetworkErrorMapper.parseApiPayload(error);
    final safeMessage = NetworkErrorMapper.safePayloadMessage(payload);
    if (safeMessage != null) {
      return NetworkErrorMapper.fromMessage(error, safeMessage);
    }

    return NetworkErrorMapper.fallback(error, fallbackMessage: fallbackMessage);
  }
}
