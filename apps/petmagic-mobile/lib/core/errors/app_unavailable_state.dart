enum AppUnavailableKind { offline, serverUnavailable }

bool isAuthRelatedFailure(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) {
    return false;
  }

  return value.contains('auth.sign_in_required') ||
      value.contains('auth.session_expired') ||
      value.contains('auth.invalid_refresh') ||
      value.contains('auth.external_ticket_invalid') ||
      value.contains('auth.legal_acceptance_required') ||
      value.contains('auth.email_not_confirmed') ||
      value.contains('auth.account_locked') ||
      value.contains('auth.invalid_subject');
}

AppUnavailableKind? classifyAppUnavailable({
  required String? raw,
  required bool hasInternet,
}) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty || isAuthRelatedFailure(value)) {
    return null;
  }

  if (!hasInternet || _looksOffline(value)) {
    return AppUnavailableKind.offline;
  }

  if (_looksServerUnavailable(value)) {
    return AppUnavailableKind.serverUnavailable;
  }

  return AppUnavailableKind.serverUnavailable;
}

bool _looksOffline(String value) {
  return value.contains('network.unavailable') ||
      value.contains('network.timeout') ||
      value.contains('connection_timeout') ||
      value.contains('connectionerror') ||
      value.contains('socketexception') ||
      value.contains('offline') ||
      value.contains('no connection') ||
      value.contains('templates.network_unavailable') ||
      value.contains('wallet.network_unavailable');
}

bool _looksServerUnavailable(String value) {
  return value.contains('server_unavailable') ||
      value.contains('server_timeout') ||
      value.contains('request_failed') ||
      value.contains('load_failed') ||
      value.contains('summary_failed') ||
      value.contains('fetch_failed') ||
      value.contains('data_unavailable');
}
