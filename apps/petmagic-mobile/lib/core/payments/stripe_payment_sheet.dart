import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';

final stripePaymentSheetProvider = Provider<StripePaymentSheetPort>((ref) {
  return const FlutterStripePaymentSheet();
});

enum StripePaymentSheetResult { completed, cancelled }

class StripePaymentSheetRequest {
  const StripePaymentSheetRequest({
    required this.paymentIntentClientSecret,
    required this.customerId,
    required this.customerEphemeralKeySecret,
    required this.publishableKey,
    required this.primaryButtonLabel,
  });

  final String paymentIntentClientSecret;
  final String customerId;
  final String customerEphemeralKeySecret;
  final String publishableKey;
  final String primaryButtonLabel;

  bool get isComplete =>
      paymentIntentClientSecret.trim().isNotEmpty &&
      customerId.trim().isNotEmpty &&
      customerEphemeralKeySecret.trim().isNotEmpty &&
      (publishableKey.startsWith('pk_test_') ||
          publishableKey.startsWith('pk_live_'));
}

abstract interface class StripePaymentSheetPort {
  Future<StripePaymentSheetResult> present(StripePaymentSheetRequest request);
}

class FlutterStripePaymentSheet implements StripePaymentSheetPort {
  const FlutterStripePaymentSheet();

  @override
  Future<StripePaymentSheetResult> present(
    StripePaymentSheetRequest request,
  ) async {
    if (!request.isComplete) {
      throw StateError('stripe.payment_sheet_configuration_invalid');
    }

    Stripe.publishableKey = request.publishableKey.trim();
    Stripe.urlScheme = AppConfig.stripeRedirectScheme;
    await Stripe.instance.applySettings();

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'PetMagic',
          paymentIntentClientSecret: request.paymentIntentClientSecret.trim(),
          customerId: request.customerId.trim(),
          customerEphemeralKeySecret: request.customerEphemeralKeySecret.trim(),
          returnURL: '${AppConfig.stripeRedirectScheme}://redirect',
          primaryButtonLabel: request.primaryButtonLabel,
          allowsDelayedPaymentMethods: false,
          style: ThemeMode.system,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return StripePaymentSheetResult.completed;
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) {
        return StripePaymentSheetResult.cancelled;
      }
      rethrow;
    }
  }
}
