import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum StripePaymentSheetOutcome { completed, cancelled, failed }

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
    required this.outcome,
    this.error,
    this.errorMessage,
  });

  final StripePaymentSheetOutcome outcome;
  final Object? error;
  final String? errorMessage;

  bool get completed => outcome == StripePaymentSheetOutcome.completed;
  bool get cancelled => outcome == StripePaymentSheetOutcome.cancelled;

  static const StripePaymentSheetResult success = StripePaymentSheetResult._(
    outcome: StripePaymentSheetOutcome.completed,
  );

  static const StripePaymentSheetResult cancelledResult =
      StripePaymentSheetResult._(outcome: StripePaymentSheetOutcome.cancelled);

  factory StripePaymentSheetResult.failure({
    required Object error,
    String? errorMessage,
    bool isCancelled = false,
  }) {
    return StripePaymentSheetResult._(
      outcome: isCancelled
          ? StripePaymentSheetOutcome.cancelled
          : StripePaymentSheetOutcome.failed,
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
    return StripePaymentSheetResult.failure(
      error: UnsupportedError('stripe_paymentsheet_unavailable'),
      errorMessage: 'Stripe PaymentSheet is unavailable in this build.',
    );
  }

  static Future<void> _closeTransientUi(
    BuildContext context, {
    required Duration settleDelay,
  }) async {
    if (kDebugMode) {
      final binding = WidgetsBinding.instance;
      if (binding.debugShowWidgetInspectorOverride) {
        binding.debugShowWidgetInspectorOverride = false;
      }
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (!context.mounted) {
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((route) => route is PageRoute<dynamic>);

    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!context.mounted) {
      return;
    }

    await Future<void>.delayed(settleDelay);
  }
}
