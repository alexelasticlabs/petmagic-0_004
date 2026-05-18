import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/templates/data/templates_cache_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

final templatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  return DefaultTemplatesRepository(
    remoteDataSource: ref.watch(templatesRemoteDataSourceProvider),
    cacheDataSource: ref.watch(templatesCacheDataSourceProvider),
  );
});

abstract interface class TemplatesRepository {
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query);

  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query);

  Future<List<String>> fetchCategories();
}

class DefaultTemplatesRepository implements TemplatesRepository {
  const DefaultTemplatesRepository({
    required TemplatesRemoteDataSource remoteDataSource,
    required TemplatesCacheDataSource cacheDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _cacheDataSource = cacheDataSource;

  final TemplatesRemoteDataSource _remoteDataSource;
  final TemplatesCacheDataSource _cacheDataSource;

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    final dto = await _cacheDataSource.readFirstPage(
      query.copyWith(clearCursor: true),
    );
    return dto?.toDomain();
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    final dto = await _remoteDataSource.fetchFeed(query);
    await _cacheDataSource.writeFirstPage(query, dto);
    return dto.toDomain();
  }

  @override
  Future<List<String>> fetchCategories() => _remoteDataSource.fetchCategories();
}
