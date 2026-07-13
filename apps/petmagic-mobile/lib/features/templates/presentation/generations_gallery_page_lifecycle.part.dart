part of 'generations_gallery_page.dart';

extension on _GenerationsGalleryPageState {
  Future<void> _openPremiumUpsell() async {
    if (ref.read(appLaunchControllerProvider).isAuthenticated) {
      await context.appNavigator.push(const PremiumDestination());
      return;
    }

    await showAuthRequiredSheet(
      context,
      redirectPath: const PremiumDestination().location,
    );
  }

  RequestCancellation? _startMediaAction() {
    if (!mounted || _activeMediaActionCancelToken != null) {
      return null;
    }

    final cancelToken = RequestCancellation();
    _activeMediaActionCancelToken = cancelToken;
    _updateState(() => _isMediaActionInFlight = true);
    return cancelToken;
  }

  void _completeMediaAction(RequestCancellation cancelToken) {
    if (!identical(_activeMediaActionCancelToken, cancelToken)) {
      return;
    }

    _activeMediaActionCancelToken = null;
    if (mounted) {
      _updateState(() => _isMediaActionInFlight = false);
    } else {
      _isMediaActionInFlight = false;
    }
  }

  void _cancelActiveMediaAction() {
    final cancelToken = _activeMediaActionCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('generations_gallery_media_action_cancelled');
    }
    _activeMediaActionCancelToken = null;
    _isMediaActionInFlight = false;
  }

  void _syncTabVisibility(bool isTabActive, {required bool fromAppResume}) {
    if (_isTabActive == isTabActive) {
      if (isTabActive && fromAppResume) {
        _handleScreenBecameVisible(fromAppResume: true);
      }
      return;
    }

    _isTabActive = isTabActive;
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      if (!isTabActive) {
        _cancelActiveMediaAction();
        _setHistoryScreenVisible(false);
        return;
      }

      _handleScreenBecameVisible(fromAppResume: fromAppResume);
    });
  }

  void _handleScreenBecameVisible({required bool fromAppResume}) {
    final isAuthenticated = ref
        .read(appLaunchControllerProvider)
        .isAuthenticated;
    if (!isAuthenticated) {
      _setHistoryScreenVisible(false);
      return;
    }

    _setHistoryScreenVisible(true);
    _maybeLoadWalletForAuthenticatedUser();
    if (!_hasLoadedInitially) {
      _hasLoadedInitially = true;
      unawaited(ref.read(generationHistoryControllerProvider.notifier).load());
      return;
    }

    if (fromAppResume) {
      unawaited(
        ref
            .read(generationHistoryControllerProvider.notifier)
            .load(refresh: true),
      );
    }
  }

  void _maybeLoadWalletForAuthenticatedUser() {
    final launchState = ref.read(appLaunchControllerProvider);
    final walletState = ref.read(walletControllerProvider);
    if (!launchState.isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet ||
        walletState.isLoading ||
        walletState.isRefreshing ||
        walletState.hasCompletedFullLoad) {
      return;
    }

    unawaited(ref.read(walletControllerProvider.notifier).load());
  }

  void _setHistoryScreenVisible(bool visible) {
    final controller = ref.read(generationHistoryControllerProvider.notifier);
    final controllerChanged = !identical(_visibleHistoryController, controller);
    if (!controllerChanged && _historyScreenVisible == visible) {
      return;
    }

    _historyScreenVisible = visible;
    if (controllerChanged) {
      _visibleHistoryController?.setScreenVisible(false);
      _visibleHistoryController = controller;
    }

    controller.setScreenVisible(visible);
  }

  void _syncVisibleHistoryController() {
    final controller = ref.read(generationHistoryControllerProvider.notifier);
    if (!identical(_visibleHistoryController, controller)) {
      _visibleHistoryController?.setScreenVisible(false);
      _visibleHistoryController = controller;
      controller.setScreenVisible(_historyScreenVisible);
    }
  }

  void _setStoredHistoryScreenVisible(
    bool visible, {
    bool clearLoadingState = true,
  }) {
    if (_historyScreenVisible == visible) {
      return;
    }

    _historyScreenVisible = visible;
    _visibleHistoryController?.setScreenVisible(
      visible,
      clearLoadingState: clearLoadingState,
    );
  }
}
