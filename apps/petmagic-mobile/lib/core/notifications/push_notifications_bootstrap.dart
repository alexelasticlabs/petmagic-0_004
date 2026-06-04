import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/notifications/notification_coordinator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
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
  static const _initialLinkTimeout = Duration(seconds: 3);
  final AppLinks _appLinks = AppLinks();
  NotificationCoordinator? _coordinator;
  StreamSubscription<Uri>? _deepLinkSubscription;
  bool _wasAuthenticated = false;
  bool _initialLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _coordinator = NotificationCoordinator(
      templateRepository: ref.read(templateGenerationRepositoryProvider),
      supportRepository: ref.read(supportChatRepositoryProvider),
      walletRepository: ref.read(walletRepositoryProvider),
      onRouteRequested: _openRoute,
    );
  }

  @override
  void dispose() {
    unawaited(_coordinator?.dispose());
    unawaited(_deepLinkSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final launchState = ref.watch(appLaunchControllerProvider);
    if (launchState.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      Future.microtask(() => _coordinator?.initializeForAuthenticatedUser());
    }

    if (!launchState.isAuthenticated && _wasAuthenticated) {
      _wasAuthenticated = false;
      Future.microtask(() => _coordinator?.unregisterCurrentTokenOnSignOut());
    }

    _deepLinkSubscription ??= _appLinks.uriLinkStream.listen(_openDeepLink);
    if (!_initialLinkHandled) {
      _initialLinkHandled = true;
      Future.microtask(_handleInitialLinkOnce);
    }

    return widget.child;
  }

  Future<void> _handleInitialLinkOnce() async {
    if (Firebase.apps.isEmpty || _deepLinkSubscription == null) {
      return;
    }

    try {
      final initialLink = await _appLinks.getInitialLink().timeout(
        _initialLinkTimeout,
      );
      if (initialLink != null) {
        _openDeepLink(initialLink);
      }
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Startup',
        operation: 'deep_link_initial_timeout',
        message:
            'Initial deep link read timed out, continue without blocking startup',
        context: {'timeout_ms': _initialLinkTimeout.inMilliseconds},
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        feature: 'Startup',
        operation: 'deep_link_initial_failed',
        message:
            'Initial deep link read failed, continue without blocking startup',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _openRoute(String route) {
    if (_isGenerationRoute(route) ||
        _isSupportRoute(route) ||
        _isWalletRoute(route) ||
        _isProfileRoute(route)) {
      widget.router.go(route);
      return;
    }
  }

  void _openDeepLink(Uri uri) {
    if (uri.scheme != 'petmagic') {
      return;
    }

    if (uri.host == 'support') {
      widget.router.go(SupportChatPage.routePath);
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

  bool _isSupportRoute(String route) {
    return route == SupportChatPage.routePath || route == '/profile/support';
  }

  bool _isWalletRoute(String route) {
    return route == WalletPage.routePath || route == WalletPage.legacyRoutePath;
  }

  bool _isProfileRoute(String route) {
    return route == '/profile';
  }
}
