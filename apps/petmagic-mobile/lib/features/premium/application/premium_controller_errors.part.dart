part of 'premium_controller.dart';

String _premiumErrorMessage(Object error, String fallback) {
  if (error is AppException) {
    final message = normalizePremiumErrorKey(error.message);
    if (message != null) {
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
  final message = normalizePremiumErrorKey(rawMessage);
  return message ?? 'premium.checkout_failed';
}

// Premium application error mapping.
