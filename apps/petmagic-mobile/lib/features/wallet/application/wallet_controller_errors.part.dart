part of 'wallet_controller.dart';

final RegExp _stripeCheckoutSessionReferencePattern = RegExp(
  r'^cs_(test|live)_[A-Za-z0-9_]{8,255}$',
);
final RegExp _stripePaymentIntentReferencePattern = RegExp(
  r'^pi_[A-Za-z0-9_]{8,255}$',
);

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
  return error is RequestCancelledException ||
      (error is DioException && CancelToken.isCancel(error));
}

String? _normalizeStripeCheckoutReferenceId(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  if (_stripeCheckoutSessionReferencePattern.hasMatch(trimmed) ||
      _stripePaymentIntentReferencePattern.hasMatch(trimmed)) {
    return trimmed;
  }

  return null;
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

// Wallet application error mapping.
