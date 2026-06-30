import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'support recent media picker exits loading state on PhotoManager errors',
    () {
      final source = File(
        'lib/features/support/presentation/widgets/support_chat_attachment_picker.part.dart',
      ).readAsStringSync();
      final pageSource = File(
        'lib/features/support/presentation/support_chat_page.dart',
      ).readAsStringSync();
      final attachmentFlowSource = File(
        'lib/features/support/presentation/widgets/support_chat_actions_attachment_flow.part.dart',
      ).readAsStringSync();
      final assetTileSource = File(
        'lib/features/support/presentation/widgets/support_chat_attachment_picker_asset_tile.part.dart',
      ).readAsStringSync();
      final quickTilesSource = File(
        'lib/features/support/presentation/widgets/support_chat_attachment_picker_quick_tiles.part.dart',
      ).readAsStringSync();

      final initializeBody = _methodBody(source, '_initializeAssets');
      final loadNextPageBody = _methodBody(source, '_loadNextPage');
      final markFailedBody = _methodBody(source, '_markAssetLoadFailed');
      final retryBody = _methodBody(source, '_retryInitializeAssets');

      expect(source, contains('bool _assetLoadFailed = false;'));
      expect(
        pageSource,
        contains(
          "part 'widgets/support_chat_actions_attachment_flow.part.dart';",
        ),
      );
      expect(
        pageSource,
        contains("part 'widgets/support_chat_attachment_picker.part.dart';"),
      );
      expect(
        pageSource,
        contains(
          "part 'widgets/support_chat_attachment_picker_asset_tile.part.dart';",
        ),
      );
      expect(
        pageSource,
        contains(
          "part 'widgets/support_chat_attachment_picker_quick_tiles.part.dart';",
        ),
      );
      expect(
        attachmentFlowSource,
        isNot(contains('class _SupportAttachmentPickerSheet')),
      );
      expect(
        pageSource,
        isNot(contains("part 'widgets/support_chat_actions.part.dart';")),
      );
      expect(source, contains('class _SupportAttachmentPickerSheet'));
      expect(source, isNot(contains('class _SupportRecentAssetTile')));
      expect(source, isNot(contains('class _SupportRecentCameraTile')));
      expect(source, isNot(contains('class _SupportRecentFilesTile')));
      expect(assetTileSource, contains('class _SupportRecentAssetTile'));
      expect(quickTilesSource, contains('class _SupportRecentCameraTile'));
      expect(quickTilesSource, contains('class _SupportRecentFilesTile'));
      expect(
        initializeBody,
        contains('PhotoManager.requestPermissionExtend()'),
      );
      expect(initializeBody, contains('PhotoManager.getAssetPathList('));
      expect(initializeBody, contains('on Object'));
      expect(
        initializeBody,
        contains('_markAssetLoadFailed(clearAssets: true)'),
      );

      expect(loadNextPageBody, contains('getAssetListPaged('));
      expect(loadNextPageBody, contains('on Object'));
      expect(loadNextPageBody, contains('_isLoadingMore = false;'));
      expect(loadNextPageBody, contains('_hasMore = false;'));
      expect(loadNextPageBody, contains('_assetLoadFailed = _assets.isEmpty;'));

      expect(markFailedBody, contains('_isInitialLoading = false;'));
      expect(markFailedBody, contains('_isLoadingMore = false;'));
      expect(markFailedBody, contains('_assetLoadFailed = true;'));

      expect(retryBody, contains('_isInitialLoading = true;'));
      expect(retryBody, contains('unawaited(_initializeAssets())'));
      expect(source, contains('text.supportChatUnavailableError'));
      expect(source, contains('TextButton('));
      expect(source, contains('child: Text(text.retryAction)'));
    },
  );
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    '(?:Future<[^>]+>|void)\\s+${RegExp.escape(methodName)}\\s*\\(',
  ).firstMatch(source);
  if (methodMatch == null) {
    throw StateError('Method $methodName not found.');
  }

  final parameterStart = source.indexOf('(', methodMatch.start);
  final parameterEnd = _matchingCloseParen(source, parameterStart);
  final openBraceIndex = source.indexOf('{', parameterEnd);
  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(openBraceIndex, index + 1);
      }
    }
  }

  throw StateError('Method $methodName body did not close.');
}

int _matchingCloseParen(String source, int openParenIndex) {
  var depth = 0;
  for (var index = openParenIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) {
        return index;
      }
    }
  }

  throw StateError('Method parameters did not close.');
}
