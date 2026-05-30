import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

class TemplatesQuery {
  const TemplatesQuery({
    this.type,
    this.category,
    this.search,
    this.cursor,
    this.page = 1,
    this.pageSize = 20,
  });

  final TemplateType? type;
  final String? category;
  final String? search;
  final String? cursor;
  final int page;
  final int pageSize;

  TemplatesQuery copyWith({
    TemplateType? type,
    bool clearType = false,
    String? category,
    bool clearCategory = false,
    String? search,
    bool clearSearch = false,
    String? cursor,
    bool clearCursor = false,
    int? page,
    int? pageSize,
    bool resetPage = false,
  }) {
    return TemplatesQuery(
      type: clearType ? null : type ?? this.type,
      category: clearCategory ? null : category ?? this.category,
      search: clearSearch ? null : search ?? this.search,
      cursor: clearCursor ? null : cursor ?? this.cursor,
      page: resetPage ? 1 : page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  String get cacheKey => [
    type?.apiValue ?? 'all',
    category?.trim().toLowerCase() ?? 'all',
    search?.trim().toLowerCase() ?? '',
    pageSize.toString(),
  ].join('|');

  Map<String, Object?> toQueryParameters() {
    return {
      if (type != null) 'type': type!.apiValue,
      if (category != null && category!.trim().isNotEmpty)
        'category': category!.trim(),
      'page': page,
      'pageSize': pageSize,
    };
  }
}
