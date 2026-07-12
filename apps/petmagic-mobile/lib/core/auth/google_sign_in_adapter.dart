import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

@immutable
class GoogleSignInCredential {
  const GoogleSignInCredential({required this.email, required this.idToken});

  final String email;
  final String? idToken;
}

class GoogleSignInConfigurationException implements Exception {
  const GoogleSignInConfigurationException();
}

abstract interface class GoogleSignInAdapter {
  Future<GoogleSignInCredential> authenticate({String? serverClientId});

  Future<void> disconnect();

  Future<void> signOut();
}

class PluginGoogleSignInAdapter implements GoogleSignInAdapter {
  PluginGoogleSignInAdapter._();

  static final PluginGoogleSignInAdapter shared = PluginGoogleSignInAdapter._();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _initialization;
  String? _initializedServerClientId;
  bool _hasInitializationConfiguration = false;

  @override
  Future<GoogleSignInCredential> authenticate({String? serverClientId}) async {
    await _ensureInitialized(serverClientId);
    final account = await _googleSignIn.authenticate();
    return GoogleSignInCredential(
      email: account.email,
      idToken: account.authentication.idToken,
    );
  }

  @override
  Future<void> disconnect() async {
    if (_initialization == null) {
      return;
    }
    await _initialization;
    await _googleSignIn.disconnect();
  }

  @override
  Future<void> signOut() async {
    if (_initialization == null) {
      return;
    }
    await _initialization;
    await _googleSignIn.signOut();
  }

  Future<void> _ensureInitialized(String? serverClientId) {
    if (_hasInitializationConfiguration &&
        _initializedServerClientId != serverClientId) {
      throw const GoogleSignInConfigurationException();
    }

    _hasInitializationConfiguration = true;
    _initializedServerClientId = serverClientId;
    return _initialization ??= _googleSignIn.initialize(
      serverClientId: serverClientId,
    );
  }
}
