part of 'push_notifications_bootstrap.dart';

abstract final class _PushNotificationRoutePolicy {
  static bool _isGenerationRoute(String route) {
    return route.startsWith('${GenerationStatusPage.routePrefix}/');
  }

  static bool _isSupportedRoute(String route) {
    return _isGenerationRoute(route) ||
        _isSupportRoute(route) ||
        _isWalletRoute(route) ||
        _isSubscriptionManagementRoute(route) ||
        _isProfileRoute(route);
  }

  static bool _isAuthOnlyRoute(String route) {
    return _isSupportRoute(route) ||
        _isWalletRoute(route) ||
        _isSubscriptionManagementRoute(route) ||
        _isProfileRoute(route);
  }

  static AppDestination _authRedirectRoute(String route) {
    final redirectPath = normalizeAuthRedirectPath(route);
    if (redirectPath == null) {
      return const AuthDestination();
    }

    return AuthDestination(redirectPath: redirectPath);
  }

  static AppDestination? _destinationForRoute(String route) {
    if (_isGenerationRoute(route)) {
      return GenerationDestination(
        route.substring('${GenerationStatusPage.routePrefix}/'.length),
      );
    }
    return switch (route) {
      '/templates' => const TemplatesDestination(),
      '/creations' => const CreationsDestination(),
      '/rewards' => const RewardsDestination(),
      '/profile' => const ProfileDestination(),
      '/profile/support' => const SupportDestination(),
      '/profile/support/chat' => const SupportChatDestination(),
      '/profile/wallet' => const WalletDestination(),
      '/profile/premium' => const PremiumDestination(),
      '/profile/subscription/manage' =>
        const SubscriptionManagementDestination(),
      _ => null,
    };
  }

  static bool _isSupportRoute(String route) {
    return route == SupportChatPage.routePath || route == '/profile/support';
  }

  static bool _isWalletRoute(String route) {
    return route == WalletPage.routePath;
  }

  static bool _isSubscriptionManagementRoute(String route) {
    return route == SubscriptionManagementPage.routePath;
  }

  static bool _isProfileRoute(String route) {
    return route == '/profile';
  }
}
