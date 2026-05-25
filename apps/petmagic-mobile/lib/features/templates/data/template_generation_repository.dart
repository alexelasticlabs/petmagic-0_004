import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

final templateGenerationRepositoryProvider =
    Provider<TemplateGenerationRepository>((ref) {
      return TemplateGenerationRepository(
        dio: ref.watch(dioProvider),
        sessionStorage: ref.watch(authSessionStorageProvider),
        authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
      );
    });

class TemplateGenerationRepository {
  TemplateGenerationRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
    AuthSessionCoordinator? authSessionCoordinator,
  }) : _dio = dio,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;

  Future<TemplateGenerationResult> startGeneration({
    required String templateId,
    required XFile sourceImage,
  }) async {
    final fileName = sourceImage.name.isNotEmpty
        ? sourceImage.name
        : sourceImage.path.split(Platform.pathSeparator).last;
    final contentType =
        sourceImage.mimeType ?? _resolveImageContentType(fileName);

    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) async => _dio.post<Map<String, dynamic>>(
        '/api/templates/$templateId/generations',
        data: FormData.fromMap({
          'sourceImage': await MultipartFile.fromFile(
            sourceImage.path,
            filename: fileName,
            contentType: MediaType.parse(contentType),
          ),
        }),
        options: _authOptions(session.accessToken, multipart: true),
      ),
    );

    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

  Future<TemplateGenerationResult> fetchGeneration(String generationId) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/templates/generations/$generationId',
        options: _authOptions(session.accessToken),
      ),
    );

    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

  Future<List<TemplateGenerationResult>> fetchGenerations({
    String? status,
    int? skip,
    int? take,
  }) async {
    final queryParameters = <String, Object?>{};
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }
    if (skip != null) {
      queryParameters['skip'] = skip;
    }
    if (take != null) {
      queryParameters['take'] = take;
    }

    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/templates/generations',
        queryParameters: queryParameters,
        options: _authOptions(session.accessToken),
      ),
    );

    return (response.data ?? const [])
        .whereType<Map>()
        .map(
          (item) => TemplateGenerationDto.fromJson(
            Map<String, dynamic>.from(item),
          ).toDomain(),
        )
        .toList(growable: false);
  }

  Future<int> fetchUnreadGenerationCount() async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/templates/generations/unread-count',
        options: _authOptions(session.accessToken),
      ),
    );

    return (response.data?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markGenerationRead(String generationId) async {
    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/templates/generations/$generationId/mark-read',
        options: _authOptions(session.accessToken),
      ),
    );
  }

  Future<void> submitGenerationFeedback({
    required String generationId,
    required int rating,
    List<String> selectedReasons = const [],
    String? comment,
    double? inputPhotoQualityScore,
  }) async {
    final data = <String, Object?>{
      'rating': rating,
      'selectedReasons': selectedReasons,
    };
    if (comment != null && comment.isNotEmpty) {
      data['comment'] = comment;
    }
    if (inputPhotoQualityScore != null) {
      data['inputPhotoQualityScore'] = inputPhotoQualityScore;
    }

    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/templates/generations/$generationId/feedback',
        data: data,
        options: _authOptions(session.accessToken),
      ),
    );
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
    String? appVersion,
    String? locale,
  }) async {
    await _authorizedRequest<void>(
      (session) => _dio.put<void>(
        '/api/templates/notifications/push-token',
        data: {
          'token': token,
          'platform': platform,
          if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
          if (appVersion != null && appVersion.isNotEmpty)
            'appVersion': appVersion,
          if (locale != null && locale.isNotEmpty) 'locale': locale,
        },
        options: _authOptions(session.accessToken),
      ),
    );
  }

  Future<void> unregisterPushToken(String token) async {
    await _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/templates/notifications/push-token',
        data: {'token': token},
        options: _authOptions(session.accessToken),
      ),
    );
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request,
  ) async {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _mapDioException,
      requestFailedMessage: 'templates.generation_failed',
      sessionExpiredMessage: 'auth.session_expired',
    );
  }

  Options _authOptions(String accessToken, {bool multipart = false}) {
    return Options(
      headers: {HttpHeaders.authorizationHeader: 'Bearer $accessToken'},
      contentType: multipart ? 'multipart/form-data' : null,
    );
  }

  AppException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    if (NetworkErrorMapper.isConnectivityIssue(error)) {
      return NetworkErrorMapper.fromMessage(
        error,
        'templates.network_unavailable',
      );
    }

    if (NetworkErrorMapper.isServerError(error)) {
      return NetworkErrorMapper.fromMessage(
        error,
        'templates.server_unavailable',
      );
    }

    return AppException(
      _problemDetail(error) ?? fallbackMessage,
      statusCode: error.response?.statusCode,
      cause: error,
    );
  }

  String _resolveImageContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  String? _problemDetail(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'] as String?;
      if (detail != null && detail.isNotEmpty) {
        return detail;
      }

      final title = data['title'] as String?;
      if (title != null && title.isNotEmpty) {
        return title;
      }
    }

    return error.message;
  }
}

