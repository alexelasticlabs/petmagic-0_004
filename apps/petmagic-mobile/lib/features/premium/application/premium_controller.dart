import 'dart:async';

// Public premium application state and use-case orchestration.
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/domain/premium_models.dart';
import 'package:petmagic_mobile/features/premium/application/premium_repository.dart';
import 'package:petmagic_mobile/features/premium/application/premium_error_key_mapper.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

part 'premium_controller_checkout.part.dart';
part 'premium_controller_errors.part.dart';
part 'premium_controller_lifecycle.part.dart';
part 'premium_controller_models.part.dart';
part 'premium_controller_state.part.dart';
part 'premium_controller_loading.part.dart';
part 'premium_controller_store_purchases.part.dart';
part 'premium_controller_verification.part.dart';

abstract class _PremiumControllerBase extends Notifier<PremiumState> {
  static const int _maxStorePurchaseVerificationKeys = 32;

  PremiumRepositoryPort? _activeRepository;
  PremiumRefreshProfile? _activeRefreshProfile;

  PremiumRepositoryPort get _repository {
    final repository = _activeRepository;
    if (repository != null) {
      return repository;
    }

    return ref.read(premiumRepositoryProvider);
  }

  AppRuntimeInfo get _runtimeInfo => ref.read(appRuntimeInfoProvider);

  PremiumRefreshProfile get _refreshProfile {
    final refreshProfile = _activeRefreshProfile;
    if (refreshProfile != null) {
      return refreshProfile;
    }

    return ref.read(premiumRefreshProfileProvider);
  }

  Future<void>? _loadInFlight;
  Future<void>? _checkoutVerificationInFlight;
  RequestCancellation? _activeLoadRequestCancellation;
  RequestCancellation? _activeStatusRefreshRequestCancellation;
  RequestCancellation? _activePremiumActionRequestCancellation;
  RequestCancellation? _activeCheckoutVerificationRequestCancellation;
  final Set<String> _storePurchaseVerificationInFlightKeys = <String>{};
  final Set<String> _storePurchaseVerifiedKeys = <String>{};
  bool _premiumLifecycleStarted = false;
  bool _hasInternet = true;

  Future<void> load({bool refresh = false});

  void selectPlan(String planCode);

  void selectProvider(PremiumPaymentProvider provider);

  Future<PremiumCheckoutModel?> startCheckout();

  Future<void> manageBilling();

  Future<void> restorePurchases();

  void consumeExternalUrl();

  void markCheckoutOpened({required bool wasPremiumBeforeCheckout});

  Future<void> verifyCheckoutStatus({
    String? stripePlanCode,
    String? stripeExternalSubscriptionId,
  });

  Future<void> _handlePurchaseUpdates(List<StorePurchaseDetails> purchases);
}

class PremiumController extends _PremiumControllerBase
    with
        _PremiumControllerLifecycle,
        _PremiumControllerLoading,
        _PremiumControllerCheckout,
        _PremiumControllerVerification,
        _PremiumControllerStorePurchases {
  @override
  PremiumState build() {
    _activeRepository = ref.read(premiumRepositoryProvider);
    _activeRefreshProfile = ref.read(premiumRefreshProfileProvider);
    _ensurePremiumLifecycleStarted();
    return const PremiumState(isLoading: true);
  }
}

enum _BillingPeriod { monthly, yearly, other }

// Public premium application controller.
