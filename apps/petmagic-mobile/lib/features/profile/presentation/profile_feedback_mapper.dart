import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';

String mapProfileFeedbackMessage(String raw, AppLocalizations text) {
  switch (raw) {
    case 'auth.password_mismatch':
      return text.authPasswordMismatch;
    case 'auth.password_too_short':
      return text.authPasswordTooShort;
    case 'auth.accept_terms_required':
      return text.authAcceptTermsRequired;
    case 'auth.legal_documents_unavailable':
      return text.authLegalUnavailable;
    case 'auth.password_reset_code_invalid':
      return text.authPasswordResetCodeInvalid;
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
    case 'auth.external_not_configured':
    case 'auth.external_token_invalid':
    case 'auth.external_invalid':
      return text.authExternalFailed;
    case 'auth.sign_in_required':
      return text.authSignInRequired;
    case 'auth.session_expired':
      return text.authSessionExpired;
    case 'auth.login_failed':
      return text.authLoginFailed;
    case 'auth.registration_failed':
      return text.authRegistrationFailed;
    case 'auth.password_reset_request_failed':
      return text.authPasswordResetRequestFailed;
    case 'auth.password_reset_failed':
      return text.authPasswordResetFailed;
    case 'auth.request_failed':
      return text.authRequestFailed;
    case 'profile.action_failed':
      return text.profileActionFailed;
    default:
      return raw;
  }
}
