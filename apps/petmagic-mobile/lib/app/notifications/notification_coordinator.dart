import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/notifications/notification_foreground_copy.dart';
import 'package:petmagic_mobile/app/notifications/push_token_registrar.dart';
import 'package:petmagic_mobile/features/support/application/support_contract.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_contract.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

class NotificationCoordinator {
  NotificationCoordinator({
    required GenerationRepository templateRepository,
    required SupportRepository supportRepository,
    required WalletRepositoryPort walletRepository,
    required AuthSessionStore sessionStorage,
    required void Function(String route) onRouteRequested,
  }) : _pushTokenRegistrar = PushTokenRegistrar(
         templateRepository: templateRepository,
         supportRepository: supportRepository,
         walletRepository: walletRepository,
         sessionStorage: sessionStorage,
       ),
       _onRouteRequested = onRouteRequested;

  final PushTokenRegistrar _pushTokenRegistrar;
  final void Function(String route) _onRouteRequested;
  static const _allowedNotificationRoutes = <String>{
    '/templates',
    '/creations',
    '/rewards',
    '/profile',
    '/profile/support',
    '/profile/support/chat',
    '/profile/wallet',
    '/profile/premium',
    '/profile/subscription/manage',
  };
  static final RegExp _routeControlCharacters = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _safeGenerationId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static const Duration _handledInteractionWindow = Duration(minutes: 5);
  static const int _maxHandledInteractions = 128;
  static const int _maxExternalDedupeKeyLength = 160;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  final Map<String, DateTime> _handledInteractions = <String, DateTime>{};
  String? _lastRegisteredToken;
  bool _isDisposed = false;
  bool _initialMessageHandled = false;
  bool _initialized = false;
  bool _initializing = false;
  bool _authenticatedReady = false;
  bool _authSessionActive = false;
  int _registrationEpoch = 0;

  Future<void> initializeForAuthenticatedUser() async {
    if (_isDisposed ||
        _authenticatedReady ||
        _initializing ||
        !_firebaseReady) {
      return;
    }

    _authSessionActive = true;
    _initializing = true;
    try {
      await _ensureInitialized();
      final permissionAllowed = await _ensureNotificationPermissionAllowed();
      if (!permissionAllowed) {
        await _unregisterCurrentToken(markSessionInactive: false);
        _authenticatedReady = true;
        return;
      }

      await registerCurrentToken();

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (!_initialMessageHandled && initialMessage != null) {
        _initialMessageHandled = true;
        _handleRemoteMessageRoute(initialMessage);
      } else {
        _initialMessageHandled = true;
      }

      _authenticatedReady = true;
    } finally {
      _initializing = false;
    }
  }

