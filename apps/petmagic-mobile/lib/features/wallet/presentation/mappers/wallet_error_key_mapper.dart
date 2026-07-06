const _safeWalletErrorKeys = <String>[
  'auth.sign_in_required',
  'auth.session_expired',
  'auth.legal_acceptance_required',
  'wallet.ledger_failed',
  'wallet.packs_failed',
  'wallet.purchases_failed',
  'wallet.payment_unavailable',
  'wallet.network_unavailable',
  'wallet.server_unavailable',
  'wallet.request_failed',
  'payment_gateway_failed',
  'economy.pack_not_found',
  'economy.insufficient_balance',
  'redeem_code_not_found',
  'redeem_code_already_used',
  'redeem_code_expired',
  'redeem_code_inactive',
  'redeem_code_exhausted',
  'redeem_code_user_limit_reached',
];

const _backendWalletErrorKeyAliases = <String, String>{
  'economy.payment_provider_unsupported': 'wallet.payment_unavailable',
  'economy.payment_provider_unavailable': 'wallet.payment_unavailable',
  'economy.payment_provider_config_not_found': 'wallet.payment_unavailable',
  'economy.payment_gateway_failed': 'payment_gateway_failed',
  'economy.store_verification_unavailable': 'wallet.payment_unavailable',
  'economy.store_purchase_invalid': 'wallet.payment_unavailable',
  'economy.store_purchase_inactive': 'wallet.payment_unavailable',
  'economy.payment_method_not_found': 'wallet.payment_unavailable',
  'economy.payment_method_provider_invalid': 'wallet.payment_unavailable',
};

String? normalizeWalletErrorKey(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();
  for (final entry in _backendWalletErrorKeyAliases.entries) {
    if (lower == entry.key || lower.contains(entry.key)) {
      return entry.value;
    }
  }

  for (final key in _safeWalletErrorKeys) {
    if (lower == key || lower.contains(key)) {
      return key;
    }
  }

  return null;
}
