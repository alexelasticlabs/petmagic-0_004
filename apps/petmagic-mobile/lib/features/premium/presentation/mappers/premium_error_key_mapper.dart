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

const _backendPremiumErrorKeyAliases = <String, String>{
  'economy.payment_provider_unsupported': 'premium.store_unavailable',
  'economy.payment_provider_unavailable': 'premium.store_unavailable',
  'economy.payment_provider_config_not_found': 'premium.store_unavailable',
  'economy.premium_billing_unavailable': 'premium.store_unavailable',
  'economy.store_verification_unavailable': 'premium.store_unavailable',
  'economy.payment_gateway_failed': 'premium.checkout_failed',
  'economy.store_purchase_invalid': 'premium.checkout_failed',
  'economy.store_purchase_inactive': 'premium.checkout_failed',
  'economy.premium_plan_not_found': 'premium.store_product_unavailable',
  'economy.payment_method_not_found': 'premium.manage_failed',
  'economy.payment_method_provider_invalid': 'premium.manage_failed',
};

String? normalizePremiumErrorKey(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();
  for (final entry in _backendPremiumErrorKeyAliases.entries) {
    if (lower == entry.key || lower.contains(entry.key)) {
      return entry.value;
    }
  }

  for (final key in _safePremiumErrorKeys) {
    if (lower == key || lower.contains(key)) {
      return key;
    }
  }

  return null;
}
