import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/firebase/firebase_app_initializer.dart';

void main() {
  test('coalesces concurrent Firebase initialization requests', () async {
    var initialized = false;
    var initializeCalls = 0;
    final gate = Completer<void>();
    final initializer = FirebaseAppInitializer(
      isInitialized: () => initialized,
      initialize: () async {
        initializeCalls++;
        await gate.future;
        initialized = true;
      },
    );

    final first = initializer.ensureInitialized();
    final second = initializer.ensureInitialized();

    expect(initializeCalls, 1);
    expect(identical(first, second), isTrue);

    gate.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
  });

  test('failed initialization can be retried in the same session', () async {
    var initialized = false;
    var initializeCalls = 0;
    final initializer = FirebaseAppInitializer(
      isInitialized: () => initialized,
      initialize: () async {
        initializeCalls++;
        if (initializeCalls == 1) {
          throw StateError('temporary initialization failure');
        }
        initialized = true;
      },
    );

    await expectLater(initializer.ensureInitialized(), throwsStateError);
    expect(await initializer.ensureInitialized(), isTrue);
    expect(initializeCalls, 2);
  });

  test('already initialized Firebase skips the initialize action', () async {
    var initializeCalls = 0;
    final initializer = FirebaseAppInitializer(
      isInitialized: () => true,
      initialize: () async {
        initializeCalls++;
      },
    );

    expect(await initializer.ensureInitialized(), isTrue);
    expect(initializeCalls, 0);
  });

  test('disabled Firebase policy never initializes', () async {
    var initializeCalls = 0;
    final initializer = FirebaseAppInitializer(
      enabled: false,
      isInitialized: () => false,
      initialize: () async {
        initializeCalls++;
      },
    );

    expect(initializer.isInitialized, isFalse);
    expect(await initializer.ensureInitialized(), isFalse);
    expect(initializeCalls, 0);
  });
}
