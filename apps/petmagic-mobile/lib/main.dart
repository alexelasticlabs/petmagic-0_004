import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/app.dart';
import 'package:petmagic_mobile/app/composition/mobile_provider_overrides.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_crash_reporter.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/decoded_image_cache_budget.dart';
import 'package:petmagic_mobile/shared/files/temp_media_cleanup.dart';

const bool _skipFirebase = bool.fromEnvironment('PETMAGIC_SKIP_FIREBASE');

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initializeFirebase();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  AppConfig.validateReleaseConfiguration();
  _installGlobalErrorHandlers();
  configureDecodedImageCacheBudget();

  await runZonedGuarded<Future<void>>(
    () async {
      assert(() {
        debugPaintBaselinesEnabled = false;
        debugPaintSizeEnabled = false;
        debugPaintPointersEnabled = false;
        return true;
      }());

      TempMediaCleanup.scheduleTtlSweep();
      if (!_skipFirebase) {
        _registerFirebaseMessagingBackgroundHandler();
        unawaited(_configureFirebaseMessagingAsync());
      }
      AppLogger.info(
        feature: 'Startup',
        operation: 'app_startup',
        message: 'Application startup completed',
      );
      runApp(
        ProviderScope(
          overrides: mobileProviderOverrides,
          child: const PetMagicApp(),
        ),
      );
    },
    (error, stackTrace) {
      AppCrashReporter.recordFatal(
        error: error,
        stackTrace: stackTrace,
        reason: 'zoned_guarded_error',
      );
      AppLogger.error(
        feature: 'App',
        operation: 'zoned_guarded_error',
        message: 'Unhandled zoned error',
        error: error,
        stackTrace: stackTrace,
        reportToCrashlytics: false,
      );
    },
  );
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    AppCrashReporter.recordFatal(
      error: details.exception,
      stackTrace: details.stack ?? StackTrace.current,
      reason: 'flutter_framework_error',
    );
    AppLogger.error(
      feature: 'App',
      operation: 'flutter_error',
      message: 'Unhandled Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
      reportToCrashlytics: false,
    );
  };
  ErrorWidget.builder = _buildSafeErrorWidget;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppCrashReporter.recordFatal(
      error: error,
      stackTrace: stackTrace,
      reason: 'platform_dispatcher_error',
    );
    AppLogger.error(
      feature: 'App',
      operation: 'platform_dispatcher_error',
      message: 'Unhandled platform error',
      error: error,
      stackTrace: stackTrace,
      reportToCrashlytics: false,
    );
    return true;
  };
}

Future<void> _configureFirebaseMessagingAsync() async {
  if (!await _initializeFirebase()) {
    return;
  }
}

void _registerFirebaseMessagingBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

Widget _buildSafeErrorWidget(FlutterErrorDetails details) {
  AppLogger.error(
    feature: 'App',
    operation: 'error_widget',
    message: 'Widget build failed',
    error: details.exception,
    stackTrace: details.stack,
    reportToCrashlytics: false,
  );

  if (kDebugMode) {
    return ErrorWidget.withDetails(message: details.exceptionAsString());
  }

  return const _ProductionErrorFallback();
}

AppLocalizations _resolveErrorFallbackLocalizations() {
  final locale = PlatformDispatcher.instance.locale;
  for (final supportedLocale in AppLocalizations.supportedLocales) {
    if (supportedLocale.languageCode == locale.languageCode) {
      return lookupAppLocalizations(supportedLocale);
    }
  }

  return lookupAppLocalizations(const Locale('en'));
}

Future<bool> _initializeFirebase() async {
  if (_skipFirebase) {
    return false;
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await AppCrashReporter.initialize();
    AppCrashReporter.runStagingProbeIfRequested();
    return true;
  } catch (error, stackTrace) {
    AppLogger.error(
      feature: 'Startup',
      operation: 'firebase_initialize',
      message: 'Firebase initialization failed',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}

class _ProductionErrorFallback extends StatelessWidget {
  const _ProductionErrorFallback();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: const ColoredBox(
        color: Color(0xFFF8F5F0),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: _ProductionErrorFallbackMessage(),
          ),
        ),
      ),
    );
  }
}

class _ProductionErrorFallbackMessage extends StatelessWidget {
  const _ProductionErrorFallbackMessage();

  @override
  Widget build(BuildContext context) {
    final localizations = _resolveErrorFallbackLocalizations();
    return Text(
      localizations.appUnexpectedErrorFallback,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF302A25),
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );
  }
}
