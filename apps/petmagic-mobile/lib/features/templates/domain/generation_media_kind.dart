import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

bool isVideoGenerationResult(TemplateGenerationResult generation) {
  final mediaType = generation.mediaType?.toLowerCase() ?? '';
  final type = generation.templateType?.toLowerCase() ?? '';
  return mediaType.contains('video') ||
      type.contains('video') ||
      generation.outputVideoDurationSeconds != null ||
      isLikelyGenerationVideoUrl(generation.outputUrl);
}

bool isLikelyGenerationVideoUrl(String? rawUrl) {
  final url = _cleanUrl(rawUrl);
  if (url == null) {
    return false;
  }

  final normalized = url.toLowerCase();
  final uri = Uri.tryParse(normalized);
  final path = (uri?.path ?? normalized).toLowerCase();
  final query = (uri?.query ?? '').toLowerCase();

  return path.endsWith('.mp4') ||
      path.endsWith('.webm') ||
      path.endsWith('.mov') ||
      path.endsWith('.m4v') ||
      normalized.contains('.mp4?') ||
      normalized.contains('.webm?') ||
      normalized.contains('.mov?') ||
      normalized.contains('.m4v?') ||
      query.contains('format=mp4') ||
      query.contains('ext=mp4') ||
      query.contains('contenttype=video');
}

bool isLikelyGenerationImageUrl(String? rawUrl) {
  final url = _cleanUrl(rawUrl);
  if (url == null) {
    return false;
  }

  final normalized = url.toLowerCase();
  final uri = Uri.tryParse(normalized);
  final path = (uri?.path ?? normalized).toLowerCase();

  return path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp') ||
      path.endsWith('.gif') ||
      path.endsWith('.heic') ||
      path.endsWith('.heif');
}

String? _cleanUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}
