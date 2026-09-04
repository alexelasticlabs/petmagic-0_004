import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/notifications/firebase_messaging_token_reader.dart';

void main() {
  test(
    'non-Apple platforms read and normalize the FCM token directly',
    () async {
      var apnsReads = 0;
      var fcmReads = 0;
      final reader = FirebaseMessagingTokenReader(
        requiresApnsToken: false,
        readApnsToken: () async {
          apnsReads++;
          return null;
        },
        readFcmToken: () async {
          fcmReads++;
          return '  fcm-token  ';
        },
      );

      expect(await reader.readToken(), 'fcm-token');
      expect(apnsReads, 0);
      expect(fcmReads, 1);
    },
  );

  test('Apple platforms wait for APNs before reading the FCM token', () async {
    var apnsReads = 0;
    var fcmReads = 0;
    var delays = 0;
    final reader = FirebaseMessagingTokenReader(
      requiresApnsToken: true,
      maxApnsTokenAttempts: 4,
      apnsTokenPollInterval: Duration.zero,
      readApnsToken: () async {
        apnsReads++;
        return apnsReads == 3 ? 'apns-token' : null;
      },
      readFcmToken: () async {
        fcmReads++;
        return 'fcm-token';
      },
      delay: (_) async {
        delays++;
      },
    );

    expect(await reader.readToken(), 'fcm-token');
    expect(apnsReads, 3);
    expect(delays, 2);
    expect(fcmReads, 1);
  });

  test(
    'Apple APNs polling is bounded and does not call getToken early',
    () async {
      var apnsReads = 0;
      var fcmReads = 0;
      var delays = 0;
      final reader = FirebaseMessagingTokenReader(
        requiresApnsToken: true,
        maxApnsTokenAttempts: 3,
        apnsTokenPollInterval: Duration.zero,
        readApnsToken: () async {
          apnsReads++;
          return '  ';
        },
        readFcmToken: () async {
          fcmReads++;
          return 'must-not-be-read';
        },
        delay: (_) async {
          delays++;
        },
      );

      expect(await reader.readToken(), isNull);
      expect(apnsReads, 3);
      expect(delays, 2);
      expect(fcmReads, 0);
    },
  );

  test('Apple APNs polling stops when its lifecycle is cancelled', () async {
    var active = true;
    var apnsReads = 0;
    var fcmReads = 0;
    final reader = FirebaseMessagingTokenReader(
      requiresApnsToken: true,
      maxApnsTokenAttempts: 40,
      readApnsToken: () async {
        apnsReads++;
        return null;
      },
      readFcmToken: () async {
        fcmReads++;
        return 'must-not-be-read';
      },
      delay: (_) async {
        active = false;
      },
    );

    expect(await reader.readToken(canContinue: () => active), isNull);
    expect(apnsReads, 1);
    expect(fcmReads, 0);
  });
}
