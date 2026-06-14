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
      contains('return !_isDisposed && epoch == _registrationEpoch;'),
    );
    expect(source, contains('if (!_canContinueRegistration(epoch))'));
    expect(
      source,
      contains(
        'unregisterCurrentTokenOnSignOut() async {\n    _registrationEpoch++;',
      ),
    );
    expect(
      source,
      contains(
        'dispose() async {\n    _isDisposed = true;\n    _registrationEpoch++;',
      ),
    );
    expect(source, contains('PushTokenRegistrar.invalidateToken(token)'));
  });

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
    final displayBody = _methodBody(source, '_shouldDisplayForeground');
    final fallbackBody = _methodBody(source, '_fallbackBody');
    final actionLabelBody = _methodBody(source, '_openActionLabel');

    expect(displayBody, contains("type == 'wallet'"));
    expect(displayBody, contains("type == 'premium'"));
    expect(displayBody, contains("status == 'canceled'"));
    expect(displayBody, contains("status == 'cancelled'"));
    expect(displayBody, contains("status == 'expired'"));
    expect(fallbackBody, contains("type == 'premium'"));
    expect(actionLabelBody, contains("'ru' => 'Открыть'"));
    expect(actionLabelBody, contains("_ => 'Open'"));
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
    final canOpenRouteBody = _methodBody(source, '_canOpenRouteNow');
    final buildBody = _methodBody(source, 'build');

    expect(initStateBody, contains('ref.listenManual<AppLaunchState>'));
    expect(initStateBody, contains('_appLinks.uriLinkStream.listen'));
    expect(initStateBody, contains('Future.microtask(_handleInitialLinkOnce)'));
    expect(disposeBody, contains('final coordinator = _coordinator;'));
    expect(disposeBody, contains('_coordinator = null;'));
    expect(launchStateBody, contains('if (!mounted)'));
    expect(launchStateBody, contains('_flushPendingRouteIfReady(launchState)'));
    expect(routeBody, contains('if (!mounted)'));
    expect(routeBody, contains('_pendingRoute = route'));
    expect(routeBody, contains('_canOpenRouteNow(launchState)'));
    expect(deepLinkBody, contains('if (!mounted)'));
    expect(deepLinkBody, contains('_openRoute('));
    expect(initialLinkBody, isNot(contains('Firebase.apps')));
    expect(flushPendingBody, contains('widget.router.go(route)'));
    expect(canOpenRouteBody, contains('launchState.isLoading'));
    expect(canOpenRouteBody, contains('launchState.isAuthenticated'));
    expect(canOpenRouteBody, contains('launchState.guestSessionReady'));
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
