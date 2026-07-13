part of 'wallet_controller.dart';

String _errorMessage(Object error) {
  if (error is AppException) {
    final message = normalizeWalletErrorKey(error.message);
    if (message != null) {
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
  final message = normalizeWalletErrorKey(rawMessage);
  return message ?? 'wallet.payment_unavailable';
}

bool _isRequestCancelled(Object error) {
  return error is RequestCancelledException;
}

// Wallet application error mapping.
