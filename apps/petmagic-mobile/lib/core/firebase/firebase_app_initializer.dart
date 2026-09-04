import 'package:firebase_core/firebase_core.dart';

typedef FirebaseInitializedCheck = bool Function();
typedef FirebaseInitializeAction = Future<void> Function();

const firebaseInitializationEnabled = !bool.fromEnvironment(
  'PETMAGIC_SKIP_FIREBASE',
);

final firebaseAppInitializer = FirebaseAppInitializer(
  enabled: firebaseInitializationEnabled,
);

/// Coalesces concurrent Firebase initialization requests across app features.
///
/// A failed attempt is deliberately not cached so a later lifecycle retry can
/// recover without restarting the application.
final class FirebaseAppInitializer {
  FirebaseAppInitializer({
    this.enabled = true,
    FirebaseInitializedCheck? isInitialized,
    FirebaseInitializeAction? initialize,
  }) : _isInitialized = isInitialized ?? (() => Firebase.apps.isNotEmpty),
       _initialize =
           initialize ??
           (() async {
             await Firebase.initializeApp();
           });

  final FirebaseInitializedCheck _isInitialized;
  final FirebaseInitializeAction _initialize;
  final bool enabled;
  Future<bool>? _inFlight;

  bool get isInitialized => enabled && _isInitialized();

  Future<bool> ensureInitialized() {
    if (!enabled) {
      return Future<bool>.value(false);
    }
    if (isInitialized) {
      return Future<bool>.value(true);
    }

    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final task = _initializeAndClear();
    _inFlight = task;
    return task;
  }

  Future<bool> _initializeAndClear() async {
    try {
      if (!isInitialized) {
        await _initialize();
      }
      return isInitialized;
    } finally {
      _inFlight = null;
    }
  }
}
