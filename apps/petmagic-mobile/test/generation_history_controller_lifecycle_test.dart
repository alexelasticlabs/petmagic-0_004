import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generation history controller guards async state updates after dispose',
    () {
      final source = File(
        'lib/features/templates/presentation/generation_history_controller.dart',
      ).readAsStringSync();

      final buildBody = _methodBody(source, 'build');
      final loadBody = _methodBody(source, 'load');
      final autoRefreshBody = _methodBody(source, '_scheduleNextAutoRefresh');
      final offlineBannerBody = _methodBody(
        source,
        '_scheduleOfflineBannerHide',
      );
      final unreadBody = _methodBody(source, 'refreshUnreadCount');
      final markReadBody = _methodBody(source, 'markRead');
      final deleteBody = _methodBody(source, 'deleteGeneration');
      final realtimeBody = _methodBody(source, '_resumeRealtimeIfNeeded');
      final eventBody = _methodBody(source, '_handleRealtimeEvent');

      expect(buildBody, contains('_isScreenVisible = false;'));
      expect(buildBody, contains('if (!ref.mounted)'));
      expect(buildBody, isNot(contains('_startAutoRefresh();')));
      expect(buildBody, contains('if (!_isScreenVisible)'));
      expect(loadBody, contains('if (!ref.mounted)'));
      expect(
        autoRefreshBody,
        contains('if (!ref.mounted || !_isScreenVisible)'),
      );
      expect(autoRefreshBody, contains('if (!ref.mounted)'));
      expect(offlineBannerBody, contains('if (!ref.mounted)'));
      expect(unreadBody, contains('if (!ref.mounted'));
      expect(unreadBody, contains('!_isScreenVisible'));
      expect(unreadBody, contains('_isLoadInFlight'));
      expect(
        markReadBody.indexOf('state = state.copyWith'),
        lessThan(markReadBody.indexOf('await _repository.markGenerationRead')),
      );
      expect(
        markReadBody.substring(
          markReadBody.indexOf('await _repository.markGenerationRead'),
        ),
        isNot(contains('state =')),
      );
      expect(deleteBody, contains('if (!ref.mounted)'));
      final markDeletedIndex = deleteBody.indexOf(
        'await _galleryStore.markDeletedLocally',
      );
      final guardAfterTombstoneIndex = deleteBody.indexOf(
        'if (!ref.mounted)',
        markDeletedIndex,
      );
      final serverDeleteIndex = deleteBody.indexOf(
        'await _repository.deleteGeneration',
      );
      final guardAfterServerDeleteIndex = deleteBody.indexOf(
        'if (!ref.mounted)',
        serverDeleteIndex,
      );
      final clearPendingIndex = deleteBody.indexOf(
        'await _galleryStore.clearPendingServerDelete',
      );
      expect(markDeletedIndex, isNonNegative);
      expect(guardAfterTombstoneIndex, isNonNegative);
      expect(serverDeleteIndex, isNonNegative);
      expect(guardAfterServerDeleteIndex, isNonNegative);
      expect(clearPendingIndex, isNonNegative);
      expect(markDeletedIndex, lessThan(guardAfterTombstoneIndex));
      expect(guardAfterTombstoneIndex, lessThan(serverDeleteIndex));
      expect(serverDeleteIndex, lessThan(guardAfterServerDeleteIndex));
      expect(guardAfterServerDeleteIndex, lessThan(clearPendingIndex));
      expect(realtimeBody, contains('if (!ref.mounted || !_isScreenVisible)'));
      expect(realtimeBody, contains('if (!ref.mounted)'));
      expect(eventBody, contains('if (!ref.mounted || !_isScreenVisible)'));
    },
  );
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    '(?:Future<[^>]+>|void|GenerationHistoryState)\\s+${RegExp.escape(methodName)}\\s*\\(',
  ).firstMatch(source);
  if (methodMatch == null) {
    throw StateError('Method $methodName not found.');
  }

  final parameterStart = source.indexOf('(', methodMatch.start);
  if (parameterStart < 0) {
    throw StateError('Method $methodName parameters not found.');
  }

  final parameterEnd = _matchingCloseParen(source, parameterStart);
  final openBraceIndex = source.indexOf('{', parameterEnd);
  if (openBraceIndex < 0) {
    throw StateError('Method $methodName body not found.');
  }

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
