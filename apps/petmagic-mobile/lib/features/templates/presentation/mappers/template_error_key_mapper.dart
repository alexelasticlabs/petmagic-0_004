const _templateErrorKeyAliases = <String, String>{
  'active_generation_limit_reached': 'templates.generation_already_started',
  'economy.insufficient_balance': 'templates.insufficient_balance',
  'feedback.rate_limited': 'templates.request_failed',
  'generation_queue_overloaded': 'templates.server_unavailable',
  'generation_wait_too_long': 'templates.generation_wait_too_long',
  'provider_capacity_unavailable': 'templates.server_unavailable',
  'templates.ai_provider_failed': 'templates.server_unavailable',
  'templates.ai_provider_timed_out': 'templates.server_timeout',
  'templates.ai_provider_transient': 'templates.server_unavailable',
  'templates.ai_provider_unavailable': 'templates.server_unavailable',
  'templates.generation_attempts_exceeded': 'templates.generation_failed',
  'templates.premium_required': 'templates.premium_required',
  'templates.source_media_unavailable': 'templates.generation_failed',
  'templates.source_image_empty': 'templates.generation_failed',
  'templates.source_image_type_not_allowed': 'pets.photo_type_not_allowed',
  'templates.source_image_too_large': 'templates.generation_failed',
  'pets.not_found': 'templates.template_unavailable',
  'pets.photo_not_found': 'pets.photo_not_found',
  'pets.photo_required': 'pets.photo_required',
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
  'templates.generation_wait_too_long',
  'templates.premium_required',
  'templates.ai_provider_unavailable',
  'templates.ai_provider_failed',
  'templates.ai_provider_transient',
  'templates.ai_provider_timed_out',
  'templates.generation_attempts_exceeded',
  'templates.source_media_unavailable',
  'templates.source_image_empty',
  'templates.source_image_type_not_allowed',
  'templates.source_image_too_large',
  'templates.template_unavailable',
  'templates.template_changed',
  'pets.not_found',
  'pets.photo_not_found',
  'pets.photo_required',
  'feedback.rate_limited',
  'active_generation_limit_reached',
  'generation_queue_overloaded',
  'generation_wait_too_long',
  'provider_capacity_unavailable',
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
