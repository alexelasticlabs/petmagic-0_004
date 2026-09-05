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
      final frameSource = File(
        'lib/features/templates/presentation/widgets/template_flow_media_preview.part.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final videoSource = File(
        'lib/features/templates/presentation/widgets/template_flow_video_preview.part.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final lifecycleSource = File(
        'lib/features/templates/presentation/widgets/template_flow_video_preview_lifecycle.part.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final source = '$frameSource\n$videoSource\n$lifecycleSource';

      expect(parentSource, contains("import 'dart:async';"));
      expect(
        parentSource,
        contains("part 'template_flow_media_preview.part.dart';"),
      );
      expect(
        parentSource,
        contains("part 'template_flow_video_preview.part.dart';"),
      );
      expect(
        parentSource,
        contains("part 'template_flow_video_preview_lifecycle.part.dart';"),
      );
      expect(contentSource, isNot(contains('class _NetworkVideoPreview')));
      expect(contentSource, contains('TemplateMediaFrame(template: template)'));
      expect(source, contains('class TemplateMediaFrame'));
      expect(source, isNot(contains('class _AdaptiveTemplateMediaFrame')));
      expect(
        parentSource,
        contains(
          "import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';",
        ),
      );
      expect(source, contains('int _initializeRequestVersion = 0;'));
      expect(
        source,
        contains('_TemplateVideoPreviewControllerLease? _controllerLease;'),
      );
      expect(source, contains('Future<void>? _pendingControllerDispose;'));
      expect(source, isNot(contains('bool _hasPreviewSlot = false;')));
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
      expect(source, contains('oldWidget.isActive != widget.isActive'));
      expect(source, contains('if (!widget.isActive)'));
      expect(source, contains('widget.autoplay && !_manualPaused'));
      expect(source, contains('_manualStarted ||'));
      expect(
        source,
        contains('MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()'),
      );
      expect(
        source,
        contains('MediaLifecyclePolicy.releaseVideoPreviewSlot()'),
      );
      expect(
        'MediaLifecyclePolicy.releaseVideoPreviewSlot()'.allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains('final class _TemplateVideoPreviewControllerLease'),
      );
      expect(source, contains('lease.attach(controller);'));
      expect(source, contains('await lease.dispose();'));
      expect(source, contains('final existing = _disposeFuture;'));
      expect(source, isNot(contains('unawaited(previous?.dispose())')));
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
      final pendingDisposeRead = source.indexOf(
        'final pendingDispose = _pendingControllerDispose;',
      );
      final pendingDisposeAwait = source.indexOf(
        'await pendingDispose;',
        pendingDisposeRead,
      );
      final flowLeaseAcquisition = source.indexOf(
        'lease = _TemplateVideoPreviewControllerLease.tryAcquire(',
      );
      final flowLeaseAssignment = source.indexOf(
        '_controllerLease = lease;',
        flowControllerAssignment,
      );
      final leaseDisposer = source.indexOf(
        'Future<void> _dispose({required bool pauseFirst}) async',
      );
      final nativeControllerDispose = source.indexOf(
        'await controller.dispose();',
        leaseDisposer,
      );
      final slotRelease = source.indexOf(
        'MediaLifecyclePolicy.releaseVideoPreviewSlot();',
        leaseDisposer,
      );

      expect(flowControllerAssignment, isNonNegative);
      expect(flowFirstStaleCheck, lessThan(flowSetVolume));
      expect(flowSecondStaleCheck, lessThan(flowSetLooping));
      expect(pendingDisposeRead, isNonNegative);
      expect(pendingDisposeAwait, lessThan(flowLeaseAcquisition));
      expect(flowLeaseAssignment, greaterThan(flowControllerAssignment));
      expect(nativeControllerDispose, isNonNegative);
      expect(nativeControllerDispose, lessThan(slotRelease));
      expect(source, contains('if (!_isAppResumed ||'));
      expect(source, contains('_isAppResumed = false;'));
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
      final mediaSource = [
        'lib/features/support/presentation/widgets/support_chat_message_media.part.dart',
        'lib/features/support/presentation/widgets/support_chat_video_attachment_preview.part.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');

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
