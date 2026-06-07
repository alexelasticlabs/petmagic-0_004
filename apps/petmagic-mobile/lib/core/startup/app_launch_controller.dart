import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/startup/guest_launch_storage.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';

final appLaunchControllerProvider =
    NotifierProvider<AppLaunchController, AppLaunchState>(
      AppLaunchController.new,
    );

class AppLaunchState {
  const AppLaunchState({
    required this.isLoading,
    required this.isAuthenticated,
    required this.requiresLegalAcceptance,
    required this.hasSeenOnboarding,
    required this.guestSessionReady,
  });

  const AppLaunchState.loading()
    : this(
        isLoading: true,
        isAuthenticated: false,
        requiresLegalAcceptance: false,
        hasSeenOnboarding: false,
        guestSessionReady: false,
      );

  final bool isLoading;
  final bool isAuthenticated;
  final bool requiresLegalAcceptance;
  final bool hasSeenOnboarding;
  final bool guestSessionReady;

  AppLaunchState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    bool? requiresLegalAcceptance,
    bool? hasSeenOnboarding,
    bool? guestSessionReady,
  }) {
    return AppLaunchState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      requiresLegalAcceptance:
          requiresLegalAcceptance ?? this.requiresLegalAcceptance,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      guestSessionReady: guestSessionReady ?? this.guestSessionReady,
    );
  }
}

class AppLaunchController extends Notifier<AppLaunchState> {
  late final GuestLaunchStorage _guestLaunchStorage;
  static const _onboardingReadTimeout = Duration(seconds: 3);
  static final Object _disposedReadSentinel = Object();
  final Completer<void> _disposed = Completer<void>();
  Timer? _onboardingReadTimeoutTimer;
  bool _didScheduleInitialize = false;
  bool _isInitializing = false;

  void _logAppLaunchFailure(String stage, Object error, StackTrace stackTrace) {
    AppLogger.warn(
      feature: 'Startup',
      operation: stage,
      message: 'App launch step failed',
      context: {'stage': stage},
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  AppLaunchState build() {
    _guestLaunchStorage = ref.watch(guestLaunchStorageProvider);
    ref.onDispose(() {
      _onboardingReadTimeoutTimer?.cancel();
      _onboardingReadTimeoutTimer = null;
      if (!_disposed.isCompleted) {
        _disposed.complete();
      }
    });
    if (!_didScheduleInitialize) {
      _didScheduleInitialize = true;
      Future.microtask(initialize);
    }
    return const AppLaunchState.loading();
  }

  Future<void> initialize() async {
    if (!ref.mounted) {
      return;
    }

    if (!state.isLoading) {
      return;
    }

    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    try {
      final sessionStorage = ref.read(authSessionStorageProvider);
      var isAuthenticated = false;
      var requiresLegalAcceptance = false;
      var hasSeenOnboarding = false;
      var guestSessionReady = false;

      try {
        final session = await sessionStorage.read();
        isAuthenticated = session != null;
        requiresLegalAcceptance =
            session?.user.legalAcceptance.requiresAcceptance ?? false;
        guestSessionReady = session != null;
      } catch (error, stackTrace) {
        _logAppLaunchFailure('read_session', error, stackTrace);
        AppLogger.warn(
          feature: 'Startup',
          operation: 'app_launch_session_fallback',
          message: 'Falling back to guest launch because session read failed',
        );
      }

      try {
        final onboardingSeen = await _readOnboardingSeenWithTimeout();
        if (onboardingSeen == null) {
          return;
        }
        hasSeenOnboarding = onboardingSeen;
      } on TimeoutException catch (error, stackTrace) {
        _logAppLaunchFailure('read_onboarding_timeout', error, stackTrace);
      } catch (error, stackTrace) {
        _logAppLaunchFailure('read_onboarding', error, stackTrace);
      }

      if (!ref.mounted) {
        return;
      }

      state = AppLaunchState(
        isLoading: false,
        isAuthenticated: isAuthenticated,
        requiresLegalAcceptance: requiresLegalAcceptance,
        hasSeenOnboarding: hasSeenOnboarding,
        guestSessionReady: guestSessionReady,
      );
    } finally {
      _isInitializing = false;
    }
  }

  Future<bool?> _readOnboardingSeenWithTimeout() async {
    final timeout = Completer<Never>();
    _onboardingReadTimeoutTimer?.cancel();
    _onboardingReadTimeoutTimer = Timer(_onboardingReadTimeout, () {
      if (!timeout.isCompleted) {
        timeout.completeError(
          TimeoutException(
            'Timed out reading onboarding flag.',
            _onboardingReadTimeout,
          ),
        );
      }
    });

    try {
      final result = await Future.any<Object?>([
        _guestLaunchStorage.readOnboardingSeen(),
        timeout.future,
        _disposed.future.then((_) => _disposedReadSentinel),
      ]);
      if (identical(result, _disposedReadSentinel)) {
        return null;
      }

      return result as bool;
    } finally {
      _onboardingReadTimeoutTimer?.cancel();
      _onboardingReadTimeoutTimer = null;
    }
  }

  Future<void> continueAsGuest() async {
    if (!state.hasSeenOnboarding) {
      try {
        await _guestLaunchStorage.saveOnboardingSeen(true);
      } catch (error, stackTrace) {
        _logAppLaunchFailure('save_onboarding_seen', error, stackTrace);
        // Do not block guest entry when local persistence fails.
      }
    }

    if (!ref.mounted) {
      return;
    }

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }

  Future<void> markOnboardingSeen() async {
    await _guestLaunchStorage.saveOnboardingSeen(true);
    if (!ref.mounted) {
      return;
    }

    state = state.copyWith(hasSeenOnboarding: true);
  }

  void markSignedIn() {
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }

  void markSignedInWithLegalStatus({required bool requiresLegalAcceptance}) {
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: requiresLegalAcceptance,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }

  void markSignedOut() {
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      guestSessionReady: false,
    );
  }
}
