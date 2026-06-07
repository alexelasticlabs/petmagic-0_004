import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: 'Missing method: $signature');

  final parameterStart = source.indexOf('(', start);
  expect(
    parameterStart,
    isNonNegative,
    reason: 'Missing method parameters: $signature',
  );

  var parameterDepth = 0;
  var parameterEnd = -1;
  for (var index = parameterStart; index < source.length; index += 1) {
    final character = source[index];
    if (character == '(') {
      parameterDepth += 1;
    } else if (character == ')') {
      parameterDepth -= 1;
      if (parameterDepth == 0) {
        parameterEnd = index;
        break;
      }
    }
  }
  expect(
    parameterEnd,
    isNonNegative,
    reason: 'Unclosed parameters: $signature',
  );

  final braceStart = source.indexOf('{', parameterEnd);
  expect(braceStart, isNonNegative, reason: 'Missing method body: $signature');

  var depth = 0;
  for (var index = braceStart; index < source.length; index += 1) {
    final character = source[index];
    if (character == '{') {
      depth += 1;
    } else if (character == '}') {
      depth -= 1;
      if (depth == 0) {
        return source.substring(braceStart + 1, index);
      }
    }
  }

  fail('Unclosed method body: $signature');
}

void main() {
  test('support chat external media downloads are cancelled on dispose', () {
    final pageSource = File(
      'lib/features/support/presentation/support_chat_page.dart',
    ).readAsStringSync();
    final mediaSource = File(
      'lib/features/support/presentation/widgets/'
      'support_chat_external_media.part.dart',
    ).readAsStringSync();

    final disposeBody = _methodBody(pageSource, 'void dispose()');
    expect(pageSource, contains("import 'package:dio/dio.dart';"));
    expect(
      pageSource,
      contains('CancelToken? _activeMediaDownloadCancelToken;'),
    );
    expect(disposeBody, contains('_cancelActiveMediaDownload();'));
    expect(pageSource, contains('CancelToken? _startMediaDownload()'));
    expect(pageSource, contains('void _completeMediaDownload(CancelToken'));
    expect(pageSource, contains('void _cancelActiveMediaDownload()'));
    expect(
      pageSource,
      contains("cancelToken.cancel('support_media_download_cancelled');"),
    );

    final saveBody = _methodBody(
      mediaSource,
      'Future<void> _saveImageToDeviceImpl({',
    );
    expect(saveBody, contains('final cancelToken = _startMediaDownload();'));
    expect(saveBody, contains('if (cancelToken == null)'));
    expect(saveBody, contains('cancelToken: cancelToken'));
    expect(saveBody, contains('on DioException catch (error)'));
    expect(saveBody, contains('CancelToken.isCancel(error)'));
    expect(saveBody, contains('_completeMediaDownload(cancelToken);'));

    final shareBody = _methodBody(
      mediaSource,
      'Future<void> _shareImageImpl({',
    );
    expect(shareBody, contains('final cancelToken = _startMediaDownload();'));
    expect(shareBody, contains('if (cancelToken == null)'));
    expect(shareBody, contains('cancelToken: cancelToken'));
    expect(shareBody, contains('on DioException catch (error)'));
    expect(shareBody, contains('CancelToken.isCancel(error)'));
    expect(shareBody, contains('_completeMediaDownload(cancelToken);'));

    final downloadBody = _methodBody(
      mediaSource,
      'Future<List<int>> _downloadImageBytesImpl(',
    );
    expect(mediaSource, contains('CancelToken? cancelToken'));
    expect(downloadBody, contains('downloadFileBytes('));
    expect(downloadBody, contains('cancelToken: cancelToken'));
  });
}
