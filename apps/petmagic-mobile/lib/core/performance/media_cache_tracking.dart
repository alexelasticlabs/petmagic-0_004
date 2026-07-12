import 'dart:collection';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache_budget.dart';

/// Bounds in-memory fetch bookkeeping and reads persisted cache validity.
final class MediaCacheTracking {
  MediaCacheTracking._();

  static void trimInvalidations(
    LinkedHashMap<String, int> invalidations,
    LinkedHashSet<String> blockedUrls, {
    required int maxEntries,
  }) {
    while (invalidations.length > maxEntries) {
      final oldestUrl = invalidations.keys.first;
      invalidations.remove(oldestUrl);
      blockedUrls.remove(oldestUrl);
    }
  }

  static void trimBlockedUrls(
    LinkedHashSet<String> blockedUrls, {
    required int maxEntries,
  }) {
    while (blockedUrls.length > maxEntries) {
      blockedUrls.remove(blockedUrls.first);
    }
  }

  static void rememberLatestGeneration(
    LinkedHashMap<String, int> generations,
    String url,
    int generation, {
    required int maxEntries,
  }) {
    generations.remove(url);
    generations[url] = generation;
    while (generations.length > maxEntries) {
      generations.remove(generations.keys.first);
    }
  }

  static void rememberInFlightFetch(
    Map<String, Future<File>> fetches,
    String url,
    Future<File> fetch, {
    required int maxEntries,
  }) {
    fetches.remove(url);
    fetches[url] = fetch;
    while (fetches.length > maxEntries) {
      fetches.remove(fetches.keys.first);
    }
  }

  static Future<DateTime> cacheValidTill(
    CacheManager cacheManager,
    String url, {
    required DateTime fallbackValidTill,
    required MediaCacheFailureLogger onFailure,
  }) async {
    try {
      return (await cacheManager.getFileFromCache(url))?.validTill ??
          fallbackValidTill;
    } catch (error, stackTrace) {
      onFailure('cache_valid_till_lookup', error, stackTrace);
      return fallbackValidTill;
    }
  }
}
