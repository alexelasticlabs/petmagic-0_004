import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';

const _safeProfileFeedbackKeys = <String>[
  'auth.password_mismatch',
  'auth.password_policy_invalid',
  'auth.password_too_short',
  'auth.accept_terms_required',
  'auth.legal_documents_unavailable',
  'auth.legal_acceptance_required',
  'auth.password_reset_code_invalid',
  'auth.email_code_invalid',
  'auth.email_not_confirmed',
  'auth.external_cancelled',
  'auth.external_callback_failed',
  'auth.external_launch_failed',
  'auth.external_timed_out',
  'auth.external_ticket_invalid',
  'auth.external_already_linked',
  'auth.external_provider_already_linked',
  'auth.external_email_missing',
  'auth.external_email_not_verified',
  'auth.external_not_configured',
  'auth.external_token_invalid',
  'auth.external_invalid',
  'auth.sign_in_required',
  'auth.session_expired',
  'auth.invalid_refresh',
  'auth.login_failed',
  'auth.registration_failed',
  'auth.password_reset_request_failed',
  'auth.password_reset_failed',
  'auth.email_verification_failed',
  'auth.email_verification_resend_failed',
  'auth.request_failed',
  'network.unavailable',
  'network.timeout',
  'templates.network_unavailable',
  'profile.action_failed',
];

const _safeProfileSuccessKeys = <String>[
  'logout',
  'auth.registration_pending_verification',
  'auth.password_reset_code_sent',
  'auth.password_reset_success',
  'profile.account_deleted',
];

String? normalizeProfileFeedbackKey(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();
  for (final key in _safeProfileFeedbackKeys) {
    if (lower == key || lower.contains(key)) {
      return key;
    }
  }

  return null;
}

String? normalizeProfileSuccessKey(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();
  for (final key in _safeProfileSuccessKeys) {
    if (lower == key || lower.contains(key)) {
      return key;
    }
  }

  return null;
}

String mapProfileFeedbackMessage(String raw, AppLocalizations text) {
  switch (normalizeProfileFeedbackKey(raw) ?? raw.trim().toLowerCase()) {
    case 'auth.password_mismatch':
      return text.authPasswordMismatch;
    case 'auth.password_policy_invalid':
      return text.authPasswordPolicyInvalid;
    case 'auth.password_too_short':
      return text.authPasswordTooShort;
    case 'auth.accept_terms_required':
      return text.authAcceptTermsRequired;
    case 'auth.legal_documents_unavailable':
      return text.authLegalUnavailable;
    case 'auth.legal_acceptance_required':
      return text.profileLegalAcceptanceRequired;
    case 'auth.password_reset_code_invalid':
      return text.authPasswordResetCodeInvalid;
    case 'auth.email_code_invalid':
      return text.authPasswordResetCodeInvalid;
    case 'auth.email_not_confirmed':
      return text.profileEmailPending;
    case 'auth.external_cancelled':
      return text.authExternalCancelled;
    case 'auth.external_callback_failed':
      return text.authExternalCallbackFailed;
    case 'auth.external_launch_failed':
      return text.authExternalLaunchFailed;
    case 'auth.external_timed_out':
      return text.authExternalTimedOut;
    case 'auth.external_ticket_invalid':
      return text.authExternalSessionExpired;
    case 'auth.external_already_linked':
    case 'auth.external_provider_already_linked':
      return text.authExternalFailed;
    case 'auth.external_email_missing':
    case 'auth.external_email_not_verified':
      return text.authExternalFailed;
    case 'auth.external_not_configured':
    case 'auth.external_token_invalid':
    case 'auth.external_invalid':
      return text.authExternalFailed;
    case 'auth.sign_in_required':
      return text.authSignInRequired;
    case 'auth.session_expired':
      return text.authSessionExpired;
    case 'auth.invalid_refresh':
      return text.authSessionExpired;
    case 'auth.login_failed':
      return text.authLoginFailed;
    case 'auth.registration_failed':
      return text.authRegistrationFailed;
    case 'auth.password_reset_request_failed':
      return text.authPasswordResetRequestFailed;
    case 'auth.password_reset_failed':
      return text.authPasswordResetFailed;
    case 'auth.email_verification_failed':
      return text.authPasswordResetFailed;
    case 'auth.email_verification_resend_failed':
      return text.authRequestFailed;
    case 'auth.request_failed':
      return text.authRequestFailed;
    case 'network.unavailable':
    case 'network.timeout':
    case 'templates.network_unavailable':
      return text.templateFlowNetworkError;
    case 'profile.action_failed':
      return text.profileActionFailed;
    default:
      return text.authRequestFailed;
  }
}

String? mapProfileSuccessMessage(String raw, AppLocalizations text) {
  switch (normalizeProfileSuccessKey(raw)) {
    case 'logout':
      return text.profileSignedOut;
    case 'auth.registration_pending_verification':
      return null;
    case 'auth.password_reset_code_sent':
      return text.authPasswordResetCodeSent;
    case 'auth.password_reset_success':
      return text.authPasswordResetSuccess;
    case 'profile.account_deleted':
      return text.profileAccountDeleted;
    default:
      return null;
  }
}
