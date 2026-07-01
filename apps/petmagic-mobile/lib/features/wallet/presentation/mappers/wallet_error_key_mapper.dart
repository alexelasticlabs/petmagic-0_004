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

String? normalizeWalletErrorKey(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();
  for (final key in _safeWalletErrorKeys) {
    if (lower == key || lower.contains(key)) {
      return key;
    }
  }

  return null;
}
