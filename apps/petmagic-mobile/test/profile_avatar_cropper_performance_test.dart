import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'avatar cropper keeps CPU-heavy image processing off the UI isolate',
    () {
      final source = File(
        'lib/features/profile/presentation/profile_avatar_cropper_page.dart',
      ).readAsStringSync();

      expect(source, contains("import 'package:flutter/foundation.dart';"));
      expect(source, contains('compute(_prepareAvatarPreview, bytes)'));
      expect(source, contains('compute(_cropAvatarImage'));

      final loadSourceImageBody = _methodBody(source, '_loadSourceImage');
      expect(loadSourceImageBody, isNot(contains('img.decodeImage')));
      expect(loadSourceImageBody, isNot(contains('img.encodeJpg')));

      final saveCropBody = _methodBody(source, '_saveCrop');
      expect(saveCropBody, isNot(contains('img.decodeImage')));
      expect(saveCropBody, isNot(contains('img.copyCrop')));
      expect(saveCropBody, isNot(contains('img.copyResize')));
      expect(saveCropBody, isNot(contains('img.encodeJpg')));

      final prepareHelperBody = _functionBody(source, '_prepareAvatarPreview');
      expect(prepareHelperBody, contains('img.decodeImage'));
      expect(prepareHelperBody, contains('img.encodeJpg'));

      final cropHelperBody = _functionBody(source, '_cropAvatarImage');
      expect(cropHelperBody, contains('img.decodeImage'));
      expect(cropHelperBody, contains('img.copyCrop'));
      expect(cropHelperBody, contains('img.copyResize'));
      expect(cropHelperBody, contains('img.encodeJpg'));
    },
  );
}

String _methodBody(String source, String methodName) {
  final methodIndex = source.indexOf(RegExp('\\b$methodName\\b'));
  if (methodIndex < 0) {
    fail('Method $methodName was not found.');
  }

  final asyncBodyIndex = source.indexOf('async {', methodIndex);
  final openBraceIndex = asyncBodyIndex < 0
      ? source.indexOf('{', methodIndex)
      : source.indexOf('{', asyncBodyIndex);
  return _bodyFromOpenBrace(source, openBraceIndex, 'Method $methodName');
}

String _functionBody(String source, String functionName) {
  final functionIndex = source.indexOf(RegExp('\\n[^\\n]+\\b$functionName\\('));
  if (functionIndex < 0) {
    fail('Function $functionName was not found.');
  }

  return _bodyFromOpenBrace(
    source,
    source.indexOf('{', functionIndex),
    'Function $functionName',
  );
}

String _bodyFromOpenBrace(String source, int openBraceIndex, String label) {
  if (openBraceIndex < 0) {
    fail('$label has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }

    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('$label body did not close.');
}
