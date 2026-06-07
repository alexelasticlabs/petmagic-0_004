import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('network video preview lifecycle', () {
    test('generation result previews ignore stale async initialization', () {
      final source = File(
        'lib/features/templates/presentation/generation_status_page_sections.dart',
      ).readAsStringSync();

      expect(source, contains('int _initializeRequestVersion = 0;'));
      expect(source, contains('int _videoInitializeRequestVersion = 0;'));
      expect(
        source,
        contains('_isCurrentVideoRequest(requestVersion, url, controller)'),
      );
      expect(
        source,
        contains(
          '_isCurrentVideoRequest(requestVersion, mediaUrl, controller)',
        ),
      );
      expect(source, contains('requestVersion == _initializeRequestVersion'));
      expect(
        source,
        contains('requestVersion == _videoInitializeRequestVersion'),
      );
      expect(source, contains('widget.url == url'));
      expect(source, contains('widget.mediaUrl == mediaUrl'));
    });

    test('template flow preview ignores stale async initialization', () {
      final parentSource = File(
        'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
      ).readAsStringSync();
      final source = File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart',
      ).readAsStringSync();

      expect(parentSource, contains("import 'dart:async';"));
      expect(source, contains('int _initializeRequestVersion = 0;'));
      expect(
        source,
        contains('_isCurrentVideoRequest(requestVersion, url, controller)'),
      );
      expect(source, contains('requestVersion == _initializeRequestVersion'));
      expect(source, contains('widget.url == url'));
    });

    test('support video previews ignore stale async initialization', () {
      final dialogSource = File(
        'lib/features/support/presentation/widgets/support_chat_dialogs.part.dart',
      ).readAsStringSync();
      final mediaSource = File(
        'lib/features/support/presentation/widgets/support_chat_message_media.part.dart',
      ).readAsStringSync();

      for (final source in [dialogSource, mediaSource]) {
        expect(source, contains('int _initializeRequestVersion = 0;'));
        expect(
          source,
          contains(
            '_isCurrentVideoRequest(requestVersion, videoUrl, controller)',
          ),
        );
        expect(source, contains('requestVersion == _initializeRequestVersion'));
        expect(source, contains('widget.videoUrl == videoUrl'));
      }
    });
  });
}
