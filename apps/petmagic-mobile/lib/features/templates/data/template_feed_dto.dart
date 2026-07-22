import 'package:petmagic_mobile/features/templates/data/template_item_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

class TemplatesFeedDto {
  const TemplatesFeedDto({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    required this.page,
  });

  final List<TemplateItemDto> items;
  final bool hasMore;
  final String? nextCursor;
  final int page;

  factory TemplatesFeedDto.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];

    return TemplatesFeedDto(
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => TemplateItemDto.fromJson(Map<String, Object?>.from(item)),
          )
          .toList(growable: false),
      nextCursor: json['nextCursor'] as String?,
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'nextCursor': nextCursor,
    'page': page,
    'hasMore': hasMore,
  };

  TemplatesFeedPage toDomain() => TemplatesFeedPage(
    items: items.map((item) => item.toDomain()).toList(growable: false),
    nextCursor: nextCursor,
    hasMore: hasMore,
    page: page,
  );
}

class TemplatesCatalogVersionDto {
  const TemplatesCatalogVersionDto({required this.version});

  final int version;

  factory TemplatesCatalogVersionDto.fromJson(Map<String, Object?> json) {
    return TemplatesCatalogVersionDto(
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }
}

class TemplatesCatalogChangesDto {
  const TemplatesCatalogChangesDto({
    required this.fromVersion,
    required this.toVersion,
    required this.upserts,
    required this.deletedIds,
    required this.needsFullResync,
  });

  final int fromVersion;
  final int toVersion;
  final List<TemplateItemDto> upserts;
  final List<String> deletedIds;
  final bool needsFullResync;

  factory TemplatesCatalogChangesDto.fromJson(Map<String, Object?> json) {
    final rawUpserts = json['upserts'] as List<dynamic>? ?? const [];
    final rawDeletedIds = json['deletedIds'] as List<dynamic>? ?? const [];

    return TemplatesCatalogChangesDto(
      fromVersion: (json['fromVersion'] as num?)?.toInt() ?? 0,
      toVersion: (json['toVersion'] as num?)?.toInt() ?? 0,
      upserts: rawUpserts
          .whereType<Map>()
          .map(
            (item) => TemplateItemDto.fromJson(Map<String, Object?>.from(item)),
          )
          .toList(growable: false),
      deletedIds: rawDeletedIds.map((item) => item.toString()).toList(),
      needsFullResync: json['needsFullResync'] as bool? ?? false,
    );
  }

  TemplatesCatalogChanges toDomain() {
    return TemplatesCatalogChanges(
      fromVersion: fromVersion,
      toVersion: toVersion,
      upserts: upserts.map((item) => item.toDomain()).toList(growable: false),
      deletedIds: deletedIds,
      needsFullResync: needsFullResync,
    );
  }
}

class PublicRandomTemplateDto {
  const PublicRandomTemplateDto({required this.template});

  final TemplateItemDto? template;

  factory PublicRandomTemplateDto.fromJson(Map<String, Object?> json) {
    final rawTemplate = json['template'];
    return PublicRandomTemplateDto(
      template: rawTemplate is Map
          ? TemplateItemDto.fromJson(Map<String, Object?>.from(rawTemplate))
          : null,
    );
  }

  TemplateItem? toDomain() => template?.toDomain();
}
