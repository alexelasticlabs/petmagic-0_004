import 'dart:async';

import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registration_cache.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';

final class PushTokenRegistrar {
  PushTokenRegistrar({
    required TemplateGenerationRepository templateRepository,
    required SupportChatRepository supportRepository,
    required WalletRepository walletRepository,
    PushTokenRegistrationCache? registrationCache,
  }) : _templateRepository = templateRepository,
       _supportRepository = supportRepository,
       _walletRepository = walletRepository,
       _registrationCache =
           registrationCache ?? SharedPreferencesPushTokenRegistrationCache();

  static final Map<String, Future<bool>> _inFlightRegistrations =
      <String, Future<bool>>{};
  static final Map<String, Future<bool>> _inFlightUnregistrations =
      <String, Future<bool>>{};
  static String? _lastCompletedRegistrationKey;

  final TemplateGenerationRepository _templateRepository;
  final SupportChatRepository _supportRepository;
  final WalletRepository _walletRepository;
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

    final registrationKey = _registrationKey(
      token: normalizedToken,
      platform: platform,
      locale: locale,
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
      platform: platform,
      locale: locale,
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
    await _registrationCache.clearLastCompletedRegistrationKeyForToken(token);
  }

  static Future<void> clearRegistrationState({
    PushTokenRegistrationCache? registrationCache,
  }) async {
    _lastCompletedRegistrationKey = null;
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
    final registrationKey = await _readLastCompletedRegistrationKey();
    if (registrationKey == null || registrationKey.isEmpty) {
      return null;
    }

    final separatorIndex = registrationKey.indexOf('|');
    if (separatorIndex <= 0) {
      return null;
    }

    final token = registrationKey.substring(0, separatorIndex).trim();
    return token.isEmpty ? null : token;
  }

  static void _invalidateTokenInMemory(String token) {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    final currentKey = _lastCompletedRegistrationKey;
    if (currentKey != null && currentKey.startsWith('$normalizedToken|')) {
      _lastCompletedRegistrationKey = null;
    }
    _inFlightRegistrations.removeWhere(
      (key, _) => key.startsWith('$normalizedToken|'),
    );
    _inFlightUnregistrations.remove(normalizedToken);
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
    required String platform,
    required String locale,
    String? appVersion,
    String? deviceId,
  }) {
    return [
      token,
      platform.trim(),
      locale.trim(),
      _nonEmpty(appVersion) ?? AppConfig.appVersion,
      _nonEmpty(deviceId) ?? '',
    ].join('|');
  }

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
