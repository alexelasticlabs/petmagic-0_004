import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/startup/guest_launch_storage.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('markOnboardingSeen does not update state after disposal', () async {
    final guestStorage = _DelayedGuestLaunchStorage();
    final container = ProviderContainer(
      overrides: [
        authSessionStorageProvider.overrideWith(
          (ref) => _EmptySessionStorage(),
        ),
        guestLaunchStorageProvider.overrideWithValue(guestStorage),
      ],
    );

    container.read(appLaunchControllerProvider);
    final operation = container
        .read(appLaunchControllerProvider.notifier)
        .markOnboardingSeen();

    container.dispose();
    guestStorage.completeSave();

    await expectLater(operation, completes);
  });

  testWidgets('initialize cancels onboarding read timeout after disposal', (
    tester,
  ) async {
    final guestStorage = _NeverCompletingGuestLaunchStorage();
    final container = ProviderContainer(
      overrides: [
        authSessionStorageProvider.overrideWith(
          (ref) => _EmptySessionStorage(),
        ),
        guestLaunchStorageProvider.overrideWithValue(guestStorage),
      ],
    );

    container.read(appLaunchControllerProvider);
    await tester.pump();

    expect(guestStorage.readStarted, isTrue);

    container.dispose();
    await tester.pump();
  });

  testWidgets('scheduled initialize skips after explicit signed in state', (
    tester,
  ) async {
    final guestStorage = _NeverCompletingGuestLaunchStorage();
    final container = ProviderContainer(
      overrides: [
        authSessionStorageProvider.overrideWith(
          (ref) => _EmptySessionStorage(),
        ),
        guestLaunchStorageProvider.overrideWithValue(guestStorage),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(appLaunchControllerProvider.notifier);
    controller.markSignedIn();
    await tester.pump();

    expect(container.read(appLaunchControllerProvider).isLoading, isFalse);
    expect(guestStorage.readStarted, isFalse);
  });
}

class _DelayedGuestLaunchStorage extends GuestLaunchStorage {
  Completer<void>? _pendingSave;

  @override
  Future<bool> readOnboardingSeen() async => false;

  @override
  Future<void> saveOnboardingSeen(bool value) {
    final pendingSave = Completer<void>();
    _pendingSave = pendingSave;
    return pendingSave.future;
  }

  void completeSave() {
    final pendingSave = _pendingSave;
    if (pendingSave == null || pendingSave.isCompleted) {
      throw StateError('No pending save.');
    }
    pendingSave.complete();
  }
}

class _NeverCompletingGuestLaunchStorage extends GuestLaunchStorage {
  bool readStarted = false;

  @override
  Future<bool> readOnboardingSeen() {
    readStarted = true;
    return Completer<bool>().future;
  }

  @override
  Future<void> saveOnboardingSeen(bool value) async {}
}

class _EmptySessionStorage extends AuthSessionStorage {
  @override
  Future<AuthSession?> read() async => null;
}
