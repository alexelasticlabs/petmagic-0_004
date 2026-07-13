import 'package:petmagic_mobile/core/operations/request_cancellation.dart';

/// Owns cancellation tokens for mutually exclusive profile operations.
class ProfileRequestTracker {
  RequestCancellation? _avatarUpload;
  RequestCancellation? _initialize;
  RequestCancellation? _auth;
  RequestCancellation? _profileMutation;

  RequestCancellation? tryStartAvatarUpload() {
    if (_avatarUpload != null) {
      return null;
    }

    return _avatarUpload = RequestCancellation();
  }

  RequestCancellation startInitialize() {
    cancelInitialize();
    return _initialize = RequestCancellation();
  }

  RequestCancellation startAuth() {
    cancelAuth();
    return _auth = RequestCancellation();
  }

  RequestCancellation startProfileMutation() {
    cancelProfileMutation();
    return _profileMutation = RequestCancellation();
  }

  bool ownsAuth(RequestCancellation cancelToken) =>
      identical(_auth, cancelToken);

  void cancelAvatarUpload() {
    _cancel(_avatarUpload, 'profile_avatar_upload_cancelled');
    _avatarUpload = null;
  }

  void cancelInitialize() {
    _cancel(_initialize, 'profile_initialize_cancelled');
    _initialize = null;
  }

  void cancelAuth() {
    _cancel(_auth, 'profile_auth_cancelled');
    _auth = null;
  }

  void cancelProfileMutation() {
    _cancel(_profileMutation, 'profile_mutation_cancelled');
    _profileMutation = null;
  }

  void clearAvatarUpload(RequestCancellation cancelToken) {
    if (identical(_avatarUpload, cancelToken)) {
      _avatarUpload = null;
    }
  }

  void clearInitialize(RequestCancellation cancelToken) {
    if (identical(_initialize, cancelToken)) {
      _initialize = null;
    }
  }

  void clearAuth(RequestCancellation cancelToken) {
    if (identical(_auth, cancelToken)) {
      _auth = null;
    }
  }

  void clearProfileMutation(RequestCancellation cancelToken) {
    if (identical(_profileMutation, cancelToken)) {
      _profileMutation = null;
    }
  }

  void cancelAll() {
    cancelInitialize();
    cancelAvatarUpload();
    cancelAuth();
    cancelProfileMutation();
  }

  static void _cancel(RequestCancellation? token, String reason) {
    if (token != null && !token.isCancelled) {
      token.cancel(reason);
    }
  }
}
