import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petmagic_mobile/app/app.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/shared/files/temp_media_cleanup.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initializeFirebase();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  _installGlobalErrorHandlers();

  await runZonedGuarded<Future<void>>(
    () async {
      assert(() {
        debugPaintBaselinesEnabled = false;
        debugPaintSizeEnabled = false;
        debugPaintPointersEnabled = false;
        return true;
      }());

      TempMediaCleanup.scheduleTtlSweep();
      _registerFirebaseMessagingBackgroundHandler();
      unawaited(_configureFirebaseMessagingAsync());
      AppLogger.info(
        feature: 'Startup',
        operation: 'app_startup',
        message: 'Application startup completed',
      );
      runApp(const ProviderScope(child: PetMagicApp()));
    },
    (error, stackTrace) {
      AppLogger.error(
        feature: 'App',
        operation: 'zoned_guarded_error',
        message: 'Unhandled zoned error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    AppLogger.error(
      feature: 'App',
      operation: 'flutter_error',
      message: 'Unhandled Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  ErrorWidget.builder = _buildSafeErrorWidget;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error(
      feature: 'App',
      operation: 'platform_dispatcher_error',
      message: 'Unhandled platform error',
      error: error,
      stackTrace: stackTrace,
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
  );

  if (kDebugMode) {
    return ErrorWidget.withDetails(message: details.exceptionAsString());
  }

  return const _ProductionErrorFallback();
}

Future<bool> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    return true;
  }

  try {
    await Firebase.initializeApp();
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
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFF8F5F0),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF302A25),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
