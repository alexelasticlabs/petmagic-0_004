import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

typedef BaseUrlHealthProbe = Future<bool> Function(String baseUrl);
typedef BaseUrlProbeFailure =
    void Function(String baseUrl, Object error, StackTrace stackTrace);

/// Performs bounded concurrent health checks. Candidate ordering and endpoint
/// persistence remain responsibilities of [ApiBaseUrlResolver].
final class ApiBaseUrlHealthChecker {
  const ApiBaseUrlHealthChecker({
    this.healthProbe,
    this.onProbeFailure,
    this.workerCount = 24,
    this.probeBudget = const Duration(seconds: 8),
    this.connectTimeout = const Duration(milliseconds: 350),
    this.readTimeout = const Duration(milliseconds: 650),
  });

  final BaseUrlHealthProbe? healthProbe;
  final BaseUrlProbeFailure? onProbeFailure;
  final int workerCount;
  final Duration probeBudget;
  final Duration connectTimeout;
  final Duration readTimeout;

  Future<String?> findReachable(List<String> candidates) async {
    if (candidates.isEmpty) {
      return null;
    }

    final queue = Queue<String>.from(candidates);
    final completer = Completer<String?>();
    var runningWorkers = candidates.length < workerCount
        ? candidates.length
        : workerCount;

    Future<void> runWorker() async {
      try {
        while (!completer.isCompleted && queue.isNotEmpty) {
          final candidate = queue.removeFirst();
          if (await _probe(candidate) && !completer.isCompleted) {
            completer.complete(candidate);
            return;
          }
        }
      } finally {
        runningWorkers--;
        if (runningWorkers == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }
    }

    for (var index = 0; index < runningWorkers; index++) {
      unawaited(runWorker());
    }
    return completer.future.timeout(probeBudget, onTimeout: () => null);
  }

  Future<bool> _probe(String baseUrl) async {
    final override = healthProbe;
    if (override != null) {
      return override(baseUrl);
    }

    final httpClient = HttpClient()..connectionTimeout = connectTimeout;
    try {
      final request = await httpClient.getUrl(Uri.parse('$baseUrl/health'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-PetMagic-Client', 'mobile-flutter');
      if (kDebugMode) {
        request.headers.set('ngrok-skip-browser-warning', 'true');
        request.headers.set('Bypass-Tunnel-Reminder', 'true');
      }
      final response = await request.close().timeout(readTimeout);
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (error, stackTrace) {
      onProbeFailure?.call(baseUrl, error, stackTrace);
      return false;
    } finally {
      httpClient.close(force: true);
    }
  }
}
