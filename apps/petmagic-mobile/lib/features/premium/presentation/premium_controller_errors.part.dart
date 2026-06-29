part of 'premium_controller.dart';

String _premiumErrorMessage(Object error, String fallback) {
  if (error is AppException) {
    final message = error.message.trim();
    if (_isSafePremiumErrorKey(message)) {
      return message;
    }

    final statusCode = error.statusCode;
    if (statusCode == 401) {
      return 'auth.session_expired';
    }
    if (statusCode == 404) {
      return 'premium.store_product_unavailable';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'premium.store_unavailable';
    }

    return fallback;
  }

  return fallback;
}

String _premiumPurchaseErrorMessage(String? rawMessage) {
  final message = rawMessage?.trim();
  return message != null && _isSafePremiumErrorKey(message)
      ? message
      : 'premium.checkout_failed';
}

bool _isSafePremiumErrorKey(String value) {
  return value == 'auth.session_expired' ||
      value == 'premium.plans_failed' ||
      value == 'premium.request_failed' ||
      value == 'premium.checkout_failed' ||
      value == 'premium.manage_failed' ||
      value == 'premium.restore_started' ||
      value == 'premium.purchase_activated' ||
      value == 'templates.network_unavailable' ||
      value == 'premium.purchase_cancelled' ||
      value == 'premium.store_unavailable' ||
      value == 'premium.store_product_unavailable';
}
