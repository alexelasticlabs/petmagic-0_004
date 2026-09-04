part of 'notification_coordinator.dart';

extension _NotificationAuthenticatedInitialization on NotificationCoordinator {
  Future<void> _initializeAuthenticatedSession(int sessionEpoch) async {
    var failureAttempt = 0;
    while (_canContinueInitialization(sessionEpoch) && !_authenticatedReady) {
      try {
        if (!await _waitForFirebaseReady(sessionEpoch)) {
          return;
        }

        await _ensureInitialized();
        if (!_canContinueInitialization(sessionEpoch)) {
          return;
        }

        final permissionAllowed = await _ensureNotificationPermissionAllowed();
        if (!_canContinueInitialization(sessionEpoch)) {
          return;
        }
        if (!permissionAllowed) {
          await _unregisterCurrentToken(markSessionInactive: false);
          if (_canContinueInitialization(sessionEpoch)) {
            _authenticatedReady = true;
          }
          return;
        }

        await registerCurrentToken();
        if (!_canContinueInitialization(sessionEpoch)) {
          return;
        }

        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (!_canContinueInitialization(sessionEpoch)) {
          return;
        }
        if (!_initialMessageHandled && initialMessage != null) {
          _initialMessageHandled = true;
          _handleRemoteMessageRoute(initialMessage);
        } else {
          _initialMessageHandled = true;
        }

        _authenticatedReady = true;
        return;
      } catch (error, stackTrace) {
        failureAttempt++;
        _logNotificationFailure(
          'authenticated_notification_initialize_retry',
          error,
          stackTrace,
          context: {'attempt': failureAttempt},
        );
        if (!await _waitForNotificationInitializationRetry(
          sessionEpoch,
          failureAttempt - 1,
        )) {
          return;
        }
      }
    }
  }
}
