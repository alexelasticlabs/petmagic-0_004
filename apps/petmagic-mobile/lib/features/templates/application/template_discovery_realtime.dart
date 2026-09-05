import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_feed_invalidation.dart';

/// Shares the app's reference-counted connection; hiding the discovery screen
/// still records invalidations, but the controller defers HTTP work until resume.
final templateDiscoveryRealtimeProvider = Provider.autoDispose<void>((ref) {
  final client = ref.watch(realtimeClientProvider);
  final controller = ref.read(templateDiscoveryControllerProvider.notifier);
  final subscription = client.events.listen((event) {
    if (event.topic != RealtimeTopics.templatesFeedInvalidated) return;
    final invalidation = TemplateFeedInvalidation.fromPayload(event.payload);
    if (invalidation == null || invalidation.isTemplateOfTheDay) return;
    controller.invalidate();
  });
  unawaited(_bestEffort(client.connect));
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(_bestEffort(client.disconnect));
  });
});

Future<void> _bestEffort(Future<void> Function() operation) async {
  try {
    await operation();
  } on Object {
    // Pull-to-refresh and the freshness interval remain available without SSE.
  }
}
