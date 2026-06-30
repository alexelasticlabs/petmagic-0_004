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
    final replySource = await File(
      'lib/features/support/presentation/widgets/support_chat_messages_reply.part.dart',
    ).readAsString();

    expect(
      pageSource,
      contains('const int _supportReplyThumbnailCacheWidth = 160;'),
    );
    expect(
      pageSource,
      contains("part 'widgets/support_chat_messages_reply.part.dart';"),
    );
    expect(
      messagesSource,
      isNot(contains('memCacheWidth: _supportReplyThumbnailCacheWidth')),
    );
    for (final source in [composerSource, replySource]) {
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
    final messagesSource = await File(
      'lib/features/support/presentation/widgets/support_chat_messages.part.dart',
    ).readAsString();
    final replySource = await File(
      'lib/features/support/presentation/widgets/support_chat_messages_reply.part.dart',
    ).readAsString();
    final sources = [
      await _supportMessageMediaSource(),
      messagesSource,
      replySource,
      await File(
        'lib/features/support/presentation/widgets/support_chat_dialogs.part.dart',
      ).readAsString(),
      await File(
        'lib/features/support/presentation/widgets/support_chat_composer.part.dart',
      ).readAsString(),
    ];

    expect(messagesSource, isNot(contains('CachedNetworkImage(')));
    expect(replySource, contains('CachedNetworkImage('));
    for (final source in sources) {
      expect(source, isNot(contains('Image.network(')));
    }
  });

  test('support remote media previews require trusted attachment origins', () async {
    final mediaSource = await _supportMessageMediaSource();
    final messagesSource = await File(
      'lib/features/support/presentation/widgets/support_chat_messages.part.dart',
    ).readAsString();
    final metaSource = await File(
      'lib/features/support/presentation/widgets/support_chat_messages_meta.part.dart',
    ).readAsString();
    final previewActionsSource = await File(
      'lib/features/support/presentation/widgets/support_chat_actions_preview.part.dart',
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
    expect(messagesSource, isNot(contains('class _MessageMetaFooter')));
    expect(metaSource, contains('class _MessageMetaFooter'));
    expect(metaSource, contains('class _MessageDeliveryStatusIcon'));
    expect(
      previewActionsSource,
      contains('parseSafeSupportExternalUri(imageUrl)'),
    );
    expect(
      previewActionsSource,
      contains('parseSafeSupportExternalUri(videoUrl)'),
    );
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

  test('recent media picker thumbnails decode to bounded thumbnail size', () async {
    final pageSource = await File(
      'lib/features/support/presentation/support_chat_page.dart',
    ).readAsString();
    final pickerSource = await File(
      'lib/features/support/presentation/widgets/support_chat_attachment_picker.part.dart',
    ).readAsString();
    final assetTileSource = await File(
      'lib/features/support/presentation/widgets/support_chat_attachment_picker_asset_tile.part.dart',
    ).readAsString();

    expect(
      pageSource,
      contains('const int _supportRecentMediaThumbnailCacheExtent = 300;'),
    );
    expect(
      pickerSource,
      isNot(contains('cacheWidth: _supportRecentMediaThumbnailCacheExtent')),
    );
    expect(
      assetTileSource,
      contains('cacheWidth: _supportRecentMediaThumbnailCacheExtent'),
    );
    expect(
      assetTileSource,
      contains('cacheHeight: _supportRecentMediaThumbnailCacheExtent'),
    );
    expect(assetTileSource, contains('filterQuality: FilterQuality.medium'));
  });

  test('support chat empty states use sliver scroll surfaces', () async {
    final pageSource = await File(
      'lib/features/support/presentation/support_chat_page.dart',
    ).readAsString();
    final sectionsSource = await File(
      'lib/features/support/presentation/widgets/support_chat_sections.part.dart',
    ).readAsString();
    final interactionsSource = await File(
      'lib/features/support/presentation/widgets/support_chat_sections_interactions.part.dart',
    ).readAsString();
    final composerSource = await File(
      'lib/features/support/presentation/widgets/support_chat_sections_composer.part.dart',
    ).readAsString();

    expect(
      pageSource,
      contains("part 'widgets/support_chat_sections_interactions.part.dart';"),
    );
    expect(
      pageSource,
      contains("part 'widgets/support_chat_sections_composer.part.dart';"),
    );
    expect(sectionsSource, contains('CustomScrollView('));
    expect(sectionsSource, contains('SliverFillRemaining('));
    expect(sectionsSource, isNot(contains('SingleChildScrollView(')));
    expect(sectionsSource, isNot(contains('child: LayoutBuilder(')));
    expect(sectionsSource, isNot(contains('class _SupportComposerPanel')));
    expect(sectionsSource, isNot(contains('class _SwipeToReplyBubble')));
    expect(interactionsSource, contains('class _MessageEntranceAnimation'));
    expect(interactionsSource, contains('class _SwipeToReplyBubble'));
    expect(composerSource, contains('class _SupportComposerPanel'));
    expect(composerSource, contains('class _SupportResolutionPrompt'));
    expect(composerSource, contains('class _SupportClosedConversationBanner'));
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
