import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';

bool isLegalAcceptanceRequiredError(String? raw) {
  return _containsErrorCode(raw, 'auth.legal_acceptance_required');
}

bool isAuthSignInRequiredError(String? raw) {
  return _containsErrorCode(raw, 'auth.sign_in_required');
}

bool isAuthSessionExpiredError(String? raw) {
  return _containsErrorCode(raw, 'auth.session_expired') ||
      _containsErrorCode(raw, 'auth.invalid_refresh');
}

bool isCommonAuthFeedbackError(String? raw) {
  return isLegalAcceptanceRequiredError(raw) ||
      isAuthSignInRequiredError(raw) ||
      isAuthSessionExpiredError(raw);
}

String? mapCommonAuthFeedbackMessage(
  AppLocalizations text,
  String? raw, {
  bool preferAuthRequiredMessage = false,
}) {
  if (isLegalAcceptanceRequiredError(raw)) {
    return text.profileLegalAcceptanceRequired;
  }

  if (isAuthSignInRequiredError(raw)) {
    return preferAuthRequiredMessage
        ? text.authRequiredMessage
        : text.authSignInRequired;
  }

  if (isAuthSessionExpiredError(raw)) {
    return text.authSessionExpired;
  }

  return null;
}

bool _containsErrorCode(String? raw, String code) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) {
    return false;
  }

  return value.contains(code);
}
