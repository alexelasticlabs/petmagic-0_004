import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app and tool sources do not bypass centralized logging', () {
    const developerLogAllowlist = {
      'lib/core/logging/app_logger.dart',
      'lib/core/network/request_identity.dart',
    };
    final violations = <String>[];
    for (final root in [Directory('lib'), Directory('tool')]) {
      if (!root.existsSync()) {
        continue;
      }

      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final source = entity.readAsStringSync();
        if (RegExp(r'\b(?:print|debugPrint)\s*\(').hasMatch(source)) {
          violations.add('${entity.path} uses print/debugPrint');
        }

        final normalizedPath = entity.path.replaceAll('\\', '/');
        final usesDeveloperLog =
            source.contains("import 'dart:developer'") ||
            RegExp(r'\bdeveloper\.log\s*\(').hasMatch(source);
        if (usesDeveloperLog &&
            !developerLogAllowlist.contains(normalizedPath)) {
          violations.add('${entity.path} uses dart:developer directly');
        }
      }
    }

    expect(violations, isEmpty);
  });

  test('high-volume template feed telemetry stays below release info logs', () {
    const debugOnlySources = [
      'lib/features/templates/presentation/template_feed_media_preload_queue.dart',
      'lib/features/templates/presentation/template_feed_playback_manager.dart',
      'lib/features/templates/application/templates_controller.dart',
      'lib/features/templates/presentation/widgets/template_card.dart',
      'lib/features/templates/presentation/widgets/template_card_playback_coordinator.dart',
    ];

    for (final path in debugOnlySources) {
      final source = File(path).readAsStringSync();

      expect(
        source,
        isNot(contains('AppLogger.info(')),
        reason: '$path should not emit high-volume feed telemetry in release.',
      );
    }
  });
}
