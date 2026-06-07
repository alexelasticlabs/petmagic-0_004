import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

class NotificationCoordinator {
  NotificationCoordinator({
    required TemplateGenerationRepository templateRepository,
    required SupportChatRepository supportRepository,
    required WalletRepository walletRepository,
    required void Function(String route) onRouteRequested,
  }) : _templateRepository = templateRepository,
       _supportRepository = supportRepository,
       _walletRepository = walletRepository,
       _onRouteRequested = onRouteRequested;

  final TemplateGenerationRepository _templateRepository;
  final SupportChatRepository _supportRepository;
  final WalletRepository _walletRepository;
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

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _lastRegisteredToken;
  bool _isDisposed = false;
  bool _initialMessageHandled = false;
  bool _initialized = false;
  bool _initializing = false;
  bool _authenticatedReady = false;
  int _registrationEpoch = 0;

  Future<void> initializeForAuthenticatedUser() async {
    if (_isDisposed ||
        _authenticatedReady ||
        _initializing ||
        !_firebaseReady) {
      return;
    }

    _initializing = true;
    try {
      await _ensureInitialized();
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
    if (_isDisposed || !_firebaseReady) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      final epoch = _registrationEpoch;
      _lastRegisteredToken = token;
      final registered = await _registerTokenWithRetry(token, epoch: epoch);
      if (registered && _canContinueRegistration(epoch)) {
        _lastRegisteredToken = token;
      }
    } catch (error, stackTrace) {
      _logNotificationFailure('register_current_token', error, stackTrace);
    }
  }

  Future<void> unregisterCurrentTokenOnSignOut() async {
    _registrationEpoch++;
    final token = _lastRegisteredToken;
    _authenticatedReady = false;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _templateRepository.unregisterPushToken(token);
    } catch (error, stackTrace) {
      _logNotificationFailure('unregister_template_token', error, stackTrace);
    }
    try {
      await _supportRepository.unregisterPushToken(token);
    } catch (error, stackTrace) {
      _logNotificationFailure('unregister_support_token', error, stackTrace);
    }
    try {
      await _walletRepository.unregisterPushToken(token);
    } catch (error, stackTrace) {
      _logNotificationFailure('unregister_economy_token', error, stackTrace);
    }
    _lastRegisteredToken = null;
  }

  void handleForegroundMessage(RemoteMessage message) {
    if (_isDisposed || !_shouldDisplayForeground(message)) {
      return;
    }

    final type = message.data['type'] as String?;
    final rawTitle = message.notification?.title?.trim();
    final rawBody = message.notification?.body?.trim();

    final title = rawTitle == null || rawTitle.isEmpty ? null : rawTitle;
    final body = rawBody == null || rawBody.isEmpty
        ? _fallbackBody(type)
        : rawBody;
    final messageText = body.isEmpty ? (title ?? _fallbackTitle(type)) : body;
    final dedupeKey =
        message.data['dedupe_key'] as String? ??
        message.data['dedupeKey'] as String? ??
        message.messageId ??
        '${type ?? 'update'}:${messageText.hashCode}:${title ?? ''}';

    PetMagicToast.show(
      null,
      title: title,
      message: messageText,
      tone: _foregroundMessageTone(message),
      dedupeKey: dedupeKey,
    );
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _registrationEpoch++;
    await _tokenRefreshSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
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
      final epoch = _registrationEpoch;
      _lastRegisteredToken = token;
      unawaited(_registerTokenWithRetry(token, epoch: epoch));
    });

    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleRemoteMessageRoute,
    );
    _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      handleForegroundMessage,
    );
    _initialized = true;
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
        await _templateRepository.registerPushToken(
          token: token,
          platform: Platform.operatingSystem,
          locale: Platform.localeName,
        );
        if (!_canContinueRegistration(epoch)) {
          return false;
        }
        await _supportRepository.registerPushToken(
          token: token,
          platform: Platform.operatingSystem,
          locale: Platform.localeName,
        );
        if (!_canContinueRegistration(epoch)) {
          return false;
        }
        await _walletRepository.registerPushToken(
          token: token,
          platform: Platform.operatingSystem,
          locale: Platform.localeName,
        );
        return _canContinueRegistration(epoch);
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

  bool _canContinueRegistration(int epoch) {
    return !_isDisposed && epoch == _registrationEpoch;
  }

  void _handleRemoteMessageRoute(RemoteMessage message) {
    final route = _routeFromMap(message.data);
    if (route != null) {
      _onRouteRequested(route);
    }
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
          status == 'succeeded' ||
          status == 'success' ||
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
    if (status == 'succeeded' || status == 'success' || status == 'completed') {
      return PetMagicToastTone.success;
    }
    if (status == 'failed' || status == 'error') {
      return PetMagicToastTone.warning;
    }

    return PetMagicToastTone.info;
  }

  String _fallbackTitle(String? type) {
    if (type == 'support_chat') {
      return 'PetMagic Support replied';
    }
    if (type == 'template_generation') {
      return 'PetMagic generation update';
    }
    if (type == 'wallet') {
      return 'PetMagic wallet update';
    }
    if (type == 'premium') {
      return 'PetMagic premium update';
    }
    return 'PetMagic update';
  }

  String _fallbackBody(String? type) {
    if (type == 'support_chat') {
      return 'Open support chat to see the latest response.';
    }
    if (type == 'template_generation') {
      return 'Your generation status has changed.';
    }
    if (type == 'wallet') {
      return 'Open your wallet to review the latest balance update.';
    }
    return '';
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
