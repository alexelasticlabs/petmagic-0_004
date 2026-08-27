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
import 'package:petmagic_mobile/core/notifications/notification_route_resolver.dart';
import 'package:petmagic_mobile/app/notifications/push_token_registrar.dart';
import 'package:petmagic_mobile/features/support/application/support_contract.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_contract.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

part 'notification_interaction_coordinator.part.dart';

abstract class _NotificationCoordinatorBase {
  _NotificationCoordinatorBase({
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
  final NotificationRouteResolver _routeResolver =
      const NotificationRouteResolver();
  static final RegExp _routeControlCharacters = RegExp(r'[\x00-\x1F\x7F]');
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
}

class NotificationCoordinator extends _NotificationCoordinatorBase
    with _NotificationInteractionCoordinator {
  NotificationCoordinator({
    required super.templateRepository,
    required super.supportRepository,
    required super.walletRepository,
    required super.sessionStorage,
    required super.onRouteRequested,
  });

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

    // On Android 13+, Firebase reports `denied` before the first runtime
    // prompt as well as after a denial. Let Android decide whether it can
    // display the prompt; iOS must not be prompted again after a denial.
    if (settings.authorizationStatus == AuthorizationStatus.denied &&
        !Platform.isAndroid) {
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
}
