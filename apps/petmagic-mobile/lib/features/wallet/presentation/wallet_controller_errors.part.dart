part of 'wallet_controller.dart';

String _errorMessage(Object error) {
  if (error is AppException) {
    final message = error.message.trim();
    if (_isSafeWalletErrorKey(message)) {
      return message;
    }

    return switch (error.statusCode) {
      400 => 'wallet.request_failed',
      401 => 'auth.session_expired',
      403 => 'wallet.payment_unavailable',
      404 => 'wallet.request_failed',
      409 => 'wallet.request_failed',
      _ => 'wallet.server_unavailable',
    };
  }

  return 'wallet.request_failed';
}

String _purchaseErrorMessage(String? rawMessage) {
  final message = rawMessage?.trim();
  return message != null && _isSafeWalletErrorKey(message)
      ? message
      : 'wallet.payment_unavailable';
}

bool _isRequestCancelled(Object error) {
  return error is RequestCancelledException ||
      (error is DioException && CancelToken.isCancel(error));
}

String _stripeReferenceType(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return 'missing';
  }

  if (trimmed.startsWith('pi_')) {
    return 'payment_intent';
  }

  if (trimmed.startsWith('cs_')) {
    return 'checkout_session';
  }

  return 'unknown';
}

bool _isSafeWalletErrorKey(String value) {
  return value == 'auth.sign_in_required' ||
      value == 'auth.session_expired' ||
      value == 'auth.legal_acceptance_required' ||
      value == 'wallet.ledger_failed' ||
      value == 'wallet.packs_failed' ||
      value == 'wallet.purchases_failed' ||
      value == 'wallet.payment_unavailable' ||
      value == 'wallet.network_unavailable' ||
      value == 'wallet.server_unavailable' ||
      value == 'wallet.request_failed' ||
      value == 'payment_gateway_failed' ||
      value == 'economy.pack_not_found' ||
      value == 'economy.insufficient_balance' ||
      value == 'redeem_code_not_found' ||
      value == 'redeem_code_already_used' ||
      value == 'redeem_code_expired' ||
      value == 'redeem_code_inactive' ||
      value == 'redeem_code_exhausted' ||
      value == 'redeem_code_user_limit_reached';
}
