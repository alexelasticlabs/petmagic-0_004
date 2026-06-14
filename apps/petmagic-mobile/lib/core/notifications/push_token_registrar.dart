import 'dart:async';

import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';

final class PushTokenRegistrar {
  PushTokenRegistrar({
    required TemplateGenerationRepository templateRepository,
    required SupportChatRepository supportRepository,
    required WalletRepository walletRepository,
  }) : _templateRepository = templateRepository,
       _supportRepository = supportRepository,
       _walletRepository = walletRepository;

  static final Map<String, Future<bool>> _inFlightRegistrations =
      <String, Future<bool>>{};
  static String? _lastCompletedRegistrationKey;

  final TemplateGenerationRepository _templateRepository;
  final SupportChatRepository _supportRepository;
  final WalletRepository _walletRepository;

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
    if (_lastCompletedRegistrationKey == registrationKey) {
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
