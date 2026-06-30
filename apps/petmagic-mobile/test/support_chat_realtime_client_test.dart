import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'support chat realtime disconnect keeps event stream reusable for next start',
    () async {
      final client = SignalRSupportChatRealtimeClient(
        sessionStorage: AuthSessionStorage(),
        apiBaseUrlResolver: ApiBaseUrlResolver(),
      );

      var streamClosed = false;
      final subscription = client.events.listen(
        (_) {},
        onDone: () {
          streamClosed = true;
        },
      );
      addTearDown(subscription.cancel);

      await client.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(streamClosed, isFalse);

      final secondSubscription = client.events.listen((_) {});
      addTearDown(secondSubscription.cancel);
    },
  );

  test('support chat realtime dispose closes the event stream', () async {
    final client = SignalRSupportChatRealtimeClient(
      sessionStorage: AuthSessionStorage(),
      apiBaseUrlResolver: ApiBaseUrlResolver(),
    );

    var streamClosed = false;
    final subscription = client.events.listen(
      (_) {},
      onDone: () {
        streamClosed = true;
      },
    );
    addTearDown(subscription.cancel);

    await client.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(streamClosed, isTrue);
  });
}
