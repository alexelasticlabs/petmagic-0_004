import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'network image attachment previews use one bounded image provider',
    () async {
      final source = await _supportMessageMediaSource();
      final pageSource = await File(
        'lib/features/support/presentation/support_chat_page.dart',
      ).readAsString();

      expect(source, contains('ResizeImage.resizeIfNeeded'));
      expect(source, contains('CachedNetworkImageProvider(imageUrl'));
      expect(source, contains('maxWidth: _previewCacheWidth'));
      expect(source, contains('image: _imageProvider'));
      expect(
        pageSource,
        contains(
          "import 'package:cached_network_image/cached_network_image.dart';",
        ),
      );
      expect(source, contains('CachedNetworkImage('));
      expect(source, contains('memCacheWidth: 512'));
      expect(
        source,
        isNot(contains('child: Image.network(\r\n            widget.imageUrl')),
      );
      expect(
        source,
        isNot(contains('child: Image.network(\n            widget.imageUrl')),
      );
    },
  );

  test('reply thumbnails decode to bounded thumbnail size', () async {
    final pageSource = await File(
      'lib/features/support/presentation/support_chat_page.dart',
    ).readAsString();
    final composerSource = await File(
      'lib/features/support/presentation/widgets/support_chat_composer.part.dart',
    ).readAsString().then((source) => source.replaceAll('\r\n', '\n'));
    final messagesSource = await File(
      'lib/features/support/presentation/widgets/support_chat_messages.part.dart',
    ).readAsString();

    expect(
      pageSource,
      contains('const int _supportReplyThumbnailCacheWidth = 160;'),
    );
    for (final source in [composerSource, messagesSource]) {
      expect(
        source,
        anyOf(
          contains('cacheWidth: _supportReplyThumbnailCacheWidth'),
          contains('memCacheWidth: _supportReplyThumbnailCacheWidth'),
        ),
      );
      expect(source, contains('filterQuality: FilterQuality.medium'));
      expect(source, isNot(contains('cacheWidth: 720')));
    }
  });

  test('support image previews avoid uncached Image.network widgets', () async {
    final sources = [
      await _supportMessageMediaSource(),
      await File(
        'lib/features/support/presentation/widgets/support_chat_messages.part.dart',
      ).readAsString(),
      await File(
        'lib/features/support/presentation/widgets/support_chat_dialogs.part.dart',
      ).readAsString(),
      await File(
        'lib/features/support/presentation/widgets/support_chat_composer.part.dart',
      ).readAsString(),
    ];

    for (final source in sources) {
      expect(source, contains('CachedNetworkImage('));
      expect(source, isNot(contains('Image.network(')));
    }
  });

  test('support remote media previews require trusted attachment origins', () async {
    final mediaSource = await _supportMessageMediaSource();
    final messagesSource = await File(
      'lib/features/support/presentation/widgets/support_chat_messages.part.dart',
    ).readAsString();
    final actionsSource = await File(
      'lib/features/support/presentation/widgets/support_chat_actions.part.dart',
    ).readAsString();
    final dialogsSource = await File(
      'lib/features/support/presentation/widgets/support_chat_dialogs.part.dart',
    ).readAsString();

    expect(
      mediaSource,
      contains(
        'final safeUri = parseSafeSupportExternalUri(attachment.fileUrl);',
      ),
    );
    expect(mediaSource, contains('imageUrl: safeUri!.toString()'));
    expect(mediaSource, contains('_UnsupportedAttachmentTileBackground('));
    expect(
      messagesSource,
      contains(
        'final safeUri = parseSafeSupportExternalUri(attachment.fileUrl);',
      ),
    );
    expect(messagesSource, contains('_UnsupportedAttachmentPlaceholder('));
    expect(actionsSource, contains('parseSafeSupportExternalUri(imageUrl)'));
    expect(actionsSource, contains('parseSafeSupportExternalUri(videoUrl)'));
    expect(
      mediaSource,
      contains('final safeUri = parseSafeSupportExternalUri(videoUrl);'),
    );
    expect(
      dialogsSource,
      contains('final safeUri = parseSafeSupportExternalUri(videoUrl);'),
    );
    expect(mediaSource, contains('VideoPlayerController.networkUrl(safeUri)'));
    expect(
      dialogsSource,
      contains('VideoPlayerController.networkUrl(safeUri)'),
    );
    expect(
      mediaSource,
      isNot(contains('imageUrl: attachment.fileUrl,\n                  fit')),
    );
    expect(
      mediaSource,
      isNot(contains('VideoPlayerController.networkUrl(Uri.parse(videoUrl))')),
    );
    expect(
      dialogsSource,
      isNot(contains('VideoPlayerController.networkUrl(Uri.parse(videoUrl))')),
    );
  });

  test('local composer attachment previews decode to thumbnail size', () async {
    final pageSource = await File(
      'lib/features/support/presentation/support_chat_page.dart',
    ).readAsString();
    final composerSource = await File(
      'lib/features/support/presentation/widgets/support_chat_composer.part.dart',
    ).readAsString().then((source) => source.replaceAll('\r\n', '\n'));

    expect(
      pageSource,
      contains('const int _supportComposerAttachmentPreviewCacheExtent = 220;'),
    );
    expect(
      composerSource,
      contains(
        'cacheWidth:\n                                    _supportComposerAttachmentPreviewCacheExtent',
      ),
    );
    expect(
      composerSource,
      contains(
        'cacheHeight:\n                                    _supportComposerAttachmentPreviewCacheExtent',
      ),
    );
    expect(composerSource, contains('filterQuality: FilterQuality.medium'));
  });

  test(
    'recent media picker thumbnails decode to bounded thumbnail size',
    () async {
      final pageSource = await File(
        'lib/features/support/presentation/support_chat_page.dart',
      ).readAsString();
      final pickerSource = await File(
        'lib/features/support/presentation/widgets/support_chat_attachment_picker.part.dart',
      ).readAsString();

      expect(
        pageSource,
        contains('const int _supportRecentMediaThumbnailCacheExtent = 300;'),
      );
      expect(
        pickerSource,
        contains('cacheWidth: _supportRecentMediaThumbnailCacheExtent'),
      );
      expect(
        pickerSource,
        contains('cacheHeight: _supportRecentMediaThumbnailCacheExtent'),
      );
      expect(pickerSource, contains('filterQuality: FilterQuality.medium'));
    },
  );

  test('support chat empty states use sliver scroll surfaces', () async {
    final sectionsSource = await File(
      'lib/features/support/presentation/widgets/support_chat_sections.part.dart',
    ).readAsString();

    expect(sectionsSource, contains('CustomScrollView('));
    expect(sectionsSource, contains('SliverFillRemaining('));
    expect(sectionsSource, isNot(contains('SingleChildScrollView(')));
    expect(sectionsSource, isNot(contains('child: LayoutBuilder(')));
  });
}

Future<String> _supportMessageMediaSource() async {
  final previewSource = await File(
    'lib/features/support/presentation/widgets/support_chat_message_media.part.dart',
  ).readAsString();
  final gridSource = await File(
    'lib/features/support/presentation/widgets/support_chat_message_media_grid.part.dart',
  ).readAsString();
  return '$previewSource\n$gridSource';
}
