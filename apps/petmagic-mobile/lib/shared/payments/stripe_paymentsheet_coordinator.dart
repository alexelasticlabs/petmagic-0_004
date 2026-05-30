import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripePaymentSheetRequest {
  const StripePaymentSheetRequest({
    required this.paymentIntentClientSecret,
    required this.publishableKey,
    this.customerId,
    this.customerEphemeralKeySecret,
    this.merchantDisplayName = 'PetMagic',
    this.urlScheme = 'petmagicstripe',
    this.returnUrl = 'petmagicstripe://redirect',
  });

  final String paymentIntentClientSecret;
  final String publishableKey;
  final String? customerId;
  final String? customerEphemeralKeySecret;
  final String merchantDisplayName;
  final String urlScheme;
  final String returnUrl;
}

class StripePaymentSheetResult {
  const StripePaymentSheetResult._({
    required this.completed,
    this.error,
    this.errorMessage,
  });

  final bool completed;
  final Object? error;
  final String? errorMessage;

  static const StripePaymentSheetResult success = StripePaymentSheetResult._(
    completed: true,
  );

  factory StripePaymentSheetResult.failure({
    required Object error,
    String? errorMessage,
  }) {
    return StripePaymentSheetResult._(
      completed: false,
      error: error,
      errorMessage: errorMessage,
    );
  }
}

class StripePaymentSheetCoordinator {
  const StripePaymentSheetCoordinator._();

  static Future<StripePaymentSheetResult> present(
    BuildContext context, {
    required StripePaymentSheetRequest request,
    Duration settleDelay = const Duration(milliseconds: 220),
  }) async {
    await _closeTransientUi(context, settleDelay: settleDelay);

    try {
      Stripe.publishableKey = request.publishableKey;
      Stripe.urlScheme = request.urlScheme;
      await Stripe.instance.applySettings();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: request.paymentIntentClientSecret,
          merchantDisplayName: request.merchantDisplayName,
          customerId: request.customerId,
          customerEphemeralKeySecret: request.customerEphemeralKeySecret,
          returnURL: request.returnUrl,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return StripePaymentSheetResult.success;
    } on StripeException catch (error) {
      return StripePaymentSheetResult.failure(
        error: error,
        errorMessage: error.error.localizedMessage,
      );
    } on PlatformException catch (error) {
      return StripePaymentSheetResult.failure(
        error: error,
        errorMessage: error.message,
      );
    } catch (error) {
      return StripePaymentSheetResult.failure(error: error);
    }
  }

  static Future<void> _closeTransientUi(
    BuildContext context, {
    required Duration settleDelay,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((route) => route is PageRoute<dynamic>);

    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!context.mounted) {
      return;
    }

    await Future<void>.delayed(settleDelay);
  }
}
