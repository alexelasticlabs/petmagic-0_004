import 'dart:async';

import 'package:app_links/app_links.dart';
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
  static final Object _disposedLinkReadSentinel = Object();
  final AppLinks _appLinks = AppLinks();
  final Completer<void> _disposed = Completer<void>();
  NotificationCoordinator? _coordinator;
  ProviderSubscription<AppLaunchState>? _launchSubscription;
  StreamSubscription<Uri>? _deepLinkSubscription;
  Timer? _initialLinkTimeoutTimer;
  String? _pendingRoute;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _coordinator = NotificationCoordinator(
      templateRepository: ref.read(templateGenerationRepositoryProvider),
      supportRepository: ref.read(supportChatRepositoryProvider),
      walletRepository: ref.read(walletRepositoryProvider),
      onRouteRequested: _openRoute,
    );
    _launchSubscription = ref.listenManual<AppLaunchState>(
      appLaunchControllerProvider,
      (_, next) => _handleLaunchState(next),
      fireImmediately: true,
    );
    _deepLinkSubscription = _appLinks.uriLinkStream.listen(_openDeepLink);
    Future.microtask(_handleInitialLinkOnce);
  }

  @override
  void dispose() {
    _launchSubscription?.close();
    _initialLinkTimeoutTimer?.cancel();
    _initialLinkTimeoutTimer = null;
    if (!_disposed.isCompleted) {
      _disposed.complete();
    }
    final coordinator = _coordinator;
    _coordinator = null;
    unawaited(coordinator?.dispose());
    unawaited(_deepLinkSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _handleLaunchState(AppLaunchState launchState) {
    _flushPendingRouteIfReady(launchState);

    if (launchState.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      Future.microtask(() {
        if (!mounted) {
          return;
        }

        final coordinator = _coordinator;
        if (coordinator == null) {
          return;
        }

        unawaited(coordinator.initializeForAuthenticatedUser());
      });
      return;
    }

    if (!launchState.isAuthenticated && _wasAuthenticated) {
      _wasAuthenticated = false;
      Future.microtask(() {
        if (!mounted) {
          return;
        }

        final coordinator = _coordinator;
        if (coordinator == null) {
          return;
        }

        unawaited(coordinator.unregisterCurrentTokenOnSignOut());
      });
    }
  }

  Future<void> _handleInitialLinkOnce() async {
    if (_deepLinkSubscription == null) {
      return;
    }

    try {
      final initialLink = await _readInitialLinkWithTimeout();
      if (!mounted || initialLink == null) {
        return;
      }

      if (mounted) {
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

  Future<Uri?> _readInitialLinkWithTimeout() async {
    final timeout = Completer<Never>();
    _initialLinkTimeoutTimer?.cancel();
    _initialLinkTimeoutTimer = Timer(_initialLinkTimeout, () {
      if (!timeout.isCompleted) {
        timeout.completeError(
          TimeoutException(
            'Timed out reading initial deep link.',
            _initialLinkTimeout,
          ),
        );
      }
    });

    try {
      final result = await Future.any<Object?>([
        _appLinks.getInitialLink(),
        timeout.future,
        _disposed.future.then((_) => _disposedLinkReadSentinel),
      ]);
      if (identical(result, _disposedLinkReadSentinel)) {
        return null;
      }

      return result as Uri?;
    } finally {
      _initialLinkTimeoutTimer?.cancel();
      _initialLinkTimeoutTimer = null;
    }
  }

  void _openRoute(String route) {
    if (!mounted) {
      return;
    }

    if (_isGenerationRoute(route) ||
        _isSupportRoute(route) ||
        _isWalletRoute(route) ||
        _isProfileRoute(route)) {
      final launchState = ref.read(appLaunchControllerProvider);
      if (_canOpenRouteNow(launchState)) {
        widget.router.go(route);
      } else {
        _pendingRoute = route;
      }
      return;
    }
  }

  void _flushPendingRouteIfReady(AppLaunchState launchState) {
    final route = _pendingRoute;
    if (route == null || !_canOpenRouteNow(launchState)) {
      return;
    }

    _pendingRoute = null;
    Future.microtask(() {
      if (!mounted) {
        return;
      }
      widget.router.go(route);
    });
  }

  bool _canOpenRouteNow(AppLaunchState launchState) {
    if (launchState.isLoading) {
      return false;
    }

    if (launchState.isAuthenticated) {
      return !launchState.requiresLegalAcceptance;
    }

    return launchState.hasSeenOnboarding && launchState.guestSessionReady;
  }

  void _openDeepLink(Uri uri) {
    if (!mounted) {
      return;
    }

    if (uri.scheme != 'petmagic') {
      return;
    }

    if (uri.host == 'support') {
      _openRoute(SupportChatPage.routePath);
      return;
    }

    if (uri.host == 'checkout') {
      final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      _openRoute(WalletPage.routePath);
      if (path == 'success') {
        final sessionId = uri.queryParameters['session_id'];
        if (sessionId != null && sessionId.isNotEmpty) {
          Future.microtask(() {
            if (!mounted) {
              return;
            }

            unawaited(
              ref
                  .read(walletControllerProvider.notifier)
                  .verifyStripeCheckout(sessionId),
            );
          });
        } else {
          Future.microtask(() {
            if (!mounted) {
              return;
            }

            unawaited(
              ref
                  .read(walletControllerProvider.notifier)
                  .verifyCheckoutStatus(),
            );
          });
        }
      }
      return;
    }

    if (uri.host == 'generations' && uri.pathSegments.isNotEmpty) {
      _openRoute(GenerationStatusPage.routeFor(uri.pathSegments.first));
      return;
    }

    final generationId = uri.queryParameters['generationId'];
    if (generationId != null && generationId.isNotEmpty) {
      _openRoute(GenerationStatusPage.routeFor(generationId));
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
