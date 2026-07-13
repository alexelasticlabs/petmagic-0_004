part of 'support_chat_page.dart';

extension on _SupportChatPageState {
  bool _isWaitingForInitialConversation(SupportChatState state) {
    return state.isLoading && state.conversation == null;
  }

  void _scheduleLoadingFallbackIfNeeded() {
    _loadingFallbackTimer ??= Timer(
      _SupportChatPageState._loadingFallbackDelay,
      () {
        _loadingFallbackTimer = null;
        if (!mounted ||
            !_isWaitingForInitialConversation(
              ref.read(supportChatControllerProvider),
            )) {
          return;
        }

        _applyState(() {
          _showLoadingFallback = true;
        });
      },
    );
  }

  void _clearLoadingFallback({bool notify = false}) {
    _loadingFallbackTimer?.cancel();
    _loadingFallbackTimer = null;
    if (notify && mounted && _showLoadingFallback) {
      _applyState(() {
        _showLoadingFallback = false;
      });
      return;
    }

    _showLoadingFallback = false;
  }

  void _ensureControllerStarted() {
    if (_hasRequestedControllerStart ||
        !ref.read(appLaunchControllerProvider).isAuthenticated) {
      return;
    }

    _hasRequestedControllerStart = true;
    _scheduleLoadingFallbackIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(appLaunchControllerProvider).isAuthenticated) {
        return;
      }

      _controller.start();
      _controller.setScreenVisible(true);
    });
  }

  Future<T> _runExternalMediaPicker<T>(Future<T> Function() action) async {
    _externalMediaPickerDepth += 1;
    if (_externalMediaPickerDepth == 1) {
      _controller.setScreenVisible(false);
      _clearLoadingFallback();
      _controller.suspend();
    }
    try {
      return await action();
    } finally {
      _externalMediaPickerDepth = math.max(0, _externalMediaPickerDepth - 1);
      if (mounted &&
          !_isExternalMediaPickerOpen &&
          ref.read(appLaunchControllerProvider).isAuthenticated) {
        _controller.setScreenVisible(true);
        _scheduleLoadingFallbackIfNeeded();
        unawaited(_controller.start());
      }
    }
  }

  Future<T?> _runAttachmentPickerSession<T>(
    Future<T?> Function() action,
  ) async {
    if (_attachmentPickerBusy) {
      return null;
    }

    _applyState(() {
      _attachmentPickerBusy = true;
    });
    try {
      return await action();
    } finally {
      if (mounted) {
        _applyState(() {
          _attachmentPickerBusy = false;
        });
      } else {
        _attachmentPickerBusy = false;
      }
    }
  }
}
