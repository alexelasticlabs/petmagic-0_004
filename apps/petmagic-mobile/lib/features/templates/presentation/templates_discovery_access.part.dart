part of 'templates_discovery_page.dart';

extension _TemplatesDiscoveryAccess on _TemplatesDiscoveryPageState {
  void _refreshAccessForAuthenticatedUser({bool forceRefresh = false}) {
    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      _shouldRefreshAccessOnReconnect = true;
      return;
    }

    _shouldRefreshAccessOnReconnect = false;
    _refreshWalletAccessForAuthenticatedUser(forceRefresh: forceRefresh);
    _refreshProfileAccessForAuthenticatedUser();
  }

  void _refreshWalletAccessForAuthenticatedUser({bool forceRefresh = false}) {
    final launchState = ref.read(appLaunchControllerProvider);
    final walletState = ref.read(walletControllerProvider);
    final hasHydratedWallet =
        walletState.wallet != null && walletState.hasCompletedFullLoad;
    if (!launchState.isAuthenticated ||
        (!hasHydratedWallet &&
            (walletState.isLoading || walletState.isRefreshing)) ||
        _walletAccessRefreshInFlight != null) {
      return;
    }

    final Future<void> refresh;
    if (hasHydratedWallet) {
      refresh = ref
          .read(walletControllerProvider.notifier)
          .syncSnapshot(forceRefresh: forceRefresh);
    } else {
      refresh = ref.read(walletControllerProvider.notifier).load();
    }

    _walletAccessRefreshInFlight = refresh;
    unawaited(
      refresh.whenComplete(() {
        if (identical(_walletAccessRefreshInFlight, refresh)) {
          _walletAccessRefreshInFlight = null;
        }
      }),
    );
  }

  void _refreshProfileAccessForAuthenticatedUser() {
    final launchState = ref.read(appLaunchControllerProvider);
    final profileState = ref.read(profileControllerProvider);
    if (!launchState.isAuthenticated ||
        profileState.profile != null ||
        _profileAccessRefreshInFlight != null) {
      return;
    }

    final Future<void> refresh;
    try {
      refresh = ref.read(profileControllerProvider.notifier).initialize();
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Discovery',
        operation: 'profile_access_preload',
        message: 'Profile access preload could not start.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _profileAccessRefreshInFlight = refresh;
    unawaited(
      refresh
          .catchError((Object error, StackTrace stackTrace) {
            AppLogger.warn(
              feature: 'Templates.Discovery',
              operation: 'profile_access_preload',
              message: 'Profile access preload failed.',
              error: error,
              stackTrace: stackTrace,
            );
          })
          .whenComplete(() {
            if (identical(_profileAccessRefreshInFlight, refresh)) {
              _profileAccessRefreshInFlight = null;
            }
          }),
    );
  }
}
