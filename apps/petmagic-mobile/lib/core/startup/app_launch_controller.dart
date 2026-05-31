import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  AppLaunchState build() {
    _guestLaunchStorage = ref.watch(guestLaunchStorageProvider);
    Future.microtask(initialize);
    return const AppLaunchState.loading();
  }

  Future<void> initialize() async {
    final sessionStorage = ref.read(authSessionStorageProvider);
    final session = await sessionStorage.read();
    final hasSeenOnboarding = await _guestLaunchStorage.readOnboardingSeen();

    if (!ref.mounted) {
      return;
    }

    state = AppLaunchState(
      isLoading: false,
      isAuthenticated: session != null,
      requiresLegalAcceptance:
          session?.user.legalAcceptance.requiresAcceptance ?? false,
      hasSeenOnboarding: hasSeenOnboarding,
      guestSessionReady: session != null,
    );
  }

  Future<void> continueAsGuest() async {
    if (!state.hasSeenOnboarding) {
      try {
        await _guestLaunchStorage.saveOnboardingSeen(true);
      } catch (_) {
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

  void markSignedInWithLegalStatus({
    required bool requiresLegalAcceptance,
  }) {
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
