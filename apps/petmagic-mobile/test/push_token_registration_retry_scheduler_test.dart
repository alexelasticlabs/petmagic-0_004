import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registration_retry_scheduler.dart';

void main() {
  testWidgets(
    'token-unavailable result is retried until registration succeeds',
    (tester) async {
      var sessionActive = true;
      var tokenReads = 0;
      late final PushTokenRegistrationRetryScheduler scheduler;

      Future<void> registerCurrentToken() async {
        tokenReads++;
        final token = tokenReads >= 3 ? 'fcm-token' : null;
        if (token == null) {
          scheduler.schedule(registerCurrentToken);
          return;
        }
        scheduler.reset();
      }

      scheduler = PushTokenRegistrationRetryScheduler(
        canRetry: () => sessionActive,
        retryDelays: const [Duration(milliseconds: 10)],
      );

      scheduler.schedule(registerCurrentToken);
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.pump(const Duration(milliseconds: 10));
        await tester.pump();
      }

      expect(tokenReads, 3);
      expect(scheduler.hasPendingRetry, isFalse);
      sessionActive = false;
      scheduler.cancel();
    },
  );

  for (final lifecycleEnd in ['sign-out', 'dispose']) {
    testWidgets('pending retry is cancelled on $lifecycleEnd', (tester) async {
      var canRetry = true;
      var attempts = 0;
      final scheduler = PushTokenRegistrationRetryScheduler(
        canRetry: () => canRetry,
        retryDelays: const [Duration(seconds: 1)],
      );

      scheduler.schedule(() async {
        attempts++;
      });
      expect(scheduler.hasPendingRetry, isTrue);

      canRetry = false;
      scheduler.cancel();
      await tester.pump(const Duration(seconds: 1));

      expect(attempts, 0);
      expect(scheduler.hasPendingRetry, isFalse);
    });
  }
}
