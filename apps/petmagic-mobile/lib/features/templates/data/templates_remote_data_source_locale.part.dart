part of 'templates_remote_data_source.dart';

extension _TemplateLocaleQueryParameters on AppRuntimeInfo {
  Map<String, Object?> localizedQueryParameters(
    Map<String, Object?> parameters,
  ) {
    final languageTag = locale.languageTag.trim();
    return languageTag.isEmpty || languageTag.toLowerCase().startsWith('en')
        ? parameters
        : <String, Object?>{...parameters, 'locale': languageTag};
  }
}