class TemplateGenerationDto {
  const TemplateGenerationDto({
    required this.generationId,
    required this.userId,
    required this.templateId,
    required this.status,
    required this.tokenCost,
    required this.attemptCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.userMediaExpired,
    this.sourceImageAsset,
    this.normalizedImageUrl,
    this.referenceMotionUrl,
    this.outputUrl,
    this.usedPreprocessingModel,
    this.usedKlingModel,
    this.outputVideoDurationSeconds,
    this.failureCode,
    this.failureMessage,
    this.startedAtUtc,
    this.preprocessingCompletedAtUtc,
    this.motionGenerationCompletedAtUtc,
    this.mediaImportCompletedAtUtc,
    this.completedAtUtc,
    this.templateTitle,
    this.templateType,
    this.stage,
    this.progressPercent,
    this.estimatedDurationLabel,
    this.chargedAtUtc,
    this.refundedAtUtc,
    this.isUnread = false,
  });

  final String generationId;
  final String userId;
  final String templateId;
  final String status;
  final int tokenCost;
  final TemplateAssetDto? sourceImageAsset;
  final String? normalizedImageUrl;
  final String? referenceMotionUrl;
  final String? outputUrl;
  final int attemptCount;
  final String? usedPreprocessingModel;
  final String? usedKlingModel;
  final double? outputVideoDurationSeconds;
  final String? failureCode;
  final String? failureMessage;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? startedAtUtc;
  final DateTime? preprocessingCompletedAtUtc;
  final DateTime? motionGenerationCompletedAtUtc;
  final DateTime? mediaImportCompletedAtUtc;
  final DateTime? completedAtUtc;
  final String? templateTitle;
  final String? templateType;
  final String? stage;
  final int? progressPercent;
  final String? estimatedDurationLabel;
  final DateTime? chargedAtUtc;
  final DateTime? refundedAtUtc;
  final bool userMediaExpired;
  final bool isUnread;

  factory TemplateGenerationDto.fromJson(Map<String, dynamic> json) {
    final rawSourceImageAsset = json['sourceImageAsset'];

    return TemplateGenerationDto(
      generationId: json['generationId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      templateId: json['templateId'] as String? ?? '',
      status: json['status'] as String? ?? 'Queued',
      tokenCost: (json['tokenCost'] as num?)?.toInt() ?? 0,
      sourceImageAsset: rawSourceImageAsset is Map
          ? TemplateAssetDto.fromJson(
              Map<String, Object?>.from(rawSourceImageAsset),
            )
          : null,
      normalizedImageUrl: json['normalizedImageUrl'] as String?,
      referenceMotionUrl: json['referenceMotionUrl'] as String?,
      outputUrl: json['outputUrl'] as String?,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      usedPreprocessingModel: json['usedPreprocessingModel'] as String?,
      usedKlingModel: json['usedKlingModel'] as String?,
      outputVideoDurationSeconds: (json['outputVideoDurationSeconds'] as num?)
          ?.toDouble(),
      failureCode: json['failureCode'] as String?,
      failureMessage: json['failureMessage'] as String?,
      createdAtUtc: _dateTime(json['createdAtUtc']) ?? DateTime.now().toUtc(),
      updatedAtUtc: _dateTime(json['updatedAtUtc']) ?? DateTime.now().toUtc(),
      startedAtUtc: _dateTime(json['startedAtUtc']),
      preprocessingCompletedAtUtc: _dateTime(
        json['preprocessingCompletedAtUtc'],
      ),
      motionGenerationCompletedAtUtc: _dateTime(
        json['motionGenerationCompletedAtUtc'],
      ),
      mediaImportCompletedAtUtc: _dateTime(json['mediaImportCompletedAtUtc']),
      completedAtUtc: _dateTime(json['completedAtUtc']),
      templateTitle: json['templateTitle'] as String?,
      templateType: json['templateType'] as String?,
      stage: json['stage'] as String?,
      progressPercent: (json['progressPercent'] as num?)?.toInt(),
      estimatedDurationLabel: json['estimatedDurationLabel'] as String?,
      chargedAtUtc: _dateTime(json['chargedAtUtc']),
      refundedAtUtc: _dateTime(json['refundedAtUtc']),
      userMediaExpired: json['userMediaExpired'] as bool? ?? false,
      isUnread: json['isUnread'] as bool? ?? false,
    );
  }

  TemplateGenerationResult toDomain() {
    return TemplateGenerationResult(
      generationId: generationId,
      userId: userId,
      templateId: templateId,
      status: templateGenerationStatusFromApi(status),
      tokenCost: tokenCost,
      sourceImageAsset: sourceImageAsset?.toDomain(),
      normalizedImageUrl: normalizedImageUrl,
      referenceMotionUrl: referenceMotionUrl,
      outputUrl: outputUrl,
      attemptCount: attemptCount,
      usedPreprocessingModel: usedPreprocessingModel,
      usedKlingModel: usedKlingModel,
      outputVideoDurationSeconds: outputVideoDurationSeconds,
      failureCode: failureCode,
      failureMessage: failureMessage,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      templateTitle: templateTitle,
      templateType: templateType,
      stage: stage,
      progressPercent: progressPercent,
      estimatedDurationLabel: estimatedDurationLabel,
      startedAtUtc: startedAtUtc,
      preprocessingCompletedAtUtc: preprocessingCompletedAtUtc,
      motionGenerationCompletedAtUtc: motionGenerationCompletedAtUtc,
      mediaImportCompletedAtUtc: mediaImportCompletedAtUtc,
      completedAtUtc: completedAtUtc,
      chargedAtUtc: chargedAtUtc,
      refundedAtUtc: refundedAtUtc,
      userMediaExpired: userMediaExpired,
      isUnread: isUnread,
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value)?.toUtc();
  }
}
