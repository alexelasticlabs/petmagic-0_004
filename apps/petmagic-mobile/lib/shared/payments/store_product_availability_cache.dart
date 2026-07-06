import 'dart:async';
import 'dart:convert';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:crypto/crypto.dart';

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
    int maxEntries = 64,
    DateTime Function()? now,
  }) : _successTtl = successTtl,
       _unavailableTtl = unavailableTtl,
       _maxEntries = maxEntries,
       _now = now ?? DateTime.now;

  final Duration _successTtl;
  final Duration _unavailableTtl;
  final int _maxEntries;
  final DateTime Function() _now;
  final Map<String, _StoreProductAvailabilityCacheEntry> _entries =
      <String, _StoreProductAvailabilityCacheEntry>{};
  final Map<String, _StoreProductAvailabilityInFlight> _inFlight =
      <String, _StoreProductAvailabilityInFlight>{};

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
      _rememberEntry(cacheKey, cachedEntry);
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

    final exactInFlight = _inFlight[cacheKey];
    if (exactInFlight != null) {
      return exactInFlight.future;
    }

    final coveringInFlight = _findCoveringInFlight(
      normalizedProductIds,
      scopeKey: normalizedScopeKey,
    );
    if (coveringInFlight != null) {
      return coveringInFlight.future.then(
        (snapshot) => snapshot.project(normalizedProductIds),
      );
    }

    final future = () async {
      final snapshot = await loader(normalizedProductIds);
      final ttl = snapshot.isAvailable ? _successTtl : _unavailableTtl;
      _rememberEntry(
        cacheKey,
        _StoreProductAvailabilityCacheEntry(
          snapshot: snapshot,
          expiresAt: _now().add(ttl),
        ),
      );
      return snapshot;
    }();
    _inFlight[cacheKey] = _StoreProductAvailabilityInFlight(
      productIds: normalizedProductIds,
      scopeKey: normalizedScopeKey,
      future: future,
    );
    return future.whenComplete(() {
      if (identical(_inFlight[cacheKey]?.future, future)) {
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

  void _rememberEntry(
    String cacheKey,
    _StoreProductAvailabilityCacheEntry entry,
  ) {
    _entries.remove(cacheKey);
    _entries[cacheKey] = entry;
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
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

  _StoreProductAvailabilityInFlight? _findCoveringInFlight(
    Set<String> requestedProductIds, {
    String? scopeKey,
  }) {
    _StoreProductAvailabilityInFlight? bestMatch;
    for (final entry in _inFlight.values) {
      if (entry.scopeKey != scopeKey || !entry.covers(requestedProductIds)) {
        continue;
      }

      if (bestMatch == null ||
          entry.productIds.length < bestMatch.productIds.length) {
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
    if (value == null || value.isEmpty) {
      return null;
    }
    return 'sha256:${sha256.convert(utf8.encode(value.toLowerCase()))}';
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

class _StoreProductAvailabilityInFlight {
  const _StoreProductAvailabilityInFlight({
    required this.productIds,
    required this.scopeKey,
    required this.future,
  });

  final Set<String> productIds;
  final String? scopeKey;
  final Future<StoreProductAvailabilitySnapshot> future;

  bool covers(Set<String> requestedProductIds) {
    for (final productId in requestedProductIds) {
      if (!productIds.contains(productId)) {
        return false;
      }
    }
    return true;
  }
}
