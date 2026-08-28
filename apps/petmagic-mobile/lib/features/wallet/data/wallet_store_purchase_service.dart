import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/payments/store_purchase.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/shared/payments/store_product_availability_cache.dart';
import 'package:petmagic_mobile/shared/payments/store_purchase_adapter.dart';

/// Isolates StoreKit/Google Play plugin operations from wallet REST transport.
final class WalletStorePurchaseService {
  WalletStorePurchaseService({InAppPurchase? inAppPurchase})
    : _inAppPurchaseOverride = inAppPurchase;

  static const _availabilityTimeout = Duration(seconds: 8);

  final InAppPurchase? _inAppPurchaseOverride;

  InAppPurchase get _inAppPurchase =>
      _inAppPurchaseOverride ?? InAppPurchase.instance;

  Stream<List<StorePurchaseDetails>> get purchaseUpdates {
    return _inAppPurchase.purchaseStream.map(
      (purchases) =>
          purchases.map(mapPlatformStorePurchase).toList(growable: false),
    );
  }

  Future<
    ({
      bool isAvailable,
      Set<String> productIds,
      Map<String, String> productPrices,
    })
  >
  fetchAvailability(
    List<CurrencyPackModel> packs,
    WalletPaymentMethodModel paymentMethod,
  ) async {
    if (!paymentMethod.isStoreNative) {
      return (
        isAvailable: false,
        productIds: const <String>{},
        productPrices: const <String, String>{},
      );
    }

    final requestedIds = packs
        .map((pack) => pack.productIdForProvider(paymentMethod.provider))
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();
    if (requestedIds.isEmpty) {
      return (
        isAvailable: false,
        productIds: const <String>{},
        productPrices: const <String, String>{},
      );
    }

    final availability = await _fetchAvailabilityWithWarmupRetry(
      requestedIds,
      paymentMethod.provider,
    );
    return (
      isAvailable: availability.isAvailable,
      productIds: availability.productIds,
      productPrices: availability.productPrices,
    );
  }

  Future<void> startCheckout(
    CurrencyPackModel pack,
    WalletPaymentMethodModel paymentMethod, {
    required String applicationUserName,
  }) async {
    final productId = pack.productIdForProvider(paymentMethod.provider);
    if (productId == null || productId.isEmpty) {
      throw const AppException('wallet.payment_unavailable');
    }

    final availability = await _fetchAvailabilityWithWarmupRetry({
      productId,
    }, paymentMethod.provider);
    final productDetails = availability.productDetailsById[productId];
    if (!availability.isAvailable || productDetails == null) {
      throw const AppException('wallet.payment_unavailable');
    }

    final launched = await _inAppPurchase.buyConsumable(
      purchaseParam: PurchaseParam(
        productDetails: productDetails,
        applicationUserName: applicationUserName,
      ),
      autoConsume: false,
    );
    if (!launched) {
      throw const AppException('wallet.payment_unavailable');
    }
  }

  Future<void> restorePurchases({required String applicationUserName}) {
    return _inAppPurchase.restorePurchases(
      applicationUserName: applicationUserName,
    );
  }

  Future<void> completePurchase(StorePurchaseDetails purchase) {
    return _inAppPurchase.completePurchase(
      requirePlatformStorePurchase(purchase),
    );
  }

  Future<void> consumeVerifiedPurchase(StorePurchaseDetails purchase) async {
    final platformPurchase = requirePlatformStorePurchase(purchase);
    if (!Platform.isAndroid) {
      await _inAppPurchase.completePurchase(platformPurchase);
      return;
    }

    final addition = _inAppPurchase
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final result = await addition.consumePurchase(platformPurchase);
    if (result.responseCode != BillingResponse.ok) {
      throw const AppException('wallet.payment_unavailable');
    }
  }

  Future<StoreProductAvailabilitySnapshot> _fetchAvailabilityWithWarmupRetry(
    Set<String> productIds,
    String provider,
  ) async {
    final availability = await sharedStoreProductAvailabilityCache.read(
      productIds,
      loader: _loadAvailabilitySnapshot,
      scopeKey: provider,
    );
    if (availability.isAvailable) {
      return availability;
    }

    // A native billing client can report unavailable immediately after resume
    // even though it becomes ready a moment later. Retry once with a fresh
    // lookup before showing an availability error to the user.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return sharedStoreProductAvailabilityCache.read(
      productIds,
      loader: _loadAvailabilitySnapshot,
      scopeKey: provider,
    );
  }

  Future<StoreProductAvailabilitySnapshot> _loadAvailabilitySnapshot(
    Set<String> requestedProductIds,
  ) async {
    final isAvailable = await _inAppPurchase.isAvailable().timeout(
      _availabilityTimeout,
    );
    if (!isAvailable) {
      return const StoreProductAvailabilitySnapshot(isAvailable: false);
    }

    final response = await _inAppPurchase
        .queryProductDetails(requestedProductIds)
        .timeout(_availabilityTimeout);
    if (response.error != null) {
      throw const AppException('wallet.payment_unavailable');
    }
    return StoreProductAvailabilitySnapshot(
      isAvailable: true,
      productIds: response.productDetails.map((product) => product.id).toSet(),
      productPrices: {
        for (final product in response.productDetails)
          product.id: product.price,
      },
      productDetailsById: {
        for (final product in response.productDetails) product.id: product,
      },
    );
  }
}
