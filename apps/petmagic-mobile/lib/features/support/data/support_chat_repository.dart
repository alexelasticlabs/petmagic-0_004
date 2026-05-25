import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';

final supportChatRepositoryProvider = Provider<SupportChatRepository>((ref) {
  return SupportChatRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
    authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
  );
});

class SupportChatRepository {
  SupportChatRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
    AuthSessionCoordinator? authSessionCoordinator,
  }) : _dio = dio,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;

  Future<SupportChatConversation> openConversation({
    String? initialMessage,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/open',
        data: {
          'initialMessage': initialMessage?.trim().isEmpty ?? true
              ? null
              : initialMessage?.trim(),
        },
        options: _authorizedOptions(session),
      ),
    );

    return SupportChatConversation.fromJson(response.data ?? const {});
  }

  Future<SupportChatConversation> getConversation() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/support/conversation',
        options: _authorizedOptions(session),
      ),
    );

    return SupportChatConversation.fromJson(response.data ?? const {});
  }

  Future<SupportChatMessage> sendMessage({
    required String conversationId,
    required String body,
    required String localeTag,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$conversationId/messages',
        data: {'body': body.trim(), 'locale': localeTag},
        options: _authorizedOptions(session),
      ),
    );

    return SupportChatMessage.fromJson(response.data ?? const {});
  }

  Future<SupportChatMessage> sendAttachment({
    required String conversationId,
    required String filePath,
    required String fileName,
    required String contentType,
    required String localeTag,
    String? body,
  }) async {
    final trimmedBody = body?.trim() ?? '';
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$conversationId/attachments',
        data: FormData.fromMap({
          if (trimmedBody.isNotEmpty) 'body': trimmedBody,
          'locale': localeTag,
          'file': MultipartFile.fromFileSync(
            filePath,
            filename: fileName,
            contentType: MediaType.parse(contentType),
          ),
        }),
        options: _authorizedOptions(
          session,
        ).copyWith(contentType: 'multipart/form-data'),
      ),
    );

    return SupportChatMessage.fromJson(response.data ?? const {});
  }

  Future<SupportChatMessage> retryAttachment({
    required String conversationId,
    required String messageId,
    required String filePath,
    required String fileName,
    required String contentType,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$conversationId/messages/$messageId/attachment/retry',
        data: FormData.fromMap({
          'file': MultipartFile.fromFileSync(
            filePath,
            filename: fileName,
            contentType: MediaType.parse(contentType),
          ),
        }),
        options: _authorizedOptions(
          session,
        ).copyWith(contentType: 'multipart/form-data'),
      ),
    );

    return SupportChatMessage.fromJson(response.data ?? const {});
  }

  Future<void> markConversationRead(String conversationId) async {
    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/support/conversation/$conversationId/read',
        options: _authorizedOptions(session),
      ),
    );
  }

  Options _authorizedOptions(AuthSession session) {
    return Options(
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
      },
    );
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request,
  ) async {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _mapDioException,
      requestFailedMessage: 'support.request_failed',
      sessionExpiredMessage: 'auth.session_expired',
    );
  }

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    final payload = NetworkErrorMapper.parseApiPayload(error);
    if (payload.flattened != null) {
      return NetworkErrorMapper.fromMessage(
        error,
        payload.flattened!,
        includeCause: false,
      );
    }

    if (payload.detail != null || payload.title != null) {
      return NetworkErrorMapper.fromMessage(
        error,
        payload.detail ?? payload.title!,
        includeCause: false,
      );
    }

    if (NetworkErrorMapper.isConnectionUnavailable(error)) {
      return const AppException('support.unavailable', statusCode: 503);
    }

    return NetworkErrorMapper.fallback(
      error,
      fallbackMessage: fallbackMessage,
      includeCause: false,
    );
  }
}
