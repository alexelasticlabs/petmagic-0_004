import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

typedef StoreProductAvailabilityLoader =
    Future<StoreProductAvailabilitySnapshot> Function(Set<String> productIds);

final sharedStoreProductAvailabilityCache = StoreProductAvailabilityCache();

class StoreProductAvailabilitySnapshot {
  const StoreProductAvailabilitySnapshot({
    required this.isAvailable,
    this.productIds = const <String>{},
    this.productPrices = const <String, String>{},
    this.productDetailsById = const <String, ProductDetails>{},
  });

  final bool isAvailable;
  final Set<String> productIds;
  final Map<String, String> productPrices;
  final Map<String, ProductDetails> productDetailsById;

  bool covers(Set<String> requestedProductIds) {
    for (final productId in requestedProductIds) {
      if (!productIds.contains(productId)) {
        return false;
      }
    }
    return true;
  }

  StoreProductAvailabilitySnapshot project(Set<String> requestedProductIds) {
    return StoreProductAvailabilitySnapshot(
      isAvailable: isAvailable,
      productIds: productIds.where(requestedProductIds.contains).toSet(),
      productPrices: {
        for (final entry in productPrices.entries)
          if (requestedProductIds.contains(entry.key)) entry.key: entry.value,
      },
      productDetailsById: {
        for (final entry in productDetailsById.entries)
          if (requestedProductIds.contains(entry.key)) entry.key: entry.value,
      },
    );
  }
}

class StoreProductAvailabilityCache {
  StoreProductAvailabilityCache({
    Duration successTtl = const Duration(minutes: 10),
    Duration unavailableTtl = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _successTtl = successTtl,
       _unavailableTtl = unavailableTtl,
       _now = now ?? DateTime.now;

  final Duration _successTtl;
  final Duration _unavailableTtl;
  final DateTime Function() _now;
  final Map<String, _StoreProductAvailabilityCacheEntry> _entries =
      <String, _StoreProductAvailabilityCacheEntry>{};
  final Map<String, Future<StoreProductAvailabilitySnapshot>> _inFlight =
      <String, Future<StoreProductAvailabilitySnapshot>>{};

  Future<StoreProductAvailabilitySnapshot> read(
    Set<String> productIds, {
    required StoreProductAvailabilityLoader loader,
    String? scopeKey,
  }) {
    final normalizedProductIds = _normalizeProductIds(productIds);
    if (normalizedProductIds.isEmpty) {
      return Future.value(
        const StoreProductAvailabilitySnapshot(isAvailable: false),
      );
    }

    final normalizedScopeKey = _normalizeScopeKey(scopeKey);
    final cacheKey = _cacheKeyFor(
      normalizedProductIds,
      scopeKey: normalizedScopeKey,
    );
    _pruneExpiredEntries();

    final cachedEntry = _entries[cacheKey];
    final now = _now();
    if (cachedEntry != null && now.isBefore(cachedEntry.expiresAt)) {
      return Future.value(cachedEntry.snapshot.project(normalizedProductIds));
    }

    final coveringEntry = _findCoveringEntry(
      normalizedProductIds,
      now,
      scopeKey: normalizedScopeKey,
    );
    if (coveringEntry != null) {
      return Future.value(coveringEntry.snapshot.project(normalizedProductIds));
    }

    final inFlight = _inFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = () async {
      final snapshot = await loader(normalizedProductIds);
      final ttl = snapshot.isAvailable ? _successTtl : _unavailableTtl;
      _entries[cacheKey] = _StoreProductAvailabilityCacheEntry(
        snapshot: snapshot,
        expiresAt: _now().add(ttl),
      );
      return snapshot;
    }();
    _inFlight[cacheKey] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[cacheKey], future)) {
        _inFlight.remove(cacheKey);
      }
    });
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
  }

  void _pruneExpiredEntries() {
    final now = _now();
    _entries.removeWhere((_, entry) => !now.isBefore(entry.expiresAt));
  }

  _StoreProductAvailabilityCacheEntry? _findCoveringEntry(
    Set<String> requestedProductIds,
    DateTime now, {
    String? scopeKey,
  }) {
    _StoreProductAvailabilityCacheEntry? bestMatch;
    final expectedPrefix = scopeKey == null ? null : '$scopeKey::';
    for (final mapEntry in _entries.entries) {
      final entryKey = mapEntry.key;
      if (scopeKey == null) {
        if (entryKey.contains('::')) {
          continue;
        }
      } else if (!entryKey.startsWith(expectedPrefix!)) {
        continue;
      }

      final entry = mapEntry.value;
      if (!now.isBefore(entry.expiresAt) ||
          !entry.snapshot.isAvailable ||
          !entry.snapshot.covers(requestedProductIds)) {
        continue;
      }

      if (bestMatch == null ||
          entry.snapshot.productIds.length <
              bestMatch.snapshot.productIds.length) {
        bestMatch = entry;
      }
    }
    return bestMatch;
  }

  Set<String> _normalizeProductIds(Set<String> productIds) {
    final normalized = <String>{};
    for (final productId in productIds) {
      final trimmed = productId.trim();
      if (trimmed.isNotEmpty) {
        normalized.add(trimmed);
      }
    }
    return normalized;
  }

  String _cacheKeyFor(Set<String> productIds, {String? scopeKey}) {
    final sorted = productIds.toList(growable: false)..sort();
    if (scopeKey == null) {
      return sorted.join('|');
    }
    return '$scopeKey::${sorted.join('|')}';
  }

  String? _normalizeScopeKey(String? scopeKey) {
    final value = scopeKey?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

class _StoreProductAvailabilityCacheEntry {
  const _StoreProductAvailabilityCacheEntry({
    required this.snapshot,
    required this.expiresAt,
  });

  final StoreProductAvailabilitySnapshot snapshot;
  final DateTime expiresAt;
}
