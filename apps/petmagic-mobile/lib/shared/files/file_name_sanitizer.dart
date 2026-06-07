String sanitizeFileName(String? value, {required String fallback}) {
  final candidate = value?.trim();
  if (candidate == null || candidate.isEmpty) {
    return fallback;
  }

  final normalized = candidate
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  return normalized.isEmpty ? fallback : normalized;
}
