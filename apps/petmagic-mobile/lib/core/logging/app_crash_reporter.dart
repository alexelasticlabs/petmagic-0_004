import 'dart:async';
import 'dart:convert';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';

class AppCrashReporter {
  const AppCrashReporter._();

  static FirebaseCrashlytics? _crashlytics;

  static Future<void> initialize() async {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    await crashlytics.setCustomKey('app_environment', AppConfig.appEnvironment);
    await crashlytics.setCustomKey(
      'app_package_name',
      AppConfig.appPackageName,
    );
    _crashlytics = crashlytics;
  }

  static void recordNonFatal({
    required String errorType,
    required String reason,
    required String message,
    required Map<String, Object> context,
    StackTrace? stackTrace,
  }) {
    _record(
      errorType: errorType,
      reason: reason,
      message: message,
      context: context,
      stackTrace: stackTrace,
      fatal: false,
    );
  }

  static void recordFatal({
    required Object error,
    required StackTrace stackTrace,
    required String reason,
  }) {
    _record(
      errorType: error.runtimeType.toString(),
      reason: reason,
      message: 'Unhandled application error',
      context: const {},
      stackTrace: stackTrace,
      fatal: true,
    );
  }

  static void runStagingProbeIfRequested() {
    const probeEnabled = bool.fromEnvironment(
      'PETMAGIC_CRASHLYTICS_STAGING_PROBE',
    );
    if (!probeEnabled || AppConfig.appEnvironment != 'staging') {
      return;
    }
    _record(
      errorType: 'CrashlyticsStagingProbe',
      reason: 'staging_release_probe',
      message: 'Sanitized staging Crashlytics probe',
      context: const {'probe': true},
      stackTrace: StackTrace.current,
      fatal: false,
    );
  }

  static void _record({
    required String errorType,
    required String reason,
    required String message,
    required Map<String, Object> context,
    required bool fatal,
    StackTrace? stackTrace,
  }) {
    final crashlytics = _crashlytics;
    if (crashlytics == null || kDebugMode) {
      return;
    }

    unawaited(
      crashlytics.recordError(
        _SanitizedCrashException(errorType),
        stackTrace ?? StackTrace.current,
        reason: reason,
        information: <Object>[
          message,
          if (context.isNotEmpty) jsonEncode(context),
        ],
        fatal: fatal,
      ),
    );
  }
}

class _SanitizedCrashException implements Exception {
  const _SanitizedCrashException(this.errorType);

  final String errorType;

  @override
  String toString() => 'SanitizedCrashException($errorType)';
}
