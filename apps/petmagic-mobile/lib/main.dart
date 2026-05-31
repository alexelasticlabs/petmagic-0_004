import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/app.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/shared/files/temp_media_cleanup.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initializeFirebase();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    AppLogger.error(
      feature: 'App',
      operation: 'flutter_error',
      message: details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
  };
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

  await runZonedGuarded<Future<void>>(
    () async {
      assert(() {
        debugPaintBaselinesEnabled = false;
        debugPaintSizeEnabled = false;
        debugPaintPointersEnabled = false;
        return true;
      }());

      TempMediaCleanup.scheduleTtlSweep();

      if (await _initializeFirebase()) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
      }
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
