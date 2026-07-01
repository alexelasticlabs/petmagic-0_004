const _safePremiumErrorKeys = <String>[
  'auth.sign_in_required',
  'auth.session_expired',
  'auth.legal_acceptance_required',
  'premium.plans_failed',
  'premium.request_failed',
  'premium.checkout_failed',
  'premium.manage_failed',
  'premium.restore_started',
  'premium.purchase_activated',
  'templates.network_unavailable',
  'premium.purchase_cancelled',
  'premium.store_unavailable',
  'premium.store_product_unavailable',
];

String? normalizePremiumErrorKey(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();
  for (final key in _safePremiumErrorKeys) {
    if (lower == key || lower.contains(key)) {
      return key;
    }
  }

  return null;
}
