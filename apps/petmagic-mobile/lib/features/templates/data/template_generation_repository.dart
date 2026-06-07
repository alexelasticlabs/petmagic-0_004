import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/network_error_mapper.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

final templateGenerationSharedPreferencesProvider =
    Provider<SharedPreferencesAsync>((ref) => SharedPreferencesAsync());

final templateGenerationRepositoryProvider =
    Provider<TemplateGenerationRepository>((ref) {
      return TemplateGenerationRepository(
        dio: ref.watch(dioProvider),
        sessionStorage: ref.watch(authSessionStorageProvider),
        preferences: ref.watch(templateGenerationSharedPreferencesProvider),
        authSessionCoordinator: ref.watch(authSessionCoordinatorProvider),
      );
    });

class TemplateGenerationRepository {
  TemplateGenerationRepository({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
    required SharedPreferencesAsync preferences,
    AuthSessionCoordinator? authSessionCoordinator,
  }) : _dio = dio,
       _preferences = preferences,
       _authSessionCoordinator =
           authSessionCoordinator ??
           AuthSessionCoordinator(dio: dio, sessionStorage: sessionStorage);

  static const _generationsCachePrefix = 'templates_generations_v1:';
  static const _unreadCountCacheKey = 'templates_generations_unread_v1';
  static const _activeGenerationIdKey = 'templates_active_generation_id_v1';
  static const _activeGenerationCorrelationIdKey =
      'templates_active_generation_correlation_id_v1';
  static const _maxSourceImageBytes = 12 * 1024 * 1024;
  static const _cacheAllStatusKey = 'all';
  static const _cacheStatuses = <String>[
    _cacheAllStatusKey,
    'active',
    'ready',
    'failed',
  ];

  final Dio _dio;
  final SharedPreferencesAsync _preferences;
  final AuthSessionCoordinator _authSessionCoordinator;

  Future<TemplateGenerationResult> startGeneration({
    required String templateId,
    required XFile sourceImage,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    final rawFileName = sourceImage.name.isNotEmpty
        ? sourceImage.name
        : sourceImage.path.split(Platform.pathSeparator).last;
    final fileName = _safeSourceImageFileName(rawFileName);
    final declaredContentType =
        sourceImage.mimeType ?? _resolveImageContentType(fileName);
    if (!_isAllowedImageContentType(declaredContentType)) {
      throw const AppException('templates.source_image_type_not_allowed');
    }

    final fileSize = await _sourceImageSizeBytes(sourceImage.path);
    if (fileSize <= 0) {
      throw const AppException('templates.source_image_empty');
    }
    if (fileSize > _maxSourceImageBytes) {
      throw const AppException('templates.source_image_too_large');
    }

    final contentType = await _detectSourceImageContentType(sourceImage.path);
    if (contentType == null) {
      throw const AppException('templates.source_image_type_not_allowed');
    }

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
        options: authenticatedMultipartRequestOptions(
          session.accessToken,
          correlationId: correlationId,
        ),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.get<Map<String, dynamic>>(
        '/api/templates/generations/$generationId',
        options: authenticatedRequestOptions(
          session.accessToken,
          correlationId: correlationId,
        ),
        cancelToken: cancelToken,
      ),
    );

    return TemplateGenerationDto.fromJson(response.data ?? const {}).toDomain();
  }

