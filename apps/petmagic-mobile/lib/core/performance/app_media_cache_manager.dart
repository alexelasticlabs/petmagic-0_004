import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';

/// Clears only reproducible media data held by the app.
///
/// Account data, preferences and server-side generations are intentionally not
/// part of this operation.
abstract final class AppMediaCacheManager {
  static Future<void> clearAll() async {
    await Future.wait<void>([
      TemplateMediaCache.clearAll(),
      _clearDefaultImageCache(),
    ]);
  }

  static Future<void> _clearDefaultImageCache() async {
    await DefaultCacheManager().emptyCache();
    imageCache.clear();
    imageCache.clearLiveImages();
  }
}
