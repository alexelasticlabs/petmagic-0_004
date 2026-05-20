import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';

final supportChatRepositoryProvider = Provider<SupportChatRepository>((ref) {
  return SupportChatRepository(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
  );
});

class SupportChatRepository {
  SupportChatRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
  }) : _dio = dio,
       _sessionStorage = sessionStorage;

  final Dio _dio;
  final AuthSessionStorage _sessionStorage;

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
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$conversationId/messages',
        data: {'body': body.trim()},
        options: _authorizedOptions(session),
      ),
    );

    return SupportChatMessage.fromJson(response.data ?? const {});
  }

  Future<SupportChatMessage> sendImageAttachment({
    required String conversationId,
    required String filePath,
    required String fileName,
    required String contentType,
    String? body,
  }) async {
    final trimmedBody = body?.trim() ?? '';
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '/api/support/conversation/$conversationId/attachments',
        data: FormData.fromMap({
          if (trimmedBody.isNotEmpty) 'body': trimmedBody,
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
    var session = await _sessionStorage.read();
    if (session == null) {
      throw const AppException('Sign in is required.', statusCode: 401);
    }

    try {
      return await request(session);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        session = await _refreshSession(session.refreshToken);
        return request(session);
      }

      throw _mapDioException(error, fallbackMessage: 'Support request failed.');
    }
  }

  Future<AuthSession> _refreshSession(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final refreshed = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(refreshed);
      return refreshed;
    } on DioException catch (error) {
      await _sessionStorage.clear();
      throw _mapDioException(error, fallbackMessage: 'Session expired.');
    }
  }

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final detail = responseData['detail'] as String?;
      final title = responseData['title'] as String?;
      final errors = responseData['errors'];
      if (errors is Map<String, dynamic>) {
        final flattened = errors.values
            .whereType<List<dynamic>>()
            .expand((value) => value.whereType<String>())
            .join(' ');
        if (flattened.isNotEmpty) {
          return AppException(
            flattened,
            statusCode: error.response?.statusCode,
          );
        }
      }

      if ((detail?.isNotEmpty ?? false) || (title?.isNotEmpty ?? false)) {
        return AppException(
          detail?.isNotEmpty == true ? detail! : title!,
          statusCode: error.response?.statusCode,
        );
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const AppException(
        'Unable to reach support right now. Please check your connection and try again.',
        statusCode: 503,
      );
    }

    return AppException(
      fallbackMessage,
      statusCode: error.response?.statusCode,
    );
  }
}
