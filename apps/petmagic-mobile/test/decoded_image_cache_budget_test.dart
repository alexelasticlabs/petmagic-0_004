import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/performance/decoded_image_cache_budget.dart';

void main() {
  test('decoded image cache budget applies production-safe app limits', () {
    final cache = ImageCache();

    configureDecodedImageCacheBudget(imageCache: cache);

    expect(cache.maximumSize, AppConfig.decodedImageCacheMaxObjectsSafe);
    expect(cache.maximumSizeBytes, AppConfig.decodedImageCacheMaxBytesSafe);
  });

  test('decoded image cache trim clears keep-alive and live image entries', () {
    final cache = _SpyImageCache();

    trimDecodedImageCache(imageCache: cache);

    expect(cache.clearCalls, 1);
    expect(cache.clearLiveImagesCalls, 1);
  });

  test(
    'decoded image cache lifecycle observer is installed in app shell',
    () async {
      final budgetSource = await File(
        'lib/core/performance/decoded_image_cache_budget.dart',
      ).readAsString();
      final appSource = await File('lib/app/app.dart').readAsString();

      expect(budgetSource, contains('with WidgetsBindingObserver'));
      expect(
        budgetSource,
        contains('WidgetsBinding.instance.addObserver(this)'),
      );
      expect(
        budgetSource,
        contains('WidgetsBinding.instance.removeObserver(this)'),
      );
      expect(budgetSource, contains('state == AppLifecycleState.resumed'));
      expect(budgetSource, contains('configureDecodedImageCacheBudget();'));
      expect(budgetSource, contains('trimDecodedImageCache();'));
      expect(appSource, contains('DecodedImageCacheLifecycleObserver('));
    },
  );
}

class _SpyImageCache extends ImageCache {
  int clearCalls = 0;
  int clearLiveImagesCalls = 0;

  @override
  void clear() {
    clearCalls += 1;
    super.clear();
  }

  @override
  void clearLiveImages() {
    clearLiveImagesCalls += 1;
    super.clearLiveImages();
  }
}
