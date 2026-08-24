import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network status async bootstrap and timers stop after disposal', () {
    final source = File(
      'lib/core/network/network_status_controller.dart',
    ).readAsStringSync();

    final onDisposeBody = _methodBody(source, 'build');
    final bootstrapBody = _methodBody(source, '_bootstrapSafely');
    final bootstrapSetupBody = _methodBody(source, '_bootstrap');
    final refreshBody = _methodBody(source, '_refreshFromCurrentConnectivity');
    final connectivityBody = _methodBody(source, '_onConnectivityChanged');
    final applyBody = _methodBody(source, '_applyConnectionState');
    final offlineProbeBody = _methodBody(source, '_startOfflineProbe');
    final scheduleProbeBody = _methodBody(source, '_scheduleNextOfflineProbe');
    final restoreBannerBody = _methodBody(source, '_scheduleRestoreBannerHide');
    final internetProbeBody = _methodBody(source, '_probeInternet');

    expect(onDisposeBody, contains('_started = false;'));
    expect(onDisposeBody, contains('_subscription?.cancel();'));
    expect(onDisposeBody, contains('_stopOfflineProbe();'));
    expect(onDisposeBody, contains('_restoreBannerTimer?.cancel();'));

    expect(bootstrapBody, contains('if (!ref.mounted)'));
    expect(bootstrapSetupBody, contains('if (!ref.mounted)'));
    expect(refreshBody, contains('if (!ref.mounted)'));
    expect(connectivityBody, contains('if (!ref.mounted)'));
    expect(applyBody, contains('if (!ref.mounted)'));
    expect(
      applyBody,
      contains('_currentOfflineProbeInterval = _offlineProbeInterval;'),
    );

    expect(
      offlineProbeBody,
      contains('_scheduleNextOfflineProbe(_currentOfflineProbeInterval);'),
    );
    expect(scheduleProbeBody, contains('Timer(delay, () async {'));
    expect(
      scheduleProbeBody,
      contains('if (!ref.mounted || state.hasInternet)'),
    );
    expect(
      scheduleProbeBody,
      contains('_currentOfflineProbeInterval.inSeconds * 2'),
    );
    expect(scheduleProbeBody, contains('_offlineProbeMaxInterval.inSeconds'));
    expect(restoreBannerBody, contains('Timer('));
    expect(restoreBannerBody, contains('if (!ref.mounted)'));
    expect(internetProbeBody, contains('ApiBaseUrlHealthChecker'));
    expect(internetProbeBody, contains('AppConfig.apiBaseUrls'));
    expect(source, isNot(contains('one.one.one.one')));
  });
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:NetworkStatusState|Future<[^>]+>|void)\s+' + methodName + r'\s*\(',
  ).firstMatch(source);
  if (methodMatch == null) {
    fail('Method $methodName was not found.');
  }

  final openBraceIndex = _methodOpenBraceIndex(source, methodMatch);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
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

  fail('Method $methodName body did not close.');
}

int _methodOpenBraceIndex(String source, RegExpMatch methodMatch) {
  var parenDepth = 0;
  for (var index = methodMatch.end - 1; index < source.length; index++) {
    final char = source[index];
    if (char == '(') {
      parenDepth++;
      continue;
    }
    if (char == ')') {
      parenDepth--;
      continue;
    }
    if (char == '{' && parenDepth == 0) {
      return index;
    }
  }

  return -1;
}
