import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return GamificationRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
  );
});

class GamificationRepository {
  GamificationRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
    AuthSessionCoordinator? authSessionCoordinator,
  })  : _dio = dio,
        _authSessionCoordinator = authSessionCoordinator ??
            AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;

  Future<GamificationSummaryModel> fetchSummary({
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/gamification/summary',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );
    return GamificationSummaryModel.fromJson(response.data ?? const {});
  }

  Future<PetProgressModel> fetchPetProgress(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/gamification/pets/$petId/progress',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );
    return PetProgressModel.fromJson(response.data ?? const {});
  }

  Future<List<AchievementModel>> fetchAchievements({
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/gamification/achievements',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );
    return (response.data ?? [])
        .map((e) => AchievementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AchievementModel>> fetchRecentAchievements({
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/gamification/achievements/recent',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );
    return (response.data ?? [])
        .map((e) => AchievementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StreakModel?> fetchStreak({CancelToken? cancelToken}) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) => _dio.get<Map<String, dynamic>>(
          '/api/gamification/streaks',
          options: authenticatedRequestOptions(session.accessToken),
          cancelToken: cancelToken,
        ),
      );
      return StreakModel.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<UseFreezeResultModel> useStreakFreeze({
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/gamification/streaks/freeze',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );
    return UseFreezeResultModel.fromJson(response.data ?? const {});
  }

  Future<List<WeeklyChallengeModel>> fetchCurrentChallenges({
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/gamification/challenges/current',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
    );
    return (response.data ?? [])
        .map((e) => WeeklyChallengeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(dynamic session) request,
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

class UseFreezeResultModel {
  const UseFreezeResultModel({
    required this.success,
    required this.freezesRemaining,
  });

  final bool success;
  final int freezesRemaining;

  factory UseFreezeResultModel.fromJson(Map<String, dynamic> json) {
    return UseFreezeResultModel(
      success: json['success'] as bool? ?? false,
      freezesRemaining: (json['freezesRemaining'] as num?)?.toInt() ?? 0,
    );
  }
}
