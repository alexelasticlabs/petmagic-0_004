import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generation history controller guards async state updates after dispose', () {
    final source = [
      'lib/features/templates/application/generation_history_controller.dart',
      'lib/features/templates/application/generation_history_controller_cache.part.dart',
      'lib/features/templates/application/generation_history_controller_lifecycle.part.dart',
      'lib/features/templates/application/generation_history_controller_sync.part.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    final buildBody = _methodBody(source, 'build');
    final loadBody = _methodBody(source, '_load');
    final autoRefreshBody = _methodBody(source, '_scheduleNextAutoRefresh');
    final offlineBannerBody = _methodBody(source, '_scheduleOfflineBannerHide');
    final unreadBody = _methodBody(source, '_refreshUnreadCount');
    final markReadBody = _methodBody(source, '_markRead');
    final deleteBody = _methodBody(source, '_deleteGeneration');
    final realtimeBody = _methodBody(source, '_resumeRealtimeIfNeeded');
    final eventBody = _methodBody(source, '_handleRealtimeEvent');
    final refetchBody = _methodBody(source, '_refetchRealtimeGeneration');
    final pauseRealtimeBody = _methodBody(source, '_pauseRealtime');
    final cancelRealtimeBody = _methodBody(
      source,
      '_cancelActiveRealtimeRefetches',
    );

    expect(buildBody, contains('_isScreenVisible = false;'));
    expect(buildBody, contains('if (!ref.mounted)'));
    expect(buildBody, isNot(contains('_startAutoRefresh();')));
    expect(buildBody, contains('if (!_isScreenVisible)'));
    expect(buildBody, contains('networkStatusControllerProvider'));
    expect(buildBody, contains('appLaunchControllerProvider'));
    expect(buildBody, contains('_handleAuthStatusChanged'));
    expect(
      buildBody,
      contains('(_, hasInternet) => _handleNetworkStatusChanged(hasInternet)'),
    );
    expect(loadBody, contains('!ref.mounted || !_isAuthenticated'));
    expect(autoRefreshBody, contains('!_isAuthenticated'));
    expect(autoRefreshBody, contains('if (!ref.mounted)'));
    expect(autoRefreshBody, contains('!_hasInternet'));
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
    expect(deleteBody, contains('!ref.mounted || !_isAuthenticated'));
    final markDeletedIndex = deleteBody.indexOf(
      'await _galleryStore.markDeletedLocally',
    );
    final guardAfterTombstoneIndex = deleteBody.indexOf(
      '!ref.mounted || !_isAuthenticated',
      markDeletedIndex,
    );
    final serverDeleteIndex = deleteBody.indexOf(
      'await _repository.deleteGeneration',
    );
    final guardAfterServerDeleteIndex = deleteBody.indexOf(
      '!ref.mounted || !_isAuthenticated',
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
    expect(realtimeBody, contains('!_isAuthenticated'));
    expect(realtimeBody, contains('if (!ref.mounted)'));
    expect(realtimeBody, contains('!_hasInternet'));
    expect(realtimeBody, contains('unawaited(realtimeClient.disconnect())'));
    expect(eventBody, contains('!_isAuthenticated'));
    expect(eventBody, contains("AppLogger.warn("));
    expect(eventBody, contains("feature: 'Templates.GenerationHistory'"));
    expect(eventBody, contains("operation: 'realtime_event_parse'"));
    expect(eventBody, isNot(contains('} catch (_) {}')));
    expect(refetchBody, contains('!_isAuthenticated'));
    expect(
      refetchBody,
      contains(
        'if (_activeRealtimeRefetchRequestCancellations.containsKey(generationId))',
      ),
    );
    expect(refetchBody, contains('final cancelToken = RequestCancellation();'));
    expect(
      refetchBody,
      contains(
        '_activeRealtimeRefetchRequestCancellations[generationId] = cancelToken',
      ),
    );
    expect(refetchBody, contains('cancelToken: cancelToken'));
    expect(refetchBody, contains('cancelToken.isCancelled'));
    expect(refetchBody, contains('on RequestCancelledException'));
    expect(refetchBody, contains('return;'));
    expect(
      refetchBody,
      contains(
        '_activeRealtimeRefetchRequestCancellations.remove(generationId)',
      ),
    );
    expect(
      pauseRealtimeBody,
      contains(
        "_cancelActiveRealtimeRefetches('generation_history_realtime_paused')",
      ),
    );
    expect(
      cancelRealtimeBody,
      contains('_activeRealtimeRefetchRequestCancellations.clear()'),
    );
    expect(cancelRealtimeBody, contains('cancelToken.cancel(reason)'));
  });
}

String _methodBody(String source, String methodName) {
  final methodMatches = RegExp(
    '(?:Future(?:<[^>]+>)?|void|GenerationHistoryState)\\s+${RegExp.escape(methodName)}\\s*\\(',
  ).allMatches(source);
  for (final methodMatch in methodMatches) {
    final parameterStart = source.indexOf('(', methodMatch.start);
    if (parameterStart < 0) {
      continue;
    }

    final parameterEnd = _matchingCloseParen(source, parameterStart);
    final statementEnd = source.indexOf(';', parameterEnd);
    final openBraceIndex = source.indexOf('{', parameterEnd);
    if (openBraceIndex < 0) {
      continue;
    }
    if (statementEnd >= 0 && statementEnd < openBraceIndex) {
      continue;
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
  }

  throw StateError('Method $methodName implementation not found.');
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
