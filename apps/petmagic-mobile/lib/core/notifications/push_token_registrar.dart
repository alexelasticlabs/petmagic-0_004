import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registration_cache.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';

final class PushTokenRegistrar {
  PushTokenRegistrar({
    required TemplateGenerationRepository templateRepository,
    required SupportChatRepository supportRepository,
    required WalletRepository walletRepository,
    AuthSessionStorage? sessionStorage,
    PushTokenRegistrationCache? registrationCache,
  }) : _templateRepository = templateRepository,
       _supportRepository = supportRepository,
       _walletRepository = walletRepository,
       _sessionStorage = sessionStorage ?? AuthSessionStorage(),
       _registrationCache =
           registrationCache ?? SharedPreferencesPushTokenRegistrationCache();

  static final Map<String, Future<bool>> _inFlightRegistrations =
      <String, Future<bool>>{};
  static final Map<String, Future<bool>> _inFlightUnregistrations =
      <String, Future<bool>>{};
  static String? _lastCompletedRegistrationKey;
  static String? _lastCompletedRegistrationToken;

  final TemplateGenerationRepository _templateRepository;
  final SupportChatRepository _supportRepository;
  final WalletRepository _walletRepository;
  final AuthSessionStorage _sessionStorage;
  final PushTokenRegistrationCache _registrationCache;

  Future<bool> registerToken({
    required String token,
    required String platform,
    required String locale,
    String? appVersion,
    String? deviceId,
    bool Function()? canContinue,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty || !_canContinue(canContinue)) {
      return false;
    }

    final normalizedPlatform = _normalizePlatform(platform);
    final normalizedLocale = _normalizeLocale(locale);

    final accountScope = await _readAccountScope();
    if (accountScope == null || !_canContinue(canContinue)) {
      return false;
    }

    final registrationKey = _registrationKey(
      token: normalizedToken,
      accountScope: accountScope,
      platform: normalizedPlatform,
      locale: normalizedLocale,
      appVersion: appVersion,
      deviceId: deviceId,
    );
    final lastCompletedRegistrationKey =
        await _readLastCompletedRegistrationKey();
    if (lastCompletedRegistrationKey == registrationKey) {
      return true;
    }

    final existing = _inFlightRegistrations[registrationKey];
    if (existing != null) {
      return existing;
    }

    final task = _registerTokenUncached(
      token: normalizedToken,
      platform: normalizedPlatform,
      locale: normalizedLocale,
      appVersion: appVersion,
      deviceId: deviceId,
      canContinue: canContinue,
      registrationKey: registrationKey,
    );
    _inFlightRegistrations[registrationKey] = task;

    try {
      return await task;
    } finally {
      if (identical(_inFlightRegistrations[registrationKey], task)) {
        _inFlightRegistrations.remove(registrationKey);
      }
    }
  }

  static void invalidateToken(String token) {
    _invalidateTokenInMemory(token);
  }

  Future<void> invalidatePersistedToken(String token) async {
    _invalidateTokenInMemory(token);
    await _registrationCache.clear();
  }

  static Future<void> clearRegistrationState({
    PushTokenRegistrationCache? registrationCache,
  }) async {
    _lastCompletedRegistrationKey = null;
    _lastCompletedRegistrationToken = null;
    _inFlightRegistrations.clear();
    _inFlightUnregistrations.clear();
    await (registrationCache ?? SharedPreferencesPushTokenRegistrationCache())
        .clear();
  }

  Future<bool> unregisterToken({
    required String token,
    bool Function()? canContinue,
    void Function(String stage, Object error, StackTrace stackTrace)? onFailure,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty || !_canContinue(canContinue)) {
      return false;
    }

    final existing = _inFlightUnregistrations[normalizedToken];
    if (existing != null) {
      return existing;
    }

    final task = _unregisterTokenUncached(
      token: normalizedToken,
      canContinue: canContinue,
      onFailure: onFailure,
    );
    _inFlightUnregistrations[normalizedToken] = task;

    try {
      return await task;
    } finally {
      if (identical(_inFlightUnregistrations[normalizedToken], task)) {
        _inFlightUnregistrations.remove(normalizedToken);
      }
    }
  }

  Future<String?> readRegisteredToken() async {
    return _nonEmpty(_lastCompletedRegistrationToken);
  }

  static void _invalidateTokenInMemory(String token) {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    if (_lastCompletedRegistrationToken == normalizedToken) {
      final currentKey = _lastCompletedRegistrationKey;
      _lastCompletedRegistrationKey = null;
      _lastCompletedRegistrationToken = null;
      _inFlightRegistrations.removeWhere((key, _) => key == currentKey);
    }
    _inFlightUnregistrations.remove(normalizedToken);
  }

