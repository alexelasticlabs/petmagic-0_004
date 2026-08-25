import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/app/notifications/notification_coordinator.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/auth/auth_session_storage.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/subscription_management_page.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

part 'push_notification_route_policy.part.dart';

class PushNotificationsBootstrap extends ConsumerStatefulWidget {
  const PushNotificationsBootstrap({
    required this.navigator,
    required this.child,
    super.key,
  });

  final AppNavigator navigator;
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
  static final RegExp _stripeCheckoutSessionIdPattern = RegExp(
    r'^cs_(test|live)_[A-Za-z0-9_]{8,255}$',
  );
  NotificationCoordinator? _coordinator;
  ProviderSubscription<AppLaunchState>? _launchSubscription;
  StreamSubscription<Uri>? _deepLinkSubscription;
  Timer? _initialLinkTimeoutTimer;
  AppDestination? _pendingRoute;
  String? _pendingCheckoutSessionId;
  bool _pendingCheckoutVerificationRequested = false;
  bool _wasAuthenticated = false;
  bool _wasPushEligible = false;

  @override
  void initState() {
    super.initState();
    _coordinator = NotificationCoordinator(
      templateRepository: ref.read(templateGenerationRepositoryProvider),
      supportRepository: ref.read(supportChatRepositoryProvider),
      walletRepository: ref.read(walletRepositoryProvider),
      sessionStorage: ref.read(authSessionStorageProvider),
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
    _flushPendingCheckoutVerificationIfReady(launchState);

    final isPushEligible =
        launchState.isAuthenticated && !launchState.requiresLegalAcceptance;
    if (isPushEligible && !_wasPushEligible) {
      _wasPushEligible = true;
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
    }

    if (!isPushEligible) {
      _wasPushEligible = false;
    }

    if (launchState.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      return;
    }

    if (!launchState.isAuthenticated && _wasAuthenticated) {
      _wasAuthenticated = false;
      _wasPushEligible = false;
      _clearPendingCheckoutVerification();
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
    if (!mounted) {
      return;
    }

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

    if (!_isSupportedRoute(route)) {
      return;
    }

    final launchState = ref.read(appLaunchControllerProvider);
    final destination = _resolvedRouteDestination(route, launchState);
    if (destination != null) {
      widget.navigator.go(destination);
    } else {
      _pendingRoute = _destinationForRoute(route);
    }
  }

  void _flushPendingRouteIfReady(AppLaunchState launchState) {
    final destination = _pendingRoute;
    if (destination == null) {
      return;
    }

    final resolvedDestination = _resolvedRouteDestination(
      destination.location,
      launchState,
    );
    if (resolvedDestination == null) {
      return;
    }

    _pendingRoute = null;
    Future.microtask(() {
      if (!mounted) {
        return;
      }
      widget.navigator.go(resolvedDestination);
    });
  }

  AppDestination? _resolvedRouteDestination(
    String route,
    AppLaunchState launchState,
  ) {
    if (launchState.isLoading) {
      return null;
    }

    if (launchState.isAuthenticated) {
      return launchState.requiresLegalAcceptance
          ? null
          : _destinationForRoute(route);
    }

    if (!launchState.hasSeenOnboarding || !launchState.guestSessionReady) {
      return null;
    }

    return _isAuthOnlyRoute(route)
        ? _authRedirectRoute(route)
        : _destinationForRoute(route);
  }

  void _openDeepLink(Uri uri) {
    if (!mounted) {
      return;
    }

    if (!AppConfig.isExpectedDeepLinkScheme(uri.scheme)) {
      return;
    }

    if (uri.host == 'support') {
      _openRoute(SupportChatPage.routePath);
      return;
    }

    if (uri.host == 'checkout') {
      final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (path == 'manage') {
        _openRoute(SubscriptionManagementPage.routePath);
        return;
      }
      _openRoute(WalletPage.routePath);
      if (path == 'success') {
        final sessionId = uri.queryParameters['session_id'];
        if (sessionId != null && sessionId.isNotEmpty) {
          _queueCheckoutVerification(sessionId: sessionId);
        } else {
          _queueCheckoutVerification();
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

  void _queueCheckoutVerification({String? sessionId}) {
    _pendingCheckoutSessionId = _normalizeStripeCheckoutSessionId(sessionId);
    _pendingCheckoutVerificationRequested = true;
    _flushPendingCheckoutVerificationIfReady(
      ref.read(appLaunchControllerProvider),
    );
  }

  String? _normalizeStripeCheckoutSessionId(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return null;
    }

    if (!_stripeCheckoutSessionIdPattern.hasMatch(normalizedSessionId)) {
      return null;
    }

    return normalizedSessionId;
  }

  void _clearPendingCheckoutVerification() {
    _pendingCheckoutSessionId = null;
    _pendingCheckoutVerificationRequested = false;
  }

  void _flushPendingCheckoutVerificationIfReady(AppLaunchState launchState) {
    if (!_pendingCheckoutVerificationRequested ||
        launchState.isLoading ||
        !launchState.isAuthenticated ||
        launchState.requiresLegalAcceptance) {
      return;
    }

    final sessionId = _pendingCheckoutSessionId;
    _pendingCheckoutSessionId = null;
    _pendingCheckoutVerificationRequested = false;

    final controller = ref.read(walletControllerProvider.notifier);
    if (sessionId != null) {
      unawaited(controller.verifyStripeCheckout(sessionId));
      return;
    }

    unawaited(controller.verifyCheckoutStatus());
  }

  bool _isSupportedRoute(String route) =>
      _PushNotificationRoutePolicy._isSupportedRoute(route);

  bool _isAuthOnlyRoute(String route) =>
      _PushNotificationRoutePolicy._isAuthOnlyRoute(route);

  AppDestination _authRedirectRoute(String route) =>
      _PushNotificationRoutePolicy._authRedirectRoute(route);

  AppDestination? _destinationForRoute(String route) =>
      _PushNotificationRoutePolicy._destinationForRoute(route);
}
