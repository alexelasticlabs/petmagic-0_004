import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferencesAsync>(
  (ref) => SharedPreferencesAsync(),
);

final templatesCacheDataSourceProvider = Provider<TemplatesCacheDataSource>((
  ref,
) {
  return TemplatesCacheDataSource(ref.watch(sharedPreferencesProvider));
});

class TemplatesCacheDataSource {
  const TemplatesCacheDataSource(this._preferences);

  static const _prefix = 'templates_feed_v1:';

  final SharedPreferencesAsync _preferences;

  Future<TemplatesFeedDto?> readFirstPage(TemplatesQuery query) async {
    if (query.cursor != null) return null;
    final raw = await _preferences.getString('$_prefix${query.cacheKey}');
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    return TemplatesFeedDto.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<void> writeFirstPage(
    TemplatesQuery query,
    TemplatesFeedDto page,
  ) async {
    if (query.cursor != null) return;
    await _preferences.setString(
      '$_prefix${query.cacheKey}',
      jsonEncode(page.toJson()),
    );
  }
}
