import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('templates presentation logging contracts', () {
    test('mobile lib contains no silent catch blocks', () {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('catch (_)')),
          reason: 'silent catch found in ${file.path}',
        );
        expect(
          source,
          isNot(contains('catch {')),
          reason: 'bare catch found in ${file.path}',
        );
      }
    });

    test('templates presentation logs non-blocking failures explicitly', () {
      final generationStatusSource = _readSource(
        'lib/features/templates/presentation/generation_status_page.dart',
        'lib/features/templates/presentation/generation_status_page_result_actions.part.dart',
        'lib/features/templates/presentation/generation_status_page_result_sections.part.dart',
        'lib/features/templates/presentation/generation_status_page_fullscreen_viewer.part.dart',
      );
      final templateFlowSource = _readSource(
        'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
        'lib/features/templates/presentation/widgets/template_flow_media_preview.part.dart',
      );
      final templateCardSource = _readSource(
        'lib/features/templates/presentation/widgets/template_card.dart',
      );
      final templatesControllerSource = _readSource(
        'lib/features/templates/application/templates_controller.dart',
        'lib/features/templates/application/templates_metadata_coordinator.dart',
        'lib/features/templates/application/templates_preview_warmup_coordinator.dart',
      );
      final generationControllerSource = _readSource(
        'lib/features/templates/presentation/template_generation_controller.dart',
        'lib/features/templates/presentation/template_generation_wallet_coordinator.dart',
      );

      expect(generationStatusSource, contains('AppLogger.warn('));
      expect(
        generationStatusSource,
        contains("operation: 'record_result_analytics_event'"),
      );
      expect(
        generationStatusSource,
        contains("operation: 'initialize_video_preview'"),
      );

      expect(templateFlowSource, contains('AppLogger.warn('));
      expect(
        templateFlowSource,
        contains("operation: 'initialize_video_preview'"),
      );
      expect(templateFlowSource, contains("operation: 'pause_before_dispose'"));
      expect(templateFlowSource, contains("operation: 'sync_playback_state'"));

      expect(templateCardSource, contains('AppLogger.warn('));
      expect(
        templateCardSource,
        contains("operation: 'ensure_video_controller'"),
      );
      expect(
        templateCardSource,
        contains("operation: 'dispose_video_controller'"),
      );

      expect(templatesControllerSource, contains('AppLogger.warn('));
      expect(
        templatesControllerSource,
        contains("operation: 'refresh_categories'"),
      );
      expect(
        templatesControllerSource,
        contains("operation: 'warmup_single_url'"),
      );

      expect(generationControllerSource, contains('AppLogger.warn('));
      expect(
        generationControllerSource,
        contains("operation: 'refresh_wallet_after_generation'"),
      );
    });
  });
}

String _readSource(
  String firstPath, [
  String? secondPath,
  String? thirdPath,
  String? fourthPath,
]) {
  final buffer = StringBuffer(File(firstPath).readAsStringSync());
  for (final path in [secondPath, thirdPath, fourthPath]) {
    if (path != null) {
      buffer
        ..writeln()
        ..write(File(path).readAsStringSync());
    }
  }

  return buffer.toString();
}
