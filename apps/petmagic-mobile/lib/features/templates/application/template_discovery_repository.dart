import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';

final templateDiscoveryRepositoryProvider =
    Provider<TemplateDiscoveryRepository>((ref) {
      throw StateError(
        'TemplateDiscoveryRepository is not bound. '
        'Add the app composition override.',
      );
    });

abstract interface class TemplateDiscoveryRepository {
  Future<TemplateDiscovery?> readCached();
  Future<TemplateDiscovery> fetch();
  void cancelPendingRequest();
}
