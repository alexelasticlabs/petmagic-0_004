part of 'app_navigator.dart';

final class TemplatesDestination extends AppDestination {
  const TemplatesDestination({
    this.petId,
    this.petPhotoId,
    this.category,
    this.autofocusSearch = false,
    this.payload,
  });

  final String? petId;
  final String? petPhotoId;
  final String? category;
  final bool autofocusSearch;
  final Object? payload;

  @override
  String get location {
    final normalizedPetId = petId?.trim();
    final normalizedPetPhotoId = petPhotoId?.trim();
    final normalizedCategory = category?.trim();
    final queryParameters = <String, String>{
      if (normalizedPetId?.isNotEmpty ?? false) 'petId': normalizedPetId!,
      if ((normalizedPetId?.isNotEmpty ?? false) &&
          (normalizedPetPhotoId?.isNotEmpty ?? false))
        'petPhotoId': normalizedPetPhotoId!,
      if (normalizedCategory?.isNotEmpty ?? false)
        'category': normalizedCategory!,
      if (autofocusSearch) 'autofocusSearch': '1',
    };
    return Uri(
      path: '/templates',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }

  @override
  Object? get extra => payload;
}

final class DiscoverDestination extends AppDestination {
  const DiscoverDestination();

  @override
  String get location => '/discover';
}
