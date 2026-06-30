import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push token retry stops after sign-out or coordinator dispose', () {
    final source = File(
      'lib/core/notifications/notification_coordinator.dart',
    ).readAsStringSync();

    expect(source, contains('int _registrationEpoch = 0;'));
    expect(source, contains('Future<bool> _registerTokenWithRetry('));
    expect(source, contains('required int epoch,'));
    expect(source, contains('PushTokenRegistrar'));
    expect(source, contains('_pushTokenRegistrar.registerToken'));
    expect(source, contains('bool _canContinueRegistration(int epoch)'));
    expect(
      source,
      contains(
        'return !_isDisposed && _authSessionActive && epoch == _registrationEpoch;',
      ),
    );
    expect(source, contains('if (!_canContinueRegistration(epoch))'));
    expect(source, contains('unregisterCurrentTokenOnSignOut() async {'));
    expect(
      source,
      contains('await _unregisterCurrentToken(markSessionInactive: true);'),
    );
    expect(source, contains('Future<void> _unregisterCurrentToken({'));
    expect(source, contains('final epoch = ++_registrationEpoch;'));
    expect(
      source,
      contains(
        'dispose() async {\n    _isDisposed = true;\n    _authSessionActive = false;\n    _registrationEpoch++;',
      ),
    );
    expect(source, contains('_pushTokenRegistrar.readRegisteredToken()'));
    expect(source, contains('_pushTokenRegistrar.unregisterToken('));
    expect(source, contains("onFailure: (stage, error, stackTrace) {"));
    expect(source, contains('if (allUnregistered) {'));
    expect(source, contains("unregister_\${stage}_token"));
  });

  test(
    'notification coordinator stops token re-registration and clears dedupe state after sign-out',
    () {
      final source = File(
        'lib/core/notifications/notification_coordinator.dart',
      ).readAsStringSync();
      final initBody = _methodBody(source, 'initializeForAuthenticatedUser');
      final registerBody = _methodBody(source, 'registerCurrentToken');
      final unregisterBody = _methodBody(source, '_unregisterCurrentToken');
      final refreshedBody = _methodBody(source, '_registerRefreshedToken');
      final ensureInitializedBody = _methodBody(source, '_ensureInitialized');
      final canContinueBody = _methodBody(source, '_canContinueRegistration');

      expect(source, contains('bool _authSessionActive = false;'));
      expect(initBody, contains('_authSessionActive = true;'));
      expect(registerBody, contains('|| !_authSessionActive'));
      expect(unregisterBody, contains('_authSessionActive = false;'));
      expect(unregisterBody, contains('_handledInteractions.clear();'));
      expect(refreshedBody, contains('!_authSessionActive'));
      expect(ensureInitializedBody, contains('if (!_authSessionActive) {'));
      expect(canContinueBody, contains('_authSessionActive'));
    },
  );

  test('notification failure logs do not include push token context', () {
    final source = File(
      'lib/core/notifications/notification_coordinator.dart',
    ).readAsStringSync();
    final body = _methodBody(source, '_logNotificationFailure');

    expect(body, contains('AppLogger.error'));
    expect(body, contains("'stage': stage"));
    expect(body, isNot(contains("'token'")));
    expect(body, isNot(contains('token:')));
    expect(body, isNot(contains('message.data')));
  });

  test('notification routes are constrained to safe internal destinations', () {
    final source = File(
      'lib/core/notifications/notification_coordinator.dart',
    ).readAsStringSync();
    final routeBody = _methodBody(source, '_routeFromMap');
    final safeRouteBody = _methodBody(source, '_safeInternalRoute');
    final generationRouteBody = _methodBody(source, '_generationRoute');

    expect(routeBody, isNot(contains('return route;')));
    expect(routeBody, contains('_safeInternalRoute(route)'));
    expect(routeBody, contains('_generationRoute(generationId)'));
    expect(routeBody, contains("if (type == 'wallet')"));
    expect(routeBody, contains("return '/profile/wallet';"));
    expect(routeBody, contains("if (type == 'premium')"));
    expect(routeBody, contains("return '/profile';"));
    expect(source, contains('_allowedNotificationRoutes'));
    expect(source, contains("'/profile/support/chat'"));
    expect(source, contains("'/profile/wallet'"));
    expect(safeRouteBody, contains('value.startsWith(\'//\')'));
    expect(safeRouteBody, contains("value.contains(r'\\')"));
    expect(safeRouteBody, contains('uri.hasScheme'));
    expect(safeRouteBody, contains('uri.hasAuthority'));
    expect(safeRouteBody, contains('uri.query.isNotEmpty'));
    expect(safeRouteBody, contains('uri.fragment.isNotEmpty'));
    expect(generationRouteBody, contains('_safeGenerationId.hasMatch'));
  });

  test(
    'auth bootstrap requests notification permission before token register',
    () {
      final coordinatorSource = File(
        'lib/core/notifications/notification_coordinator.dart',
      ).readAsStringSync();
      final settingsSource = File(
        'lib/features/profile/presentation/widgets/profile_notifications_settings_section.dart',
      ).readAsStringSync();

      expect(
        coordinatorSource,
        contains('_ensureNotificationPermissionAllowed'),
      );
      expect(coordinatorSource, contains('requestPermission('));
      expect(coordinatorSource, contains('getNotificationSettings()'));
      expect(coordinatorSource, contains('_notificationsAllowed()'));
      expect(settingsSource, contains('requestPermission('));
    },
  );

  test('foreground push notifications can route from their toast action', () {
    final source = File(
      'lib/core/notifications/notification_coordinator.dart',
    ).readAsStringSync();
    final foregroundBody = _methodBody(source, 'handleForegroundMessage');

    expect(
      foregroundBody,
      contains('final route = _routeFromMap(message.data);'),
    );
    expect(foregroundBody, contains('PetMagicNotificationAction('));
    expect(foregroundBody, contains('label: _openActionLabel()'));
    expect(
      foregroundBody,
      contains('onPressed: () => _onRouteRequested(route)'),
    );
  });

  test('foreground push coverage matches backend economy statuses', () {
    final source = File(
      'lib/core/notifications/notification_coordinator.dart',
    ).readAsStringSync();
    final foregroundCopySource = File(
      'lib/core/notifications/notification_foreground_copy.dart',
    ).readAsStringSync();
    final displayBody = _methodBody(source, '_shouldDisplayForeground');
    final fallbackBody = _methodBody(source, '_fallbackBody');
    final actionLabelBody = _methodBody(source, '_openActionLabel');

    expect(displayBody, contains("type == 'wallet'"));
    expect(displayBody, contains("type == 'premium'"));
    expect(displayBody, contains("status == 'inactive'"));
    expect(displayBody, contains("status == 'expired'"));
    expect(fallbackBody, contains('NotificationForegroundCopy.bodyForType'));
    expect(
      actionLabelBody,
      contains('NotificationForegroundCopy.openActionForLocale'),
    );
    expect(source, isNot(contains("'ru' => 'Открыть'")));
    expect(source, isNot(contains('PetMagic Support replied')));
    expect(
      source,
      isNot(contains('Open support chat to see the latest response.')),
    );
    expect(
      foregroundCopySource,
      contains('lookupAppLocalizations(supportedLocale)'),
    );
    expect(foregroundCopySource, contains("const Locale('en')"));
    expect(
      foregroundCopySource,
      contains('AppLocalizations.supportedLocales.any'),
    );
    expect(foregroundCopySource, contains('notificationOpenAction'));
    expect(foregroundCopySource, contains('notificationSupportTitle'));
    expect(foregroundCopySource, contains('notificationWalletBody'));
    expect(foregroundCopySource, isNot(contains('Открыть')));
  });

  test('notification tap handling deduplicates repeated message opens', () {
    final source = File(
      'lib/core/notifications/notification_coordinator.dart',
    ).readAsStringSync();
    final routeBody = _methodBody(source, '_handleRemoteMessageRoute');
    final dedupeBody = _methodBody(source, '_markInteractionHandled');

    expect(source, contains('_handledInteractions'));
    expect(source, contains('_handledInteractionWindow'));
    expect(routeBody, contains('if (!_markInteractionHandled(message))'));
    expect(dedupeBody, contains("message.data['dedupe_key']"));
    expect(dedupeBody, contains('message.messageId'));
    expect(dedupeBody, contains('_handledInteractions[key]'));
  });

  test('push bootstrap keeps lifecycle side effects out of build', () {
    final source = File(
      'lib/core/notifications/push_notifications_bootstrap.dart',
    ).readAsStringSync();
    final initStateBody = _methodBody(source, 'initState');
    final disposeBody = _methodBody(source, 'dispose');
    final launchStateBody = _methodBody(source, '_handleLaunchState');
    final routeBody = _methodBody(source, '_openRoute');
    final deepLinkBody = _methodBody(source, '_openDeepLink');
    final initialLinkBody = _methodBody(source, '_handleInitialLinkOnce');
    final flushPendingBody = _methodBody(source, '_flushPendingRouteIfReady');
    final resolvedRouteBody = _methodBody(source, '_resolvedRouteDestination');
    final buildBody = _methodBody(source, 'build');

    expect(initStateBody, contains('ref.listenManual<AppLaunchState>'));
    expect(initStateBody, contains('_appLinks.uriLinkStream.listen'));
    expect(initStateBody, contains('Future.microtask(_handleInitialLinkOnce)'));
    expect(disposeBody, contains('final coordinator = _coordinator;'));
    expect(disposeBody, contains('_coordinator = null;'));
    expect(launchStateBody, contains('if (!mounted)'));
    expect(launchStateBody, contains('_flushPendingRouteIfReady(launchState)'));
    expect(routeBody, contains('if (!mounted)'));
    expect(routeBody, contains('if (!_isSupportedRoute(route))'));
    expect(
      routeBody,
      contains('final destination = _resolvedRouteDestination'),
    );
    expect(routeBody, contains('_pendingRoute = route'));
    expect(deepLinkBody, contains('if (!mounted)'));
    expect(deepLinkBody, contains('_openRoute('));
    expect(initialLinkBody, isNot(contains('Firebase.apps')));
    expect(
      flushPendingBody,
      contains('final destination = _resolvedRouteDestination'),
    );
    expect(flushPendingBody, contains('widget.router.go(destination)'));
    expect(resolvedRouteBody, contains('launchState.isLoading'));
    expect(resolvedRouteBody, contains('launchState.isAuthenticated'));
    expect(resolvedRouteBody, contains('launchState.guestSessionReady'));
    expect(resolvedRouteBody, contains('_isAuthOnlyRoute(route)'));
    expect(resolvedRouteBody, contains('_authRedirectRoute(route)'));
    expect(source, contains('AuthEntryPage.routePath'));
    expect(buildBody, contains('return widget.child;'));
    expect(
      buildBody,
      isNot(contains('ref.watch(appLaunchControllerProvider)')),
    );
    expect(buildBody, isNot(contains('Future.microtask')));
    expect(buildBody, isNot(contains('uriLinkStream.listen')));
    expect(buildBody, isNot(contains('initializeForAuthenticatedUser')));
    expect(buildBody, isNot(contains('unregisterCurrentTokenOnSignOut')));
  });

  test(
    'notification settings reconcile push token registration on permission changes',
    () {
      final source = File(
        'lib/features/profile/presentation/widgets/profile_notifications_settings_section.dart',
      ).readAsStringSync();
      final reconcileBody = _methodBody(
        source,
        '_reconcilePushTokenRegistration',
      );

      expect(source, contains('await _reconcilePushTokenRegistration('));
      expect(reconcileBody, contains('if (_isPushPermissionAllowed(status))'));
      expect(reconcileBody, contains('_registerPushTokenIfAllowed(status)'));
      expect(
        reconcileBody,
        contains('_pushTokenRegistrar.readRegisteredToken()'),
      );
      expect(reconcileBody, contains('FirebaseMessaging.instance.getToken()'));
      expect(reconcileBody, contains('_pushTokenRegistrar.unregisterToken('));
      expect(
        reconcileBody,
        contains("unregister_\${stage}_token_after_permission_change"),
      );
    },
  );

  test('firebase background message handler is registered before runApp', () {
    final source = File('lib/main.dart').readAsStringSync();
    final mainBody = _methodBody(source, 'main');

    expect(
      mainBody,
      contains('_registerFirebaseMessagingBackgroundHandler();'),
    );
    expect(
      mainBody.indexOf('_registerFirebaseMessagingBackgroundHandler();'),
      lessThan(mainBody.indexOf('runApp(')),
    );
    expect(source, contains('FirebaseMessaging.onBackgroundMessage'));
  });

  test(
    'push token registrar persists successful registrations for cross-launch dedupe',
    () {
      final registrarSource = File(
        'lib/core/notifications/push_token_registrar.dart',
      ).readAsStringSync();
      final cacheSource = File(
        'lib/core/notifications/push_token_registration_cache.dart',
      ).readAsStringSync();

      expect(
        registrarSource,
        contains('PushTokenRegistrationCache? registrationCache'),
      );
      expect(
        registrarSource,
        contains('SharedPreferencesPushTokenRegistrationCache()'),
      );
      expect(
        registrarSource,
        contains('await _readLastCompletedRegistrationKey()'),
      );
      expect(
        registrarSource,
        contains(
          'await _registrationCache.writeLastCompletedRegistrationKey(registrationKey)',
        ),
      );
      expect(
        registrarSource,
        contains('Future<String?> readRegisteredToken()'),
      );
      expect(
        registrarSource,
        contains('Future<void> invalidatePersistedToken(String token) async'),
      );
      expect(registrarSource, contains('Future<bool> unregisterToken({'));
      expect(
        registrarSource,
        contains(
          'static final Map<String, Future<bool>> _inFlightUnregistrations',
        ),
      );
      expect(
        cacheSource,
        contains('petmagic_mobile_push_token_last_registration_key_v1'),
      );
      expect(
        cacheSource,
        contains('clearLastCompletedRegistrationKeyForToken'),
      );
    },
  );
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:void|bool|String\??|Widget|Future<[^>]+>)\s+' + methodName + r'\s*\(',
  ).firstMatch(source);
  if (methodMatch == null) {
    fail('Method $methodName was not found.');
  }

  final openBraceIndex = _methodOpenBraceIndex(source, methodMatch);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }

    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('Method $methodName body did not close.');
}

int _methodOpenBraceIndex(String source, RegExpMatch methodMatch) {
  var parenDepth = 0;
  for (var index = methodMatch.end - 1; index < source.length; index++) {
    final char = source[index];
    if (char == '(') {
      parenDepth++;
      continue;
    }
    if (char == ')') {
      parenDepth--;
      continue;
    }
    if (char == '{' && parenDepth == 0) {
      return index;
    }
  }

  return -1;
}