  Future<List<TemplateGenerationResult>?> readCachedGenerations({
    String? status,
  }) async {
    try {
      final raw = await _preferences.getString(_cacheKeyForStatus(status));
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return null;
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => TemplateGenerationDto.fromJson(
              Map<String, dynamic>.from(item),
            ).toDomain(),
          )
          .toList(growable: false);
    } on Object {
      return null;
    }
  }

  Future<TemplateGenerationResult?> readCachedGeneration(
    String generationId,
  ) async {
    for (final status in _cacheStatuses) {
      final items = await readCachedGenerations(
        status: status == _cacheAllStatusKey ? null : status,
      );
      if (items == null || items.isEmpty) {
        continue;
      }

      for (final item in items) {
        if (item.generationId == generationId) {
          return item;
        }
      }
    }

    return null;
  }

  Future<int?> readCachedUnreadGenerationCount() async {
    try {
      return await _preferences.getInt(_unreadCountCacheKey);
    } on Object {
      return null;
    }
  }

  Future<({String generationId, String? correlationId})?>
  readActiveGeneration() async {
    try {
      final generationId = await _preferences.getString(_activeGenerationIdKey);
      if (generationId == null || generationId.trim().isEmpty) {
        return null;
      }

      final correlationId = await _preferences.getString(
        _activeGenerationCorrelationIdKey,
      );
      return (
        generationId: generationId.trim(),
        correlationId: correlationId == null || correlationId.trim().isEmpty
            ? null
            : correlationId.trim(),
      );
    } on Object {
      return null;
    }
  }

  Future<void> rememberActiveGeneration({
    required String generationId,
    String? correlationId,
  }) async {
    try {
      await _preferences.setString(_activeGenerationIdKey, generationId);
      final trimmedCorrelationId = correlationId?.trim();
      if (trimmedCorrelationId == null || trimmedCorrelationId.isEmpty) {
        await _preferences.remove(_activeGenerationCorrelationIdKey);
      } else {
        await _preferences.setString(
          _activeGenerationCorrelationIdKey,
          trimmedCorrelationId,
        );
      }
    } on Object {
      // Keep generation flow functional even if local persistence fails.
    }
  }

  Future<void> clearActiveGeneration(String generationId) async {
    try {
      final current = await _preferences.getString(_activeGenerationIdKey);
      if (current != null && current != generationId) {
        return;
      }

      await _preferences.remove(_activeGenerationIdKey);
      await _preferences.remove(_activeGenerationCorrelationIdKey);
    } on Object {
      // Keep cleanup best-effort.
    }
  }

  Future<void> clearLocalCache() async {
    for (final status in _cacheStatuses) {
      final key = _cacheKeyForStatus(
        status == _cacheAllStatusKey ? null : status,
      );
      try {
        await _preferences.remove(key);
      } on Object {
        // Keep best-effort semantics for logout cleanup.
      }
    }

    try {
      await _preferences.remove(_unreadCountCacheKey);
    } on Object {
      // Keep best-effort semantics for logout cleanup.
    }

    try {
      await _preferences.remove(_activeGenerationIdKey);
      await _preferences.remove(_activeGenerationCorrelationIdKey);
    } on Object {
      // Keep best-effort semantics for logout cleanup.
    }
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
        options: authenticatedRequestOptions(session.accessToken),
      ),
    );

    final itemsJson = (response.data ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);

    await _writeCachedGenerations(status: status, items: itemsJson);

    return itemsJson
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
        options: authenticatedRequestOptions(session.accessToken),
      ),
    );

    final count = (response.data?['count'] as num?)?.toInt() ?? 0;
    await _writeCachedUnreadGenerationCount(count);
    return count;
  }

  Future<void> markGenerationRead(String generationId) async {
    await _authorizedRequest<void>(
      (session) => _dio.post<void>(
        '/api/templates/generations/$generationId/mark-read',
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    await _markCachedGenerationRead(generationId);
  }

  Future<void> deleteGeneration(String generationId) async {
    await _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/templates/generations/$generationId',
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );

    await _removeCachedGeneration(generationId);
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
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
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
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );
  }

  Future<void> unregisterPushToken(String token) async {
    await _authorizedRequest<void>(
      (session) => _dio.delete<void>(
        '/api/templates/notifications/push-token',
        data: {'token': token},
        options: authenticatedRequestOptions(session.accessToken),
      ),
      retryTransientFailures: false,
    );
  }

  Future<void> _writeCachedGenerations({
    required String? status,
    required List<Map<String, Object?>> items,
  }) async {
    try {
      await _preferences.setString(
        _cacheKeyForStatus(status),
        jsonEncode(items),
      );
    } on Object {
      // Ignore local cache write errors to keep network flow stable.
    }
  }

  Future<void> _writeCachedUnreadGenerationCount(int count) async {
    try {
      await _preferences.setInt(_unreadCountCacheKey, count);
    } on Object {
      // Ignore local cache write errors to keep network flow stable.
    }
  }

  String _cacheKeyForStatus(String? status) {
    final normalized = (status == null || status.trim().isEmpty)
        ? _cacheAllStatusKey
        : status.trim().toLowerCase();
    return '$_generationsCachePrefix$normalized';
  }

  Future<void> _markCachedGenerationRead(String generationId) async {
    for (final status in _cacheStatuses) {
      final key = _cacheKeyForStatus(
        status == _cacheAllStatusKey ? null : status,
      );
      final raw = await _preferences.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        continue;
      }

      var changed = false;
      final updated = decoded
          .map((entry) {
            if (entry is! Map) {
              return entry;
            }

            final generation = Map<String, Object?>.from(entry);
            if (generation['generationId'] != generationId) {
              return generation;
            }

            if (generation['isUnread'] == false) {
              return generation;
            }

            changed = true;
            return {...generation, 'isUnread': false};
          })
          .toList(growable: false);

      if (changed) {
        await _preferences.setString(key, jsonEncode(updated));
      }
    }

    final unread = await readCachedUnreadGenerationCount();
    if (unread != null && unread > 0) {
      await _writeCachedUnreadGenerationCount(unread - 1);
    }
  }

  Future<void> _removeCachedGeneration(String generationId) async {
    var removedUnread = false;

    for (final status in _cacheStatuses) {
      final key = _cacheKeyForStatus(
        status == _cacheAllStatusKey ? null : status,
      );
      final raw = await _preferences.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        continue;
      }

      var changed = false;
      final updated = <Map<String, Object?>>[];
      for (final entry in decoded.whereType<Map>()) {
        final generation = Map<String, Object?>.from(entry);
        if (generation['generationId'] == generationId) {
          changed = true;
          if (generation['isUnread'] == true) {
            removedUnread = true;
          }
          continue;
        }
        updated.add(generation);
      }

      if (changed) {
        await _preferences.setString(key, jsonEncode(updated));
      }
    }

    if (removedUnread) {
      final unread = await readCachedUnreadGenerationCount();
      if (unread != null && unread > 0) {
        await _writeCachedUnreadGenerationCount(unread - 1);
      }
    }
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request, {
    bool retryTransientFailures = true,
  }) async {
    return _authSessionCoordinator.authorizedRequest(
      request: request,
      mapError: _mapDioException,
      requestFailedMessage: 'templates.generation_failed',
      sessionExpiredMessage: 'auth.session_expired',
      transientRetryAttempts: retryTransientFailures ? 2 : 1,
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
      NetworkErrorMapper.safePayloadMessage(
            NetworkErrorMapper.parseApiPayload(error),
          ) ??
          fallbackMessage,
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

  String _safeSourceImageFileName(String rawFileName) {
    final basename = rawFileName
        .replaceAll(r'\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .lastOrNull;
    return sanitizeFileName(basename, fallback: 'petmagic_source_image.jpg');
  }

  bool _isAllowedImageContentType(String contentType) {
    final normalized = contentType.toLowerCase();
    return normalized == 'image/jpeg' ||
        normalized == 'image/png' ||
        normalized == 'image/webp' ||
        normalized == 'image/heic' ||
        normalized == 'image/heif';
  }

  Future<String?> _detectSourceImageContentType(String path) async {
    final header = await _sourceImageHeader(path);
    if (_startsWith(header, const [0xFF, 0xD8, 0xFF])) {
      return 'image/jpeg';
    }
    if (_startsWith(
      header,
      const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    )) {
      return 'image/png';
    }
    if (header.length >= 12 &&
        _asciiEquals(header, 0, 'RIFF') &&
        _asciiEquals(header, 8, 'WEBP')) {
      return 'image/webp';
    }
    if (header.length >= 12 && _asciiEquals(header, 4, 'ftyp')) {
      final brand = String.fromCharCodes(header.skip(8).take(4)).toLowerCase();
      const heicBrands = {'heic', 'heix', 'hevc', 'hevx', 'heis', 'heim'};
      const heifBrands = {'mif1', 'msf1'};
      if (heicBrands.contains(brand)) {
        return 'image/heic';
      }
      if (heifBrands.contains(brand)) {
        return 'image/heif';
      }
    }

    return null;
  }

  Future<List<int>> _sourceImageHeader(String path) async {
    try {
      final chunks = await File(path).openRead(0, 32).toList();
      return [for (final chunk in chunks) ...chunk];
    } on FileSystemException catch (error) {
      throw AppException('templates.source_image_unavailable', cause: error);
    }
  }

  bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) {
        return false;
      }
    }
    return true;
  }

  bool _asciiEquals(List<int> bytes, int offset, String value) {
    if (bytes.length < offset + value.length) {
      return false;
    }
    for (var index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) {
        return false;
      }
    }
    return true;
  }

  Future<int> _sourceImageSizeBytes(String path) async {
    try {
      return await File(path).length();
    } on FileSystemException catch (error) {
      throw AppException('templates.source_image_unavailable', cause: error);
    }
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
    this.queuePosition,
    this.estimatedWaitSeconds,
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
  final int? queuePosition;
  final int? estimatedWaitSeconds;

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
      queuePosition: (json['queuePosition'] as num?)?.toInt(),
      estimatedWaitSeconds: (json['estimatedWaitSeconds'] as num?)?.toInt(),
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
      queuePosition: queuePosition,
      estimatedWaitSeconds: estimatedWaitSeconds,
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value)?.toUtc();
  }
}
