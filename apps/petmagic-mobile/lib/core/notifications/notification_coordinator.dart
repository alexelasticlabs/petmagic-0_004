import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';

class NotificationCoordinator {
  NotificationCoordinator({
    required TemplateGenerationRepository templateRepository,
    required SupportChatRepository supportRepository,
    required void Function(String route) onRouteRequested,
  }) : _templateRepository = templateRepository,
       _supportRepository = supportRepository,
       _onRouteRequested = onRouteRequested;

  static const _androidChannelId = 'petmagic_updates';
  static const _androidChannelName = 'PetMagic Updates';
  static const _androidChannelDescription =
      'Support and generation status updates';

  final TemplateGenerationRepository _templateRepository;
  final SupportChatRepository _supportRepository;
  final void Function(String route) _onRouteRequested;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _lastRegisteredToken;
  bool _isDisposed = false;
  bool _initialMessageHandled = false;
  bool _initialized = false;
  bool _initializing = false;
  bool _authenticatedReady = false;

  Future<void> initializeForAuthenticatedUser() async {
    if (_isDisposed || _authenticatedReady || _initializing || !_firebaseReady) {
      return;
    }

    _initializing = true;
    try {
      await _ensureInitialized();
      await registerCurrentToken();

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
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

      await _registerTokenWithRetry(token);
      _lastRegisteredToken = token;
    } catch (_) {}
  }

  Future<void> unregisterCurrentTokenOnSignOut() async {
    final token = _lastRegisteredToken;
    _authenticatedReady = false;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _templateRepository.unregisterPushToken(token);
    } catch (_) {}
    try {
      await _supportRepository.unregisterPushToken(token);
    } catch (_) {}
    _lastRegisteredToken = null;
  }

  Future<void> handleForegroundMessage(RemoteMessage message) async {
    if (_isDisposed || !_shouldDisplayForeground(message)) {
      return;
    }

    final title =
        message.notification?.title ??
        _fallbackTitle(message.data['type'] as String?);
    final body =
        message.notification?.body ??
        _fallbackBody(message.data['type'] as String?);
    if (title.isEmpty && body.isEmpty) {
      return;
    }

    final payload = _payloadForRoute(message);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _localNotifications.show(
      DateTime.now().microsecondsSinceEpoch % 2147483647,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> dispose() async {
    _isDisposed = true;
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
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _initializeLocalNotifications();

    _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen((token) {
      if (token.isEmpty) {
        return;
      }
      unawaited(_registerTokenWithRetry(token));
      _lastRegisteredToken = token;
    });

    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleRemoteMessageRoute,
    );
    _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      (message) => unawaited(handleForegroundMessage(message)),
    );
    _initialized = true;
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null || response.payload!.isEmpty) {
          return;
        }
        _openRouteFromPayload(response.payload!);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _androidChannelId,
            _androidChannelName,
            description: _androidChannelDescription,
            importance: Importance.high,
          ),
        );
  }

  Future<void> _registerTokenWithRetry(String token) async {
    const maxAttempts = 4;
    const backoffs = [400, 900, 1800, 3600];

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await _templateRepository.registerPushToken(
          token: token,
          platform: Platform.operatingSystem,
          locale: Platform.localeName,
        );
        await _supportRepository.registerPushToken(
          token: token,
          platform: Platform.operatingSystem,
          locale: Platform.localeName,
        );
        return;
      } catch (_) {
        if (attempt == maxAttempts - 1) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: backoffs[attempt]));
      }
    }
  }

  void _handleRemoteMessageRoute(RemoteMessage message) {
    final route = _routeFromMap(message.data);
    if (route != null) {
      _onRouteRequested(route);
    }
  }

  String? _routeFromMap(Map<String, dynamic> payload) {
    final route = payload['route'];
    if (route is String && route.isNotEmpty) {
      return route;
    }

    final generationId = payload['generationId'];
    if (generationId is String && generationId.isNotEmpty) {
      return '/generations/$generationId';
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

  bool _shouldDisplayForeground(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type == 'support_chat') {
      return true;
    }

    if (type == 'template_generation') {
      final status = (message.data['status'] as String?)?.toLowerCase();
      return status == 'completed' || status == 'failed';
    }

    return false;
  }

  String _fallbackTitle(String? type) {
    if (type == 'support_chat') {
      return 'PetMagic Support replied';
    }
    if (type == 'template_generation') {
      return 'PetMagic generation update';
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
    return '';
  }

  String _payloadForRoute(RemoteMessage message) {
    final route = _routeFromMap(message.data);
    if (route == null) {
      return '';
    }
    return jsonEncode({'route': route});
  }

  void _openRouteFromPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final route = decoded['route'];
      if (route is String && route.isNotEmpty) {
        _onRouteRequested(route);
      }
    } catch (_) {}
  }
}
