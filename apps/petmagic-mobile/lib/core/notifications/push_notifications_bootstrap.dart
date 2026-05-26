import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

class PushNotificationsBootstrap extends ConsumerStatefulWidget {
  const PushNotificationsBootstrap({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<PushNotificationsBootstrap> createState() =>
      _PushNotificationsBootstrapState();
}

class _PushNotificationsBootstrapState
    extends ConsumerState<PushNotificationsBootstrap> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<Uri>? _deepLinkSubscription;
  bool _started = false;
  bool _startInFlight = false;
  bool _handledInitialMessage = false;

  @override
  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
    unawaited(_messageOpenedSubscription?.cancel());
    unawaited(_deepLinkSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final launchState = ref.watch(appLaunchControllerProvider);
    if (launchState.isAuthenticated && !_started && !_startInFlight) {
      Future.microtask(_start);
    }

    return widget.child;
  }

  Future<void> _start() async {
    if (_started || _startInFlight || Firebase.apps.isEmpty) {
      return;
    }

    _startInFlight = true;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }

      _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen(
        (token) => unawaited(_registerToken(token)),
      );
      _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp
          .listen((message) => _openMessageRoute(message));
      _deepLinkSubscription ??= _appLinks.uriLinkStream.listen(_openDeepLink);

      if (!_handledInitialMessage) {
        _handledInitialMessage = true;
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          _openMessageRoute(initialMessage);
        }

        final initialLink = await _appLinks.getInitialLink();
        if (initialLink != null) {
          _openDeepLink(initialLink);
        }
      }

      _started = true;
    } catch (_) {
      _started = false;
    } finally {
      _startInFlight = false;
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .registerPushToken(
            token: token,
            platform: Platform.operatingSystem,
            locale: Platform.localeName,
          );
    } catch (_) {}
  }

  void _openMessageRoute(RemoteMessage message) {
    final route = message.data['route'];
    if (route is String && _isGenerationRoute(route)) {
      widget.router.go(route);
      return;
    }

    final generationId = message.data['generationId'];
    if (generationId is String && generationId.isNotEmpty) {
      widget.router.go('${GenerationStatusPage.routePrefix}/$generationId');
    }
  }

  void _openDeepLink(Uri uri) {
    if (uri.scheme != 'petmagic') {
      return;
    }

    if (uri.host == 'checkout') {
      final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      widget.router.go(WalletPage.routePath);
      if (path == 'success') {
        final sessionId = uri.queryParameters['session_id'];
        if (sessionId != null && sessionId.isNotEmpty) {
          Future.microtask(
            () => ref
                .read(walletControllerProvider.notifier)
                .verifyStripeCheckout(sessionId),
          );
        } else {
          Future.microtask(
            () => ref
                .read(walletControllerProvider.notifier)
                .verifyCheckoutStatus(),
          );
        }
      }
      return;
    }

    if (uri.host == 'generations' && uri.pathSegments.isNotEmpty) {
      widget.router.go(
        '${GenerationStatusPage.routePrefix}/${uri.pathSegments.first}',
      );
      return;
    }

    final generationId = uri.queryParameters['generationId'];
    if (generationId != null && generationId.isNotEmpty) {
      widget.router.go('${GenerationStatusPage.routePrefix}/$generationId');
    }
  }

  bool _isGenerationRoute(String route) {
    return route.startsWith('${GenerationStatusPage.routePrefix}/');
  }
}
