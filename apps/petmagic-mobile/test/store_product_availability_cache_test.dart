import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/shared/payments/store_product_availability_cache.dart';

void main() {
  test(
    'store product availability cache reuses fresh successful entries',
    () async {
      var now = DateTime(2026, 7, 1, 12);
      var loadCalls = 0;
      final cache = StoreProductAvailabilityCache(now: () => now);

      Future<StoreProductAvailabilitySnapshot> loader(
        Set<String> productIds,
      ) async {
        loadCalls++;
        return StoreProductAvailabilitySnapshot(
          isAvailable: true,
          productIds: productIds,
          productPrices: {
            for (final productId in productIds) productId: '\$9.99',
          },
        );
      }

      final first = await cache.read({
        ' premium.year ',
        'premium.month',
      }, loader: loader);
      final second = await cache.read({
        'premium.month',
        'premium.year',
      }, loader: loader);

      expect(loadCalls, 1);
      expect(first.productIds, {'premium.month', 'premium.year'});
      expect(second.productPrices['premium.month'], '\$9.99');

      now = now.add(const Duration(minutes: 11));
      await cache.read({'premium.month', 'premium.year'}, loader: loader);
      expect(loadCalls, 2);
    },
  );

  test(
    'store product availability cache reuses fresh superset entries for subset lookups',
    () async {
      var loadCalls = 0;
      final cache = StoreProductAvailabilityCache();

      Future<StoreProductAvailabilitySnapshot> loader(
        Set<String> productIds,
      ) async {
        loadCalls++;
        return StoreProductAvailabilitySnapshot(
          isAvailable: true,
          productIds: productIds,
          productPrices: {
            for (final productId in productIds) productId: '\$4.99',
          },
        );
      }

      final first = await cache.read({
        'premium.month',
        'premium.year',
      }, loader: loader);
      final second = await cache.read({'premium.month'}, loader: loader);

      expect(loadCalls, 1);
      expect(first.productIds, {'premium.month', 'premium.year'});
      expect(second.productIds, {'premium.month'});
      expect(second.productPrices, {'premium.month': '\$4.99'});
    },
  );

  test(
    'store product availability cache dedupes concurrent in-flight lookups',
    () async {
      final completer = Completer<StoreProductAvailabilitySnapshot>();
      var loadCalls = 0;
      final cache = StoreProductAvailabilityCache();

      Future<StoreProductAvailabilitySnapshot> loader(Set<String> productIds) {
        loadCalls++;
        return completer.future;
      }

      final firstFuture = cache.read({'pack.small'}, loader: loader);
      final secondFuture = cache.read({'pack.small'}, loader: loader);

      expect(loadCalls, 1);

      completer.complete(
        const StoreProductAvailabilitySnapshot(
          isAvailable: true,
          productIds: {'pack.small'},
          productPrices: {'pack.small': '\$1.99'},
        ),
      );

      final results = await Future.wait([firstFuture, secondFuture]);
      expect(results[0].productIds, {'pack.small'});
      expect(results[1].productPrices['pack.small'], '\$1.99');
    },
  );

  test(
    'store product availability cache reuses in-flight superset for subset lookups',
    () async {
      final completer = Completer<StoreProductAvailabilitySnapshot>();
      var loadCalls = 0;
      final cache = StoreProductAvailabilityCache();

      Future<StoreProductAvailabilitySnapshot> loader(Set<String> productIds) {
        loadCalls++;
        return completer.future;
      }

      final firstFuture = cache.read(
        {'premium.month', 'premium.year'},
        scopeKey: 'google_play',
        loader: loader,
      );
      final secondFuture = cache.read(
        {'premium.month'},
        scopeKey: 'google_play',
        loader: loader,
      );

      expect(loadCalls, 1);

      completer.complete(
        const StoreProductAvailabilitySnapshot(
          isAvailable: true,
          productIds: {'premium.month', 'premium.year'},
          productPrices: {
            'premium.month': r'$14.99',
            'premium.year': r'$99.99',
          },
        ),
      );

      final results = await Future.wait([firstFuture, secondFuture]);
      expect(results[0].productIds, {'premium.month', 'premium.year'});
      expect(results[1].productIds, {'premium.month'});
      expect(results[1].productPrices, {'premium.month': r'$14.99'});
    },
  );

  test(
    'store product availability cache does not share in-flight lookups across scopes',
    () async {
      final firstCompleter = Completer<StoreProductAvailabilitySnapshot>();
      final secondCompleter = Completer<StoreProductAvailabilitySnapshot>();
      var loadCalls = 0;
      final cache = StoreProductAvailabilityCache();

      Future<StoreProductAvailabilitySnapshot> loader(Set<String> productIds) {
        loadCalls++;
        return loadCalls == 1 ? firstCompleter.future : secondCompleter.future;
      }

      final firstFuture = cache.read(
        {'premium.month', 'premium.year'},
        scopeKey: 'google_play',
        loader: loader,
      );
      final secondFuture = cache.read(
        {'premium.month'},
        scopeKey: 'app_store',
        loader: loader,
      );

      expect(loadCalls, 2);

      firstCompleter.complete(
        const StoreProductAvailabilitySnapshot(
          isAvailable: true,
          productIds: {'premium.month', 'premium.year'},
          productPrices: {'premium.month': r'$14.99'},
        ),
      );
      secondCompleter.complete(
        const StoreProductAvailabilitySnapshot(
          isAvailable: true,
          productIds: {'premium.month'},
          productPrices: {'premium.month': r'$15.99'},
        ),
      );

      final results = await Future.wait([firstFuture, secondFuture]);
      expect(results[0].productPrices['premium.month'], r'$14.99');
      expect(results[1].productPrices['premium.month'], r'$15.99');
    },
  );

  test(
    'store product availability cache isolates entries by scope key',
    () async {
      var loadCalls = 0;
      final cache = StoreProductAvailabilityCache();

      Future<StoreProductAvailabilitySnapshot> loader(
        Set<String> productIds,
      ) async {
        loadCalls++;
        return StoreProductAvailabilitySnapshot(
          isAvailable: true,
          productIds: productIds,
          productPrices: {
            for (final productId in productIds) productId: '\$7.99',
          },
        );
      }

      await cache.read(
        {'premium.month'},
        scopeKey: 'app_store',
        loader: loader,
      );
      await cache.read(
        {'premium.month'},
        scopeKey: 'app_store',
        loader: loader,
      );
      await cache.read(
        {'premium.month'},
        scopeKey: 'google_play',
        loader: loader,
      );

      expect(loadCalls, 2);
    },
  );

  test(
    'store product availability cache normalizes equivalent scope keys',
    () async {
      var loadCalls = 0;
      final cache = StoreProductAvailabilityCache();

      Future<StoreProductAvailabilitySnapshot> loader(
        Set<String> productIds,
      ) async {
        loadCalls++;
        return StoreProductAvailabilitySnapshot(
          isAvailable: true,
          productIds: productIds,
          productPrices: {
            for (final productId in productIds) productId: '\$7.99',
          },
        );
      }

      await cache.read(
        {'premium.month'},
        scopeKey: ' App_Store ',
        loader: loader,
      );
      await cache.read(
        {'premium.month'},
        scopeKey: 'app_store',
        loader: loader,
      );

      expect(loadCalls, 1);
    },
  );

  test('store product availability cache fingerprints scope keys', () {
    final source = File(
      'lib/shared/payments/store_product_availability_cache.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('final normalizedScopeKey = _normalizeScopeKey(scopeKey);'),
    );
    expect(source, contains('scopeKey: normalizedScopeKey'));
    expect(source, contains("return 'sha256:"));
    expect(source, isNot(contains('return value;')));
  });

  test(
    'store product availability cache bounds completed entries by recent use',
    () async {
      var loadCalls = 0;
      final cache = StoreProductAvailabilityCache(maxEntries: 2);

      Future<StoreProductAvailabilitySnapshot> loader(
        Set<String> productIds,
      ) async {
        loadCalls++;
        return StoreProductAvailabilitySnapshot(
          isAvailable: true,
          productIds: productIds,
          productPrices: {
            for (final productId in productIds) productId: '\$1.99',
          },
        );
      }

      await cache.read({'pack.a'}, loader: loader);
      await cache.read({'pack.b'}, loader: loader);
      await cache.read({'pack.a'}, loader: loader);
      await cache.read({'pack.c'}, loader: loader);
      await cache.read({'pack.b'}, loader: loader);
      await cache.read({'pack.a'}, loader: loader);

      expect(loadCalls, 5);
    },
  );
}
