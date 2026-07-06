import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

final walletStorePurchaseRecoveryPreferencesProvider =
    Provider<SharedPreferencesAsync>((ref) => SharedPreferencesAsync());

final walletStorePurchaseRecoverySecureStorageProvider =
    Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final walletStorePurchaseRecoveryStoreProvider =
    Provider<WalletStorePurchaseRecoveryStore>((ref) {
      return WalletStorePurchaseRecoveryStore(
        preferences: ref.watch(walletStorePurchaseRecoveryPreferencesProvider),
        secureStorage: ref.watch(
          walletStorePurchaseRecoverySecureStorageProvider,
        ),
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
    FlutterSecureStorage? secureStorage,
    DateTime Function()? clock,
  }) : _preferences = preferences,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _clock = clock;

  static const legacyPendingPurchaseKey = 'wallet_pending_store_purchase_v1';
  static const pendingPurchaseSecureStorageKey =
      'petmagic_mobile_wallet_pending_store_purchase_v2';
  static const _maxPendingPurchaseAge = Duration(days: 14);

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;
  final DateTime Function()? _clock;

  Future<PendingStoreWalletPurchase?> readPendingPurchase() async {
    final raw = await _secureStorage.read(key: pendingPurchaseSecureStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return _readAndMigrateLegacyPendingPurchase();
    }

    return _decodePendingPurchase(raw, clearOnInvalid: clearPendingPurchase);
  }

  Future<PendingStoreWalletPurchase?>
  _readAndMigrateLegacyPendingPurchase() async {
    final raw = await _preferences.getString(legacyPendingPurchaseKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final pending = await _decodePendingPurchase(
      raw,
      clearOnInvalid: () => _preferences.remove(legacyPendingPurchaseKey),
    );
    if (pending == null) {
      return null;
    }

    await _secureStorage.write(
      key: pendingPurchaseSecureStorageKey,
      value: jsonEncode(pending),
    );
    await _preferences.remove(legacyPendingPurchaseKey);
    return pending;
  }

  Future<PendingStoreWalletPurchase?> _decodePendingPurchase(
    String raw, {
    required Future<void> Function() clearOnInvalid,
  }) async {
    if (raw.trim().isEmpty) {
      await clearOnInvalid();
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await clearOnInvalid();
        return null;
      }

      final pending = PendingStoreWalletPurchase.fromJson(decoded);
      if (pending.orderId.trim().isEmpty ||
          pending.provider.trim().isEmpty ||
          pending.productId.trim().isEmpty ||
          _isExpired(pending.createdAtUtc)) {
        await clearOnInvalid();
        return null;
      }

      return pending;
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Wallet.StorePurchaseRecovery',
        operation: 'decode_pending_purchase',
        message: 'Stored pending wallet purchase was invalid and cleared',
        context: {'stage': 'decode_pending_purchase'},
        error: error,
        stackTrace: stackTrace,
      );
      await clearOnInvalid();
      return null;
    }
  }

  Future<void> savePendingPurchase(PendingStoreWalletPurchase purchase) async {
    await _secureStorage.write(
      key: pendingPurchaseSecureStorageKey,
      value: jsonEncode(purchase),
    );
    await _preferences.remove(legacyPendingPurchaseKey);
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

    await Future.wait<void>([
      _secureStorage.delete(key: pendingPurchaseSecureStorageKey),
      _preferences.remove(legacyPendingPurchaseKey),
    ]);
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
