import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';

void main() {
  test(
    'polling realtime client keeps polling until the last consumer disconnects',
    () async {
      final client = PollingRealtimeClient(
        interval: const Duration(milliseconds: 15),
      );
      addTearDown(client.disconnect);

      final events = <RealtimeEvent>[];
      final firstSubscription = client.events.listen(events.add);
      addTearDown(firstSubscription.cancel);

      await client.connect();
      await client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(events, isNotEmpty);

      events.clear();
      await client.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(events, isNotEmpty);

      events.clear();
      await client.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(events, isEmpty);

      final resumedEvents = <RealtimeEvent>[];
      final secondSubscription = client.events.listen(resumedEvents.add);
      addTearDown(secondSubscription.cancel);

      await client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(resumedEvents, isNotEmpty);
    },
  );
}