  Future<void> registerCurrentToken() async {
    if (_isDisposed || !_firebaseReady || !_authSessionActive) {
      return;
    }

    try {
      final permissionAllowed = await _notificationsAllowed();
      if (!permissionAllowed) {
        await _unregisterCurrentToken(markSessionInactive: false);
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final epoch = _registrationEpoch;
      final previousToken = _lastRegisteredToken;
      final registered = await _registerTokenWithRetry(token, epoch: epoch);
      if (registered && _canContinueRegistration(epoch)) {
        _lastRegisteredToken = token;
        await _unregisterStaleToken(previousToken, replacementToken: token);
      }
    } catch (error, stackTrace) {
      _logNotificationFailure('register_current_token', error, stackTrace);
    }
  }

  Future<void> unregisterCurrentTokenOnSignOut() async {
    await _unregisterCurrentToken(markSessionInactive: true);
  }

  Future<void> _unregisterCurrentToken({
    required bool markSessionInactive,
  }) async {
    final epoch = ++_registrationEpoch;
    if (markSessionInactive) {
      _authSessionActive = false;
      _authenticatedReady = false;
      _handledInteractions.clear();
    }

    final token =
        _lastRegisteredToken ??
        await _pushTokenRegistrar.readRegisteredToken() ??
        await _readCurrentFirebaseToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final allUnregistered = await _pushTokenRegistrar.unregisterToken(
      token: token,
      canContinue: () => !_isDisposed && epoch == _registrationEpoch,
      onFailure: (stage, error, stackTrace) {
        _logNotificationFailure('unregister_${stage}_token', error, stackTrace);
      },
    );

    if (allUnregistered) {
      _lastRegisteredToken = null;
    } else {
      _lastRegisteredToken = token;
    }
  }

  Future<String?> _readCurrentFirebaseToken() async {
    if (!_firebaseReady) {
      return null;
    }

    final token = await FirebaseMessaging.instance.getToken();
    final normalized = token?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  void handleForegroundMessage(RemoteMessage message) {
    if (_isDisposed || !_shouldDisplayForeground(message)) {
      return;
    }

    final type = message.data['type'] as String?;
    final title = _fallbackTitle(type);
    final messageText = _fallbackBody(type);
    final dedupeKey =
        _safeExternalDedupeKey(message.data['dedupe_key']) ??
        _safeExternalDedupeKey(message.data['dedupeKey']) ??
        _safeExternalDedupeKey(message.messageId) ??
        '${type ?? 'update'}:${messageText.hashCode}:$title';
    final route = _routeFromMap(message.data);

    PetMagicToast.show(
      null,
      title: title,
      message: messageText,
      tone: _foregroundMessageTone(message),
      action: route == null
          ? null
          : PetMagicNotificationAction(
              label: _openActionLabel(),
              onPressed: () => _onRouteRequested(route),
            ),
      dedupeKey: dedupeKey,
    );
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _authSessionActive = false;
    _registrationEpoch++;
    await _tokenRefreshSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    _handledInteractions.clear();
  }

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.getNotificationSettings();
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen((token) {
      if (token.isEmpty) {
        return;
      }
      final previousToken = _lastRegisteredToken;
      if (!_authSessionActive) {
        return;
      }
      final epoch = _registrationEpoch;
      unawaited(
        _registerRefreshedToken(
          token,
          previousToken: previousToken,
          epoch: epoch,
        ),
      );
    });

    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleRemoteMessageRoute,
    );
    _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      handleForegroundMessage,
    );
    _initialized = true;
  }

  Future<bool> _ensureNotificationPermissionAllowed() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (_isNotificationPermissionAllowed(settings.authorizationStatus)) {
      return true;
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return false;
    }

    final requested = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _isNotificationPermissionAllowed(requested.authorizationStatus);
  }

  Future<bool> _notificationsAllowed() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return _isNotificationPermissionAllowed(settings.authorizationStatus);
  }

  bool _isNotificationPermissionAllowed(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<void> _registerRefreshedToken(
    String token, {
    required String? previousToken,
    required int epoch,
  }) async {
    try {
      if (_isDisposed || !_firebaseReady || !_authSessionActive) {
        return;
      }
      if (!await _notificationsAllowed()) {
        return;
      }
      final registered = await _registerTokenWithRetry(token, epoch: epoch);
      if (registered && _canContinueRegistration(epoch)) {
        _lastRegisteredToken = token;
        await _unregisterStaleToken(previousToken, replacementToken: token);
      }
    } catch (error, stackTrace) {
      _logNotificationFailure('register_refreshed_token', error, stackTrace);
    }
  }

  Future<bool> _registerTokenWithRetry(
    String token, {
    required int epoch,
  }) async {
    const maxAttempts = 4;
    const backoffs = [400, 900, 1800, 3600];

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!_canContinueRegistration(epoch)) {
        return false;
      }

      try {
        final registered = await _pushTokenRegistrar.registerToken(
          token: token,
          platform: Platform.operatingSystem,
          locale: Platform.localeName,
          canContinue: () => _canContinueRegistration(epoch),
        );
        return registered && _canContinueRegistration(epoch);
      } catch (error, stackTrace) {
        if (!_canContinueRegistration(epoch)) {
          return false;
        }

        _logNotificationFailure(
          'register_token_attempt_failed',
          error,
          stackTrace,
          context: {'attempt': attempt + 1, 'max_attempts': maxAttempts},
        );
        if (attempt == maxAttempts - 1) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: backoffs[attempt]));
      }
    }

    return false;
  }

  Future<void> _unregisterStaleToken(
    String? staleToken, {
    required String replacementToken,
  }) async {
    final normalizedStaleToken = staleToken?.trim();
    if (normalizedStaleToken == null ||
        normalizedStaleToken.isEmpty ||
        normalizedStaleToken == replacementToken.trim()) {
      return;
    }

    await _pushTokenRegistrar.unregisterToken(
      token: normalizedStaleToken,
      clearRegistrationState: false,
      canContinue: () => !_isDisposed,
      onFailure: (stage, error, stackTrace) {
        _logNotificationFailure(
          'unregister_stale_${stage}_token',
          error,
          stackTrace,
        );
      },
    );
  }

  bool _canContinueRegistration(int epoch) {
    return !_isDisposed && _authSessionActive && epoch == _registrationEpoch;
  }

  void _handleRemoteMessageRoute(RemoteMessage message) {
    if (!_markInteractionHandled(message)) {
      return;
    }

    final route = _routeFromMap(message.data);
    if (route != null) {
      _onRouteRequested(route);
    }
  }

  bool _markInteractionHandled(RemoteMessage message) {
    final key = _interactionDedupeKey(message);
    final now = DateTime.now();
    _pruneHandledInteractions(now);

    final handledAt = _handledInteractions[key];
    if (handledAt != null &&
        now.difference(handledAt) <= _handledInteractionWindow) {
      return false;
    }

    _handledInteractions[key] = now;
    _trimHandledInteractionsToLimit();
    return true;
  }

  String _interactionDedupeKey(RemoteMessage message) {
    return _safeExternalDedupeKey(message.data['dedupe_key']) ??
        _safeExternalDedupeKey(message.data['dedupeKey']) ??
        _safeExternalDedupeKey(message.messageId) ??
        _routeFromMap(message.data) ??
        _fingerprintNotificationData(message.data);
  }

  void _pruneHandledInteractions(DateTime now) {
    final expiredKeys = <String>[];
    for (final entry in _handledInteractions.entries) {
      if (now.difference(entry.value) > _handledInteractionWindow) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _handledInteractions.remove(key);
    }
  }

  void _trimHandledInteractionsToLimit() {
    while (_handledInteractions.length > _maxHandledInteractions) {
      _handledInteractions.remove(_handledInteractions.keys.first);
    }
  }

  static String? _safeExternalDedupeKey(Object? raw) {
    if (raw is! String) {
      return null;
    }

    final value = raw.trim();
    if (value.isEmpty || _routeControlCharacters.hasMatch(value)) {
      return null;
    }

    if (value.length <= _maxExternalDedupeKeyLength) {
      return value;
    }

    return _fingerprintString(value);
  }

  static String _fingerprintNotificationData(Map<String, dynamic> payload) {
    final sanitized = <String, String>{};
    final keys = payload.keys.map((key) => key.toString()).toList()..sort();
    for (final key in keys) {
      sanitized[key] = payload[key].toString();
    }

    return _fingerprintString(jsonEncode(sanitized));
  }

  static String _fingerprintString(String value) {
    return 'sha256:${sha256.convert(utf8.encode(value))}';
  }

  String? _routeFromMap(Map<String, dynamic> payload) {
    final route = payload['route'];
    if (route is String) {
      final safeRoute = _safeInternalRoute(route);
      if (safeRoute != null) {
        return safeRoute;
      }
    }

    final generationId = payload['generationId'];
    final generationRoute = _generationRoute(generationId);
    if (generationRoute != null) {
      return generationRoute;
    }

    final type = payload['type'];
    if (type == 'support_chat') {
      return '/profile/support';
    }

    if (type == 'wallet') {
      return '/profile/wallet';
    }

    if (type == 'premium') {
      return '/profile';
    }

    final conversationId = payload['conversationId'];
    if (conversationId is String && conversationId.isNotEmpty) {
      return '/profile/support';
    }

    return null;
  }

  String? _safeInternalRoute(String raw) {
    final value = raw.trim();
    if (value.isEmpty ||
        value.length > 160 ||
        _routeControlCharacters.hasMatch(value) ||
        !value.startsWith('/') ||
        value.startsWith('//') ||
        value.contains(r'\')) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.fragment.isNotEmpty ||
        uri.query.isNotEmpty) {
      return null;
    }

    final path = uri.path;
    if (_allowedNotificationRoutes.contains(path)) {
      return path;
    }

    if (path.startsWith('/generations/')) {
      final generationId = path.substring('/generations/'.length);
      if (_safeGenerationId.hasMatch(generationId)) {
        return path;
      }
    }

    return null;
  }

  String? _generationRoute(Object? rawGenerationId) {
    if (rawGenerationId is! String) {
      return null;
    }

    final generationId = rawGenerationId.trim();
    if (!_safeGenerationId.hasMatch(generationId)) {
      return null;
    }

    return '/generations/$generationId';
  }

  bool _shouldDisplayForeground(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == 'support_chat') {
      return true;
    }

    if (type == 'template_generation') {
      final status = (message.data['status'] as String?)?.toLowerCase();
      return status == 'completed' || status == 'failed';
    }

    if (type == 'wallet') {
      final status = (message.data['status'] as String?)?.toLowerCase();
      return status == 'succeeded' ||
          status == 'success' ||
          status == 'completed' ||
          status == 'pending' ||
          status == 'failed' ||
          status == 'error';
    }

    if (type == 'premium') {
      final status = (message.data['status'] as String?)?.toLowerCase();
      return status == 'active' ||
          status == 'inactive' ||
          status == 'expired' ||
          status == 'failed' ||
          status == 'error';
    }

    return false;
  }

  PetMagicToastTone _foregroundMessageTone(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == 'support_chat') {
      return PetMagicToastTone.info;
    }

    final status = (message.data['status'] as String?)?.toLowerCase();
    if (type == 'premium' && status == 'active') {
      return PetMagicToastTone.success;
    }
    if (status == 'succeeded' || status == 'success' || status == 'completed') {
      return PetMagicToastTone.success;
    }
    if (status == 'failed' || status == 'error') {
      return PetMagicToastTone.warning;
    }

    return PetMagicToastTone.info;
  }

  String _fallbackTitle(String? type) {
    return NotificationForegroundCopy.titleForType(
      PlatformDispatcher.instance.locale,
      type,
    );
  }

  String _fallbackBody(String? type) {
    return NotificationForegroundCopy.bodyForType(
      PlatformDispatcher.instance.locale,
      type,
    );
  }

  String _openActionLabel() {
    return NotificationForegroundCopy.openActionForLocale(
      PlatformDispatcher.instance.locale,
    );
  }

  void _logNotificationFailure(
    String stage,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) {
    final payload = <String, Object>{'stage': stage};
    for (final entry in context.entries) {
      final value = entry.value;
      if (value != null) {
        payload[entry.key] = value.toString();
      }
    }

    AppLogger.error(
      feature: 'Notifications',
      operation: stage,
      message: 'Notification coordinator operation failed',
      error: error,
      stackTrace: stackTrace,
      context: payload,
    );
  }
}
