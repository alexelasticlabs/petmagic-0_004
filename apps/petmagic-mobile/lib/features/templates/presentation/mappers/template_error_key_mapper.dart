const _templateErrorKeyAliases = <String, String>{
  'economy.insufficient_balance': 'templates.insufficient_balance',
  'template_unavailable': 'templates.template_unavailable',
  'template_changed': 'templates.template_changed',
};

const _safeTemplateErrorKeys = <String>[
  'auth.sign_in_required',
  'auth.session_expired',
  'auth.legal_acceptance_required',
  'economy.insufficient_balance',
  'templates.insufficient_balance',
  'templates.network_unavailable',
  'templates.server_unavailable',
  'templates.connection_timeout',
  'templates.server_timeout',
  'templates.request_failed',
  'templates.generation_failed',
  'templates.generation_already_started',
  'templates.generation_cancel_not_allowed',
  'templates.template_unavailable',
  'templates.template_changed',
  'template_unavailable',
  'template_changed',
];

String? normalizeTemplateErrorKey(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();
  for (final key in _safeTemplateErrorKeys) {
    if (lower == key || lower.contains(key)) {
      return _templateErrorKeyAliases[key] ?? key;
    }
  }

  return null;
}
