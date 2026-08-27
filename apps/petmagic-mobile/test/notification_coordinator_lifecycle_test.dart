import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push token retry stops after sign-out or coordinator dispose', () {
    final source = _readNotificationCoordinatorSource();

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
      final source = _readNotificationCoordinatorSource();
      final initBody = _methodBody(source, 'initializeForAuthenticatedUser');
      final registerBody = _methodBody(source, 'registerCurrentToken');
      final unregisterBody = _methodBody(source, '_unregisterCurrentToken');
      final refreshedBody = _methodBody(source, '_registerRefreshedToken');
      final staleUnregisterBody = _methodBody(source, '_unregisterStaleToken');
      final ensureInitializedBody = _methodBody(source, '_ensureInitialized');
      final canContinueBody = _methodBody(source, '_canContinueRegistration');

      expect(source, contains('bool _authSessionActive = false;'));
      expect(initBody, contains('_authSessionActive = true;'));
      expect(registerBody, contains('|| !_authSessionActive'));
      expect(
        registerBody,
        contains('final previousToken = _lastRegisteredToken;'),
      );
      final registerAttemptIndex = registerBody.indexOf(
        'final registered = await _registerTokenWithRetry',
      );
      expect(registerAttemptIndex, isNonNegative);
      expect(
        registerBody.substring(0, registerAttemptIndex),
        isNot(contains('_lastRegisteredToken = token;')),
      );
      expect(
        registerBody.indexOf(
          '_lastRegisteredToken = token;',
          registerAttemptIndex,
        ),
        greaterThan(registerAttemptIndex),
      );
      expect(
        registerBody,
        contains('await _unregisterStaleToken(previousToken'),
      );
      expect(unregisterBody, contains('_authSessionActive = false;'));
      expect(unregisterBody, contains('_handledInteractions.clear();'));
      expect(unregisterBody, contains('_lastRegisteredToken = null;'));
      expect(refreshedBody, contains('!_authSessionActive'));
      expect(source, contains('required String? previousToken'));
      expect(
        ensureInitializedBody,
        isNot(contains('_lastRegisteredToken = token;')),
      );
      expect(refreshedBody, contains('_lastRegisteredToken = token;'));
      expect(
        refreshedBody,
        contains('await _unregisterStaleToken(previousToken'),
      );
      expect(staleUnregisterBody, contains('clearRegistrationState: false'));
      expect(staleUnregisterBody, contains("unregister_stale_\${stage}_token"));
      expect(ensureInitializedBody, contains('if (!_authSessionActive) {'));
      expect(canContinueBody, contains('_authSessionActive'));
    },
  );

  test('notification failure logs do not include push token context', () {
    final source = _readNotificationCoordinatorSource();
    final body = _methodBody(source, '_logNotificationFailure');

    expect(body, contains('AppLogger.error'));
    expect(body, contains("'stage': stage"));
    expect(body, isNot(contains("'token'")));
    expect(body, isNot(contains('token:')));
    expect(body, isNot(contains('message.data')));
  });

  test('notification routes are constrained to safe internal destinations', () {
    final source = File(
      'lib/core/notifications/notification_route_resolver.dart',
    ).readAsStringSync();
    final routeBody = _methodBody(source, 'routeFromMap');
    final safeRouteBody = _methodBody(source, 'safeInternalRoute');
    final generationRouteBody = _methodBody(source, 'generationRouteFor');

    expect(routeBody, isNot(contains('return route;')));
    expect(routeBody, contains('safeInternalRoute(route)'));
    expect(routeBody, contains("generationRouteFor(payload['generationId'])"));
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
      final coordinatorSource = _readNotificationCoordinatorSource();
      final settingsSource = _readProfileNotificationsSettingsSource();

      expect(
        coordinatorSource,
        contains('_ensureNotificationPermissionAllowed'),
      );
      expect(coordinatorSource, contains('requestPermission('));
      expect(coordinatorSource, contains('getNotificationSettings()'));
      expect(coordinatorSource, contains('_notificationsAllowed()'));
      expect(
        coordinatorSource,
        contains('AuthorizationStatus.denied &&\n        !Platform.isAndroid'),
      );
      expect(settingsSource, contains('requestPermission('));
    },
  );

  test('foreground push notifications can route from their toast action', () {
    final source = _readNotificationCoordinatorSource();
    final foregroundBody = _methodBody(source, 'handleForegroundMessage');

    expect(
      foregroundBody,
      contains('final route = _routeFromMap(message.data);'),
    );
    expect(foregroundBody, contains('final title = _fallbackTitle(type);'));
    expect(
      foregroundBody,
      contains('final messageText = _fallbackBody(type);'),
    );
    expect(foregroundBody, isNot(contains('message.notification?.title')));
    expect(foregroundBody, isNot(contains('message.notification?.body')));
    expect(foregroundBody, contains('PetMagicNotificationAction('));
    expect(foregroundBody, contains('label: _openActionLabel()'));
    expect(
      foregroundBody,
      contains('onPressed: () => _onRouteRequested(route)'),
    );
  });

  test('foreground push coverage matches backend economy statuses', () {
    final source = _readNotificationCoordinatorSource();
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
    final source = _readNotificationCoordinatorSource();
    final routeBody = _methodBody(source, '_handleRemoteMessageRoute');
    final dedupeBody = _methodBody(source, '_markInteractionHandled');

    expect(source, contains('_handledInteractions'));
    expect(source, contains('_handledInteractionWindow'));
    expect(source, contains('_maxHandledInteractions'));
    expect(source, contains('_maxExternalDedupeKeyLength'));
    expect(routeBody, contains('if (!_markInteractionHandled(message))'));
    expect(dedupeBody, contains('final key = _interactionDedupeKey(message);'));
    expect(dedupeBody, contains('_handledInteractions[key]'));
    expect(dedupeBody, contains('_trimHandledInteractionsToLimit();'));
    expect(
      source,
      contains("_safeExternalDedupeKey(message.data['dedupe_key'])"),
    );
    expect(source, contains('_fingerprintNotificationData(message.data)'));
    expect(source, contains('sha256.convert'));
    expect(source, isNot(contains('message.data.toString()')));
  });

  test('push bootstrap keeps lifecycle side effects out of build', () {
    final source = [
      'lib/app/notifications/push_notifications_bootstrap.dart',
      'lib/app/notifications/push_notification_route_policy.part.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final initStateBody = _methodBody(source, 'initState');
    final disposeBody = _methodBody(source, 'dispose');
    final launchStateBody = _methodBody(source, '_handleLaunchState');
    final routeBody = _methodBody(source, '_openRoute');
    final deepLinkBody = _methodBody(source, '_openDeepLink');
    final initialLinkBody = _methodBody(source, '_handleInitialLinkOnce');
    final flushPendingBody = _methodBody(source, '_flushPendingRouteIfReady');
    final queueCheckoutBody = _methodBody(source, '_queueCheckoutVerification');
    final normalizeCheckoutBody = _methodBody(
      source,
      '_normalizeStripeCheckoutSessionId',
    );
    final clearCheckoutBody = _methodBody(
      source,
      '_clearPendingCheckoutVerification',
    );
    final flushCheckoutBody = _methodBody(
      source,
      '_flushPendingCheckoutVerificationIfReady',
    );
    final resolvedRouteBody = _methodBody(source, '_resolvedRouteDestination');
    final buildBody = _methodBody(source, 'build');

    expect(initStateBody, contains('ref.listenManual<AppLaunchState>'));
    expect(initStateBody, contains('_appLinks.uriLinkStream.listen'));
    expect(initStateBody, contains('Future.microtask(_handleInitialLinkOnce)'));
    expect(disposeBody, contains('final coordinator = _coordinator;'));
    expect(disposeBody, contains('_coordinator = null;'));
    expect(launchStateBody, contains('if (!mounted)'));
    expect(launchStateBody, contains('_flushPendingRouteIfReady(launchState)'));
    expect(source, contains('bool _wasPushEligible = false;'));
    expect(
      launchStateBody,
      contains(
        'launchState.isAuthenticated && !launchState.requiresLegalAcceptance',
      ),
    );
    expect(launchStateBody, contains('isPushEligible && !_wasPushEligible'));
    expect(launchStateBody, contains('_wasPushEligible = true;'));
    expect(launchStateBody, contains('_wasPushEligible = false;'));
    expect(
      launchStateBody,
      contains('_flushPendingCheckoutVerificationIfReady(launchState)'),
    );
    expect(launchStateBody, contains('_clearPendingCheckoutVerification();'));
    expect(routeBody, contains('if (!mounted)'));
    expect(routeBody, contains('if (!_isSupportedRoute(route))'));
    expect(
      routeBody,
      contains('final destination = _resolvedRouteDestination'),
    );
    expect(routeBody, contains('_pendingRoute = _destinationForRoute(route)'));
    expect(deepLinkBody, contains('if (!mounted)'));
    expect(
      deepLinkBody,
      contains('AppConfig.isExpectedDeepLinkScheme(uri.scheme)'),
    );
    expect(initialLinkBody, contains('if (!mounted)'));
    expect(deepLinkBody, contains('_openRoute('));
    expect(
      deepLinkBody,
      contains('_queueCheckoutVerification(sessionId: sessionId);'),
    );
    expect(deepLinkBody, contains('_queueCheckoutVerification();'));
    expect(
      deepLinkBody,
      contains('_openRoute(SubscriptionManagementPage.routePath);'),
    );
    expect(source, contains('_isSubscriptionManagementRoute(route)'));
    expect(initialLinkBody, isNot(contains('Firebase.apps')));
    expect(
      flushPendingBody,
      contains('final resolvedDestination = _resolvedRouteDestination'),
    );
    expect(
      flushPendingBody,
      contains('widget.navigator.go(resolvedDestination)'),
    );
    expect(
      queueCheckoutBody,
      contains('_pendingCheckoutVerificationRequested = true;'),
    );
    expect(
      queueCheckoutBody,
      contains(
        '_pendingCheckoutSessionId = _normalizeStripeCheckoutSessionId(sessionId);',
      ),
    );
    expect(
      queueCheckoutBody,
      contains('_flushPendingCheckoutVerificationIfReady('),
    );
    expect(source, contains('_stripeCheckoutSessionIdPattern'));
    expect(
      normalizeCheckoutBody,
      contains(
        '!_stripeCheckoutSessionIdPattern.hasMatch(normalizedSessionId)',
      ),
    );
    expect(normalizeCheckoutBody, contains('return null;'));
    expect(clearCheckoutBody, contains('_pendingCheckoutSessionId = null;'));
    expect(
      clearCheckoutBody,
      contains('_pendingCheckoutVerificationRequested = false;'),
    );
    expect(flushCheckoutBody, contains('launchState.isLoading'));
    expect(flushCheckoutBody, contains('!launchState.isAuthenticated'));
    expect(flushCheckoutBody, contains('launchState.requiresLegalAcceptance'));
    expect(flushCheckoutBody, contains('verifyStripeCheckout(sessionId)'));
    expect(flushCheckoutBody, contains('verifyCheckoutStatus()'));
    expect(resolvedRouteBody, contains('launchState.isLoading'));
    expect(resolvedRouteBody, contains('launchState.isAuthenticated'));
    expect(resolvedRouteBody, contains('launchState.guestSessionReady'));
    expect(resolvedRouteBody, contains('_isAuthOnlyRoute(route)'));
    expect(resolvedRouteBody, contains('_authRedirectRoute(route)'));
    expect(source, contains('AuthDestination'));
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
      final source = _readProfileNotificationsSettingsSource();
      final reconcileBody = _methodBody(
        source,
        '_reconcilePushTokenRegistration',
      );

      expect(source, contains('await _reconcilePushTokenRegistration('));
      expect(reconcileBody, contains('if (_isPushPermissionAllowed(status))'));
      expect(reconcileBody, contains('_registerPushTokenIfAllowed(status)'));
      expect(
        reconcileBody,
        contains('_pushTokenLifecycle.readRegisteredToken()'),
      );
      expect(reconcileBody, contains('final cachedToken ='));
      expect(
        reconcileBody.indexOf('if (!mounted)'),
        greaterThan(reconcileBody.indexOf('readRegisteredToken()')),
      );
      expect(
        reconcileBody,
        contains('_pushTokenLifecycle.readCurrentDeviceToken()'),
      );
      expect(
        reconcileBody.indexOf('_pushTokenLifecycle.readCurrentDeviceToken()'),
        greaterThan(reconcileBody.indexOf('if (!mounted)')),
      );
      expect(reconcileBody, contains('_pushTokenLifecycle.unregisterToken('));
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
      final registrarSource = [
        'lib/app/notifications/push_token_registrar.dart',
        'lib/app/notifications/push_token_registrar_policy.part.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');
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
        contains('_registrationCache.writeLastCompletedRegistrationKey('),
      );
      expect(
        registrarSource,
        contains(
          '_registrationCache.writeLastCompletedRegistrationToken(token)',
        ),
      );
      expect(
        registrarSource,
        contains('_registrationCache.readLastCompletedRegistrationToken()'),
      );
      expect(registrarSource, contains('sha256.convert'));
      expect(cacheSource, contains('pushTokenRegistrationFingerprintPrefix'));
      expect(cacheSource, contains('FlutterSecureStorage'));
      expect(
        cacheSource,
        contains('petmagic_mobile_push_token_last_registration_token_v1'),
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
        isNot(contains('clearLastCompletedRegistrationKeyForToken')),
      );
      expect(cacheSource, contains('!value.startsWith'));
    },
  );
}

String _readNotificationCoordinatorSource() {
  return [
    'lib/app/notifications/notification_coordinator.dart',
    'lib/app/notifications/notification_interaction_coordinator.part.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:void|bool|String\??|AppDestination\??|Widget|Future<[^>]+>)\s+' +
        methodName +
        r'\s*\(',
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

String _readProfileNotificationsSettingsSource() {
  return [
    'lib/features/profile/presentation/widgets/profile_notifications_settings_section.dart',
    'lib/features/profile/presentation/widgets/profile_notifications_settings_view.part.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}
