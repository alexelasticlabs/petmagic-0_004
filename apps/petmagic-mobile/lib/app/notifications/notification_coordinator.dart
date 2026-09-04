import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:petmagic_mobile/core/notifications/authenticated_notification_initialization_runner.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/firebase/firebase_app_initializer.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/notifications/notification_foreground_copy.dart';
import 'package:petmagic_mobile/core/notifications/firebase_messaging_token_reader.dart';
import 'package:petmagic_mobile/core/notifications/notification_route_resolver.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registration_retry_scheduler.dart';
import 'package:petmagic_mobile/app/notifications/push_token_registrar.dart';
import 'package:petmagic_mobile/features/support/application/support_contract.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_contract.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

part 'notification_interaction_coordinator.part.dart';
part 'notification_firebase_readiness.part.dart';
part 'notification_authenticated_initialization.part.dart';

abstract class _NotificationCoordinatorBase {
  _NotificationCoordinatorBase({
    required GenerationRepository templateRepository,
    required SupportRepository supportRepository,
    required WalletRepositoryPort walletRepository,
    required AuthSessionStore sessionStorage,
    required void Function(String route) onRouteRequested,
    FirebaseAppInitializer? appInitializer,
    FirebaseMessagingTokenReader? tokenReader,
  }) : _pushTokenRegistrar = PushTokenRegistrar(
         templateRepository: templateRepository,
         supportRepository: supportRepository,
         walletRepository: walletRepository,
         sessionStorage: sessionStorage,
       ),
       _appInitializer = appInitializer ?? firebaseAppInitializer,
       _tokenReader = tokenReader ?? firebaseMessagingTokenReader,
       _onRouteRequested = onRouteRequested;

  final PushTokenRegistrar _pushTokenRegistrar;
  final FirebaseAppInitializer _appInitializer;
  final FirebaseMessagingTokenReader _tokenReader;
  final void Function(String route) _onRouteRequested;
  final AuthenticatedNotificationInitializationRunner _initializationRunner =
      AuthenticatedNotificationInitializationRunner();
  late final PushTokenRegistrationRetryScheduler
  _tokenRegistrationRetryScheduler;
  final NotificationRouteResolver _routeResolver =
      const NotificationRouteResolver();
  static final RegExp _routeControlCharacters = RegExp(r'[\x00-\x1F\x7F]');
  static const Duration _handledInteractionWindow = Duration(minutes: 5);
  static const List<Duration> _firebaseInitializationRetryDelays = [
    Duration(milliseconds: 250),
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
  ];
  static const int _maxHandledInteractions = 128;
  static const int _maxExternalDedupeKeyLength = 160;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  Timer? _firebaseReadinessTimer;
  Completer<void>? _firebaseReadinessWaiter;
  final Map<String, DateTime> _handledInteractions = <String, DateTime>{};
  String? _lastRegisteredToken;
  bool _isDisposed = false;
  bool _initialMessageHandled = false;
  bool _initialized = false;
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
    super.appInitializer,
    super.tokenReader,
  }) {
    _tokenRegistrationRetryScheduler = PushTokenRegistrationRetryScheduler(
      canRetry: () => !_isDisposed && _authSessionActive && _firebaseReady,
      onFailure: (error, stackTrace) {
        _logNotificationFailure(
          'schedule_token_registration_retry',
          error,
          stackTrace,
        );
      },
    );
  }

  Future<void> initializeForAuthenticatedUser() async {
    if (_isDisposed || _authenticatedReady) {
      return;
    }

    if (!_authSessionActive) {
      _registrationEpoch++;
    }
    _authSessionActive = true;
    await _initializationRunner.activateAndRun(_initializeAuthenticatedSession);
  }

  Future<void> registerCurrentToken() async {
    if (_isDisposed || !_firebaseReady || !_authSessionActive) {
      return;
    }

    final epoch = _registrationEpoch;
    try {
      final permissionAllowed = await _notificationsAllowed();
      if (!_canContinueRegistration(epoch)) {
        return;
      }
      if (!permissionAllowed) {
        await _unregisterCurrentToken(markSessionInactive: false);
        return;
      }

      final token = await _tokenReader.readToken(
        canContinue: () => _canContinueRegistration(epoch),
      );
      if (token == null || token.isEmpty) {
        _scheduleCurrentTokenRegistrationRetry();
        return;
      }

      final previousToken = _lastRegisteredToken;
      final registered = await _registerTokenWithRetry(token, epoch: epoch);
      if (registered && _canContinueRegistration(epoch)) {
        _lastRegisteredToken = token;
        _tokenRegistrationRetryScheduler.reset();
        await _unregisterStaleToken(previousToken, replacementToken: token);
      } else {
        _scheduleCurrentTokenRegistrationRetry();
      }
    } catch (error, stackTrace) {
      _logNotificationFailure('register_current_token', error, stackTrace);
      _scheduleCurrentTokenRegistrationRetry();
    }
  }

  Future<void> unregisterCurrentTokenOnSignOut() async {
    await _unregisterCurrentToken(markSessionInactive: true);
  }

  Future<void> _unregisterCurrentToken({
    required bool markSessionInactive,
  }) async {
    _tokenRegistrationRetryScheduler.cancel();
    final epoch = ++_registrationEpoch;
    if (markSessionInactive) {
      _authSessionActive = false;
      _authenticatedReady = false;
      _initializationRunner.deactivate();
      _handledInteractions.clear();
      _cancelFirebaseReadinessWait();
    }

    final registeredToken =
        _lastRegisteredToken ?? await _pushTokenRegistrar.readRegisteredToken();
    final token =
        registeredToken ??
        (markSessionInactive
            ? null
            : await _readCurrentFirebaseToken(epoch: epoch));
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

  Future<String?> _readCurrentFirebaseToken({required int epoch}) async {
    if (!_firebaseReady) {
      return null;
    }

    return _tokenReader.readToken(
      canContinue: () => !_isDisposed && epoch == _registrationEpoch,
    );
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _authSessionActive = false;
    _registrationEpoch++;
    _initializationRunner.dispose();
    _cancelFirebaseReadinessWait();
    _tokenRegistrationRetryScheduler.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    _handledInteractions.clear();
  }

  bool get _firebaseReady => _appInitializer.isInitialized;

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
        _tokenRegistrationRetryScheduler.reset();
        await _unregisterStaleToken(previousToken, replacementToken: token);
      } else {
        _scheduleCurrentTokenRegistrationRetry();
      }
    } catch (error, stackTrace) {
      _logNotificationFailure('register_refreshed_token', error, stackTrace);
      _scheduleCurrentTokenRegistrationRetry();
    }
  }

  void _scheduleCurrentTokenRegistrationRetry() {
    _tokenRegistrationRetryScheduler.schedule(registerCurrentToken);
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
