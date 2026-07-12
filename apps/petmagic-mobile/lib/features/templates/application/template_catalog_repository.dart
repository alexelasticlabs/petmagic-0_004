import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';

final templatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  throw StateError(
    'TemplatesRepository is not bound. Add the app composition overrides.',
  );
});

abstract interface class TemplatesRepository {
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query);
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query);
  void cancelPendingFeedRequest();
  void cancelPendingRandomTemplateRequest();
  void cancelPendingMetadataRequests();

  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
  });

  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
  });

  Future<List<TemplateItem>> readSyncedCatalogItems();
  Future<TemplateOfTheDayItem?> fetchTemplateOfTheDay();

  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? source,
    String? generationId,
    Map<String, Object?>? metadata,
  });

  Future<List<String>> fetchCategories();
  Future<int> readLocalCatalogVersion();
  Future<int> fetchCatalogVersion();
  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion);
  Future<int> syncCatalog({int? knownRemoteVersion});
}
