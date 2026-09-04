import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/notifications/authenticated_notification_initialization_runner.dart';

void main() {
  test(
    'logout and sign-in during initialization reruns for the new epoch',
    () async {
      final runner = AuthenticatedNotificationInitializationRunner();
      final firstSessionGate = Completer<void>();
      final startedEpochs = <int>[];
      final completedEpochs = <int>[];

      Future<void> initialize(int epoch) async {
        startedEpochs.add(epoch);
        if (startedEpochs.length == 1) {
          await firstSessionGate.future;
        }
        if (runner.canContinue(epoch)) {
          completedEpochs.add(epoch);
        }
      }

      final first = runner.activateAndRun(initialize);
      await Future<void>.delayed(Duration.zero);
      runner.deactivate();
      final second = runner.activateAndRun(initialize);
      firstSessionGate.complete();

      await Future.wait([first, second]);

      expect(startedEpochs, [0, 1]);
      expect(completedEpochs, [1]);
    },
  );

  test('dispose invalidates an in-flight initialization epoch', () async {
    final runner = AuthenticatedNotificationInitializationRunner();
    final gate = Completer<void>();
    var completed = false;

    final initialization = runner.activateAndRun((epoch) async {
      await gate.future;
      completed = runner.canContinue(epoch);
    });
    await Future<void>.delayed(Duration.zero);

    runner.dispose();
    gate.complete();
    await initialization;

    expect(completed, isFalse);
  });

  test(
    'a later request reruns after an incomplete active-session run',
    () async {
      final runner = AuthenticatedNotificationInitializationRunner();
      var attempts = 0;

      Future<void> initialize(int epoch) async {
        if (runner.canContinue(epoch)) {
          attempts++;
        }
      }

      await runner.activateAndRun(initialize);
      await runner.activateAndRun(initialize);

      expect(attempts, 2);
    },
  );
}
