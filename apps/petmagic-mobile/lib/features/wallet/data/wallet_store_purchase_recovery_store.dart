import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final walletStorePurchaseRecoveryPreferencesProvider =
    Provider<SharedPreferencesAsync>((ref) => SharedPreferencesAsync());

final walletStorePurchaseRecoveryStoreProvider =
    Provider<WalletStorePurchaseRecoveryStore>((ref) {
      return WalletStorePurchaseRecoveryStore(
        preferences: ref.watch(walletStorePurchaseRecoveryPreferencesProvider),
      );
    });

class PendingStoreWalletPurchase {
  const PendingStoreWalletPurchase({
    required this.orderId,
    required this.provider,
    required this.productId,
    required this.packId,
    required this.packCode,
    required this.createdAtUtc,
  });

  final String orderId;
  final String provider;
  final String productId;
  final String packId;
  final String packCode;
  final DateTime createdAtUtc;

  Map<String, Object?> toJson() {
    return {
      'orderId': orderId,
      'provider': provider,
      'productId': productId,
      'packId': packId,
      'packCode': packCode,
      'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    };
  }

  factory PendingStoreWalletPurchase.fromJson(Map<String, dynamic> json) {
    return PendingStoreWalletPurchase(
      orderId: json['orderId'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      packId: json['packId'] as String? ?? '',
      packCode: json['packCode'] as String? ?? '',
      createdAtUtc: json['createdAtUtc'] is String
          ? DateTime.tryParse(json['createdAtUtc'] as String)?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class WalletStorePurchaseRecoveryStore {
  const WalletStorePurchaseRecoveryStore({
    required SharedPreferencesAsync preferences,
    DateTime Function()? clock,
  }) : _preferences = preferences,
       _clock = clock;

  static const _pendingPurchaseKey = 'wallet_pending_store_purchase_v1';
  static const _maxPendingPurchaseAge = Duration(days: 14);

  final SharedPreferencesAsync _preferences;
  final DateTime Function()? _clock;

  Future<PendingStoreWalletPurchase?> readPendingPurchase() async {
    final raw = await _preferences.getString(_pendingPurchaseKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await clearPendingPurchase();
        return null;
      }

      final pending = PendingStoreWalletPurchase.fromJson(decoded);
      if (pending.orderId.trim().isEmpty ||
          pending.provider.trim().isEmpty ||
          pending.productId.trim().isEmpty ||
          _isExpired(pending.createdAtUtc)) {
        await clearPendingPurchase();
        return null;
      }

      return pending;
    } on FormatException {
      await clearPendingPurchase();
      return null;
    }
  }

  Future<void> savePendingPurchase(PendingStoreWalletPurchase purchase) async {
    await _preferences.setString(_pendingPurchaseKey, jsonEncode(purchase));
  }

  Future<void> clearPendingPurchase({String? orderId}) async {
    final normalizedOrderId = orderId?.trim();
    if (normalizedOrderId != null && normalizedOrderId.isNotEmpty) {
      final pending = await readPendingPurchase();
      if (pending != null &&
          pending.orderId.isNotEmpty &&
          pending.orderId != normalizedOrderId) {
        return;
      }
    }

    await _preferences.remove(_pendingPurchaseKey);
  }

  bool _isExpired(DateTime createdAtUtc) {
    final createdAt = createdAtUtc.toUtc();
    if (createdAt.millisecondsSinceEpoch <= 0) {
      return true;
    }

    final now = (_clock ?? DateTime.now)().toUtc();
    if (createdAt.isAfter(now.add(const Duration(minutes: 5)))) {
      return true;
    }

    return now.difference(createdAt) > _maxPendingPurchaseAge;
  }
}