  Future<String?> _readAccountScope() async {
    final session = await _sessionStorage.read();
    return _nonEmpty(session?.user.userId);
  }

  Future<String?> _readLastCompletedRegistrationKey() async {
    final inMemory = _lastCompletedRegistrationKey;
    if (inMemory != null && inMemory.isNotEmpty) {
      return inMemory;
    }

    final persisted = await _registrationCache
        .readLastCompletedRegistrationKey();
    final normalized = _nonEmpty(persisted);
    if (normalized != null) {
      _lastCompletedRegistrationKey = normalized;
    }

    return normalized;
  }

  Future<bool> _registerTokenUncached({
    required String token,
    required String platform,
    required String locale,
    required String registrationKey,
    required bool Function()? canContinue,
    String? appVersion,
    String? deviceId,
  }) async {
    if (!_canContinue(canContinue)) {
      return false;
    }

    final resolvedAppVersion = _nonEmpty(appVersion) ?? AppConfig.appVersion;
    final resolvedDeviceId = _nonEmpty(deviceId);

    await Future.wait<void>([
      _templateRepository.registerPushToken(
        token: token,
        platform: platform,
        appVersion: resolvedAppVersion,
        deviceId: resolvedDeviceId,
        locale: locale,
      ),
      _supportRepository.registerPushToken(
        token: token,
        platform: platform,
        appVersion: resolvedAppVersion,
        deviceId: resolvedDeviceId,
        locale: locale,
      ),
      _walletRepository.registerPushToken(
        token: token,
        platform: platform,
        locale: locale,
      ),
    ], eagerError: true);

    if (!_canContinue(canContinue)) {
      return false;
    }

    _lastCompletedRegistrationKey = registrationKey;
    _lastCompletedRegistrationToken = token;
    await _registrationCache.writeLastCompletedRegistrationKey(registrationKey);
    return true;
  }

  Future<bool> _unregisterTokenUncached({
    required String token,
    required bool Function()? canContinue,
    required void Function(String stage, Object error, StackTrace stackTrace)?
    onFailure,
  }) async {
    if (!_canContinue(canContinue)) {
      return false;
    }

    var allUnregistered = true;
    await Future.wait<void>([
      _templateRepository.unregisterPushToken(token).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        allUnregistered = false;
        onFailure?.call('template', error, stackTrace);
      }),
      _supportRepository.unregisterPushToken(token).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        allUnregistered = false;
        onFailure?.call('support', error, stackTrace);
      }),
      _walletRepository.unregisterPushToken(token).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        allUnregistered = false;
        onFailure?.call('wallet', error, stackTrace);
      }),
    ]);

    if (!allUnregistered || !_canContinue(canContinue)) {
      return false;
    }

    await invalidatePersistedToken(token);
    return true;
  }

  static bool _canContinue(bool Function()? canContinue) {
    return canContinue == null || canContinue();
  }

  static String _registrationKey({
    required String token,
    required String accountScope,
    required String platform,
    required String locale,
    String? appVersion,
    String? deviceId,
  }) {
    final payload = jsonEncode([
      token,
      accountScope,
      platform.trim(),
      locale.trim(),
      _nonEmpty(appVersion) ?? AppConfig.appVersion,
      _nonEmpty(deviceId) ?? '',
    ]);
    return '$pushTokenRegistrationFingerprintPrefix${sha256.convert(utf8.encode(payload))}';
  }

  static String _normalizePlatform(String platform) {
    return platform.trim().toLowerCase();
  }

  static String _normalizeLocale(String locale) {
    final normalized = locale.trim().replaceAll('_', '-');
    if (normalized.isEmpty) {
      return normalized;
    }

    final parts = normalized
        .split('-')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '';
    }

    final canonical = <String>[parts.first.toLowerCase()];
    for (final rawPart in parts.skip(1)) {
      final part = rawPart.trim();
      if (part.length == 4) {
        canonical.add(
          '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        );
        continue;
      }

      if (_localeRegionSegmentPattern.hasMatch(part)) {
        canonical.add(part.toUpperCase());
        continue;
      }

      canonical.add(part.toLowerCase());
    }

    return canonical.join('-');
  }

  static final RegExp _localeRegionSegmentPattern = RegExp(
    r'^[A-Za-z]{2}$|^[0-9]{3}$',
  );

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
