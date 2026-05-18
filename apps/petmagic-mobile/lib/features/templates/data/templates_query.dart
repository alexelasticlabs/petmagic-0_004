import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

class TemplatesQuery {
  const TemplatesQuery({
    this.type,
    this.category,
    this.search,
    this.take = 20,
    this.cursor,
  });

  final TemplateType? type;
  final String? category;
  final String? search;
  final int take;
  final String? cursor;

  TemplatesQuery copyWith({
    TemplateType? type,
    bool clearType = false,
    String? category,
    bool clearCategory = false,
    String? search,
    bool clearSearch = false,
    int? take,
    String? cursor,
    bool clearCursor = false,
  }) {
    return TemplatesQuery(
      type: clearType ? null : type ?? this.type,
      category: clearCategory ? null : category ?? this.category,
      search: clearSearch ? null : search ?? this.search,
      take: take ?? this.take,
      cursor: clearCursor ? null : cursor ?? this.cursor,
    );
  }

  String get cacheKey => [
    type?.apiValue ?? 'all',
    category?.trim().toLowerCase() ?? 'all',
    search?.trim().toLowerCase() ?? '',
    take.toString(),
  ].join('|');

  Map<String, Object?> toQueryParameters() {
    return {
      if (type != null) 'type': type!.apiValue,
      if (category != null && category!.trim().isNotEmpty)
        'category': category!.trim(),
      if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
      'take': take,
      if (cursor != null) 'cursor': cursor,
    };
  }
}
