import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('network video preview lifecycle', () {
    test('generation result previews ignore stale async initialization', () {
      final sectionsSource = _readGenerationStatusSectionsLibrarySource();
      final fullscreenSource = File(
        'lib/features/templates/presentation/generation_status_page_fullscreen_viewer.part.dart',
      ).readAsStringSync();
      final source = '$sectionsSource\n$fullscreenSource';

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

      final inlineInitializerStart = sectionsSource.indexOf(
        'Future<void> _initializeController(',
      );
      final firstStaleCheck = sectionsSource.indexOf(
        'if (!_isCurrentVideoRequest(requestVersion, url, controller))',
        inlineInitializerStart,
      );
      final setLooping = sectionsSource.indexOf(
        'await controller.setLooping(true);',
        inlineInitializerStart,
      );
      final secondStaleCheck = sectionsSource.indexOf(
        'if (!_isCurrentVideoRequest(requestVersion, url, controller))',
        firstStaleCheck + 1,
      );
      final setVolume = sectionsSource.indexOf(
        'await controller.setVolume(0);',
        inlineInitializerStart,
      );

      expect(inlineInitializerStart, isNonNegative);
      expect(firstStaleCheck, lessThan(setLooping));
      expect(secondStaleCheck, lessThan(setVolume));

      final fullscreenInitializerStart = fullscreenSource.indexOf(
        'Future<void> _initializeFullscreenVideo(',
      );
      final fullscreenStaleCheck = fullscreenSource.indexOf(
        'if (!_isCurrentVideoRequest(requestVersion, mediaUrl, controller))',
        fullscreenInitializerStart,
      );
      final fullscreenSetLooping = fullscreenSource.indexOf(
        'await controller.setLooping(true);',
        fullscreenInitializerStart,
      );

      expect(fullscreenInitializerStart, isNonNegative);
      expect(fullscreenStaleCheck, lessThan(fullscreenSetLooping));
    });

    test('template flow preview ignores stale async initialization', () {
      final parentSource = File(
        'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
      ).readAsStringSync();
      final contentSource = File(
        'lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart',
      ).readAsStringSync();
      final source = File(
        'lib/features/templates/presentation/widgets/template_flow_media_preview.part.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');

      expect(parentSource, contains("import 'dart:async';"));
      expect(
        parentSource,
        contains("part 'template_flow_media_preview.part.dart';"),
      );
      expect(contentSource, isNot(contains('class _NetworkVideoPreview')));
      expect(
        parentSource,
        contains(
          "import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';",
        ),
      );
      expect(source, contains('int _initializeRequestVersion = 0;'));
      expect(source, contains('bool _hasPreviewSlot = false;'));
      expect(
        source,
        contains(
          'class _NetworkVideoPreviewState extends State<_NetworkVideoPreview>\n'
          '    with WidgetsBindingObserver',
        ),
      );
      expect(source, contains('WidgetsBinding.instance.addObserver(this);'));
      expect(source, contains('WidgetsBinding.instance.removeObserver(this);'));
      expect(source, contains('void didChangeAppLifecycleState'));
      expect(source, contains('state == AppLifecycleState.resumed'));
      expect(source, contains('_isVisibleEnoughToLoad &&'));
      expect(source, contains('state == AppLifecycleState.paused'));
      expect(source, contains('state == AppLifecycleState.hidden'));
      expect(source, contains('unawaited(_disposeVideoController());'));
      expect(
        source,
        contains('MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()'),
      );
      expect(
        source,
        contains('MediaLifecyclePolicy.releaseVideoPreviewSlot()'),
      );
      expect(source, contains('void _releasePreviewSlot()'));
      expect(
        source,
        contains('_isCurrentVideoRequest(requestVersion, url, controller)'),
      );
      expect(source, contains('requestVersion == _initializeRequestVersion'));
      expect(source, contains('widget.url == url'));

      final flowControllerAssignment = source.indexOf(
        '_controller = controller;',
      );
      final flowFirstStaleCheck = source.indexOf(
        'if (!_isCurrentVideoRequest(requestVersion, url, controller))',
        flowControllerAssignment,
      );
      final flowSetVolume = source.indexOf(
        'await controller.setVolume(0);',
        flowControllerAssignment,
      );
      final flowSecondStaleCheck = source.indexOf(
        'if (!_isCurrentVideoRequest(requestVersion, url, controller))',
        flowFirstStaleCheck + 1,
      );
      final flowSetLooping = source.indexOf(
        'await controller.setLooping(true);',
        flowControllerAssignment,
      );

      expect(flowControllerAssignment, isNonNegative);
      expect(flowFirstStaleCheck, lessThan(flowSetVolume));
      expect(flowSecondStaleCheck, lessThan(flowSetLooping));
    });

    test('template of the day preview ignores stale async initialization', () {
      final source = File(
        'lib/features/templates/presentation/widgets/template_of_the_day_card_media.part.dart',
      ).readAsStringSync();

      expect(source, contains('int _initializeRequestVersion = 0;'));
      expect(source, contains('bool _hasPreviewSlot = false;'));
      expect(source, contains('WidgetsBinding.instance.addObserver(this);'));
      expect(source, contains('WidgetsBinding.instance.removeObserver(this);'));
      expect(source, contains('void didChangeAppLifecycleState'));
      expect(source, contains('state == AppLifecycleState.resumed'));
      expect(source, contains('state == AppLifecycleState.paused'));
      expect(
        source,
        contains('MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()'),
      );
      expect(
        source,
        contains('MediaLifecyclePolicy.releaseVideoPreviewSlot()'),
      );
      expect(
        source,
        contains('_isCurrentVideoRequestToken(requestVersion, previewUrl)'),
      );
      expect(source, contains('requestVersion == _initializeRequestVersion'));
      expect(source, contains('widget.previewUrl == previewUrl'));

      final createController = source.indexOf(
        'controller = await createCachedTemplatePreviewVideoController(',
      );
      final firstStaleCheck = source.indexOf(
        'if (!_isCurrentVideoRequestToken(requestVersion, previewUrl))',
        createController,
      );
      final setVolume = source.indexOf(
        'await controller.setVolume(0);',
        createController,
      );
      final secondStaleCheck = source.indexOf(
        'if (!_isCurrentVideoRequestToken(requestVersion, previewUrl))',
        firstStaleCheck + 1,
      );
      final setLooping = source.indexOf(
        'await controller.setLooping(true);',
        createController,
      );

      expect(createController, isNonNegative);
      expect(firstStaleCheck, lessThan(setVolume));
      expect(secondStaleCheck, lessThan(setLooping));
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

String _readGenerationStatusSectionsLibrarySource() {
  const files = [
    'lib/features/templates/presentation/generation_status_page_sections.dart',
    'lib/features/templates/presentation/generation_status_page_active_card.part.dart',
    'lib/features/templates/presentation/generation_status_page_active_chrome.part.dart',
    'lib/features/templates/presentation/generation_status_page_result_cards.part.dart',
    'lib/features/templates/presentation/generation_status_page_result_action_widgets.part.dart',
    'lib/features/templates/presentation/generation_status_page_result_details.part.dart',
  ];

  return files.map((path) => File(path).readAsStringSync()).join('\n');
}
