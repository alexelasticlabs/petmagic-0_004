import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/application/template_feed_invalidation.dart';
import 'package:petmagic_mobile/features/templates/application/templates_feed_policy.dart';
import 'package:petmagic_mobile/features/templates/application/templates_state.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

/// Applies scoped catalog events without forcing a full feed reload.
final class TemplateScopedInvalidationHandler {
  const TemplateScopedInvalidationHandler({
    required this.repository,
    required this.readState,
    required this.writeState,
    required this.isMounted,
    required this.isScreenVisible,
  });

  final TemplatesRepository Function() repository;
  final TemplatesState Function() readState;
  final void Function(TemplatesState state) writeState;
  final bool Function() isMounted;
  final bool Function() isScreenVisible;

  Future<void> apply(TemplateFeedInvalidation invalidation) async {
    final templateId = invalidation.templateId;
    if (templateId == null || templateId.isEmpty || !isMounted()) return;

    final existing = _findLoadedTemplate(templateId);
    if (invalidation.isUnavailable) {
      _removeTemplate(templateId);
      return;
    }
    if (existing == null) return;

    if (invalidation.hasMediaChange &&
        invalidation.mediaVersion != existing.mediaVersion) {
      await _invalidateMediaCache(existing);
    }

    try {
      final updated = await repository().fetchTemplate(
        templateId,
        forceRefresh: true,
      );
      if (!isMounted() || !isScreenVisible()) return;

      final current = _findLoadedTemplate(templateId);
      if (current == null) return;
      _replaceTemplate(
        invalidation.hasMediaChange
            ? updated
            : _mergeMetadataKeepingMedia(current, updated),
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Controller',
        operation: 'scoped_template_invalidation',
        message: 'Scoped template invalidation failed.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'templateId': templateId,
          'scope': invalidation.scope,
          'reason': invalidation.reason,
        },
      );
    }
  }

  Future<void> refreshCategories() async {
    try {
      final categories = TemplatesFeedPolicy.normalizeCategories(
        await repository().fetchCategories(),
      );
      if (!isMounted() || !isScreenVisible()) return;
      writeState(readState().copyWith(categories: categories));
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Controller',
        operation: 'realtime_category_invalidation',
        message: 'Template categories scoped invalidation failed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  TemplateItem? _findLoadedTemplate(String templateId) {
    for (final item in readState().items) {
      if (item.templateId == templateId) return item;
    }
    return null;
  }

  void _replaceTemplate(TemplateItem template) {
    final current = readState();
    final items = current.items
        .map((item) => item.templateId == template.templateId ? template : item)
        .toList(growable: false);
    writeState(
      current.copyWith(
        items: items,
        cachedPagesByQueryKey: _mapCachedPages(
          current,
          (page) => _mapPageTemplate(page, template),
        ),
      ),
    );
  }

  void _removeTemplate(String templateId) {
    if (!isMounted()) return;
    final current = readState();
    final items = current.items
        .where((item) => item.templateId != templateId)
        .toList(growable: false);
    if (items.length == current.items.length) return;

    writeState(
      current.copyWith(
        items: items,
        cachedPagesByQueryKey: _mapCachedPages(
          current,
          (page) => _removePageTemplate(page, templateId),
        ),
      ),
    );
  }

  Map<String, TemplatesFeedPage> _mapCachedPages(
    TemplatesState current,
    TemplatesFeedPage Function(TemplatesFeedPage page) mapPage,
  ) {
    if (current.cachedPagesByQueryKey.isEmpty) {
      return current.cachedPagesByQueryKey;
    }
    return current.cachedPagesByQueryKey.map(
      (key, page) => MapEntry(key, mapPage(page)),
    );
  }

  TemplatesFeedPage _mapPageTemplate(
    TemplatesFeedPage page,
    TemplateItem template,
  ) {
    return TemplatesFeedPage(
      items: page.items
          .map(
            (item) => item.templateId == template.templateId ? template : item,
          )
          .toList(growable: false),
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
      page: page.page,
    );
  }

  TemplatesFeedPage _removePageTemplate(
    TemplatesFeedPage page,
    String templateId,
  ) {
    return TemplatesFeedPage(
      items: page.items
          .where((item) => item.templateId != templateId)
          .toList(growable: false),
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
      page: page.page,
    );
  }

  Future<void> _invalidateMediaCache(TemplateItem template) async {
    final mediaUrls = <String>{
      ...[
        TemplatesFeedPolicy.normalizeMediaUrl(template.thumbnailUrl),
        TemplatesFeedPolicy.normalizeMediaUrl(template.animatedPreviewUrl),
        TemplatesFeedPolicy.normalizeMediaUrl(template.feedLoopLowUrl),
        TemplatesFeedPolicy.normalizeMediaUrl(template.feedLoopMediumUrl),
        TemplatesFeedPolicy.normalizeMediaUrl(template.detailPreviewUrl),
        TemplatesFeedPolicy.normalizeMediaUrl(template.previewAsset?.url),
      ].whereType<String>(),
    };
    for (final url in mediaUrls) {
      await TemplateMediaCache.removeThumbnailFile(
        url,
        mediaVersion: template.mediaVersion,
      );
      await TemplateMediaCache.removePreviewFile(
        url,
        mediaVersion: template.mediaVersion,
      );
    }
    AppLogger.debug(
      feature: 'Templates.Controller',
      operation: 'mobile_media_redownload_after_sse',
      message: 'Invalidated scoped template media cache after SSE.',
      context: {
        'templateId': template.templateId,
        'mediaVersion': template.mediaVersion,
        'mediaUrls': mediaUrls.length,
      },
    );
  }

  TemplateItem _mergeMetadataKeepingMedia(
    TemplateItem current,
    TemplateItem updated,
  ) {
    return TemplateItem(
      templateId: updated.templateId,
      templateType: updated.templateType,
      title: updated.title,
      shortDescription: updated.shortDescription,
      petPhotoRequirements: updated.petPhotoRequirements,
      category: updated.category,
      tags: updated.tags,
      isPremium: updated.isPremium,
      tokenCost: updated.tokenCost,
      effectivePromoBadge: updated.effectivePromoBadge,
      thumbnailUrl: current.thumbnailUrl,
      animatedPreviewUrl: current.animatedPreviewUrl,
      feedLoopLowUrl: current.feedLoopLowUrl,
      feedLoopMediumUrl: current.feedLoopMediumUrl,
      detailPreviewUrl: current.detailPreviewUrl,
      mediaKind: current.mediaKind,
      durationMs: current.durationMs,
      sizeBytes: current.sizeBytes,
      mediaVersion: current.mediaVersion,
      previewAsset: current.previewAsset,
      musicDescription: updated.musicDescription,
      referenceVideoDurationSeconds: updated.referenceVideoDurationSeconds,
      supportsGenerationResultInput: updated.supportsGenerationResultInput,
      requiredInputMediaType: updated.requiredInputMediaType,
      recommendedAfterImageGeneration: updated.recommendedAfterImageGeneration,
      supportsGenerateSimilar: updated.supportsGenerateSimilar,
      defaultVariationStrength: updated.defaultVariationStrength,
      version: updated.version,
      updatedAtUtc: updated.updatedAtUtc,
    );
  }
}
