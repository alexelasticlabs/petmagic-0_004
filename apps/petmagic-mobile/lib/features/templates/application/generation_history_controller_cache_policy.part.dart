part of 'generation_history_controller.dart';

class _GenerationHistoryLoadRequest {
  const _GenerationHistoryLoadRequest({
    required this.filter,
    required this.refresh,
  });

  final GenerationHistoryFilter filter;
  final bool refresh;
}

String _historyLoadErrorMessage(Object error) {
  if (error is AppException) {
    final message = normalizeTemplateErrorKey(error.message);
    final safeMessage = switch (message) {
      'templates.connection_timeout' => message,
      'templates.server_timeout' => message,
      'templates.request_failed' => message,
      _ => null,
    };
    if (safeMessage != null) {
      return safeMessage;
    }

    final statusCode = error.statusCode;
    if (statusCode == 401) {
      return 'auth.session_expired';
    }
    if (statusCode == 408) {
      return 'templates.connection_timeout';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'templates.server_timeout';
    }

    return 'templates.request_failed';
  }

  return 'templates.request_failed';
}

bool _isCancelledRequest(Object error) {
  return error is RequestCancelledException;
}

bool _localRecordMatchesGeneration(
  GenerationGalleryMediaRecordView record,
  TemplateGenerationResult generation,
) {
  final previewUrl = _historyPreviewUrl(generation);
  final outputUrl = _safeGenerationMediaUrl(generation.outputUrl);
  if (previewUrl == null && outputUrl == null) {
    return false;
  }

  return _safeNullableMediaUrlEquals(record.previewRemoteUrl, previewUrl) &&
      _safeNullableMediaUrlEquals(record.outputRemoteUrl, outputUrl);
}

String? _historyPreviewUrl(TemplateGenerationResult generation) {
  final resultPreview = _safeGenerationMediaUrl(generation.resultPreviewUrl);
  final output = _safeGenerationMediaUrl(generation.outputUrl);
  final source = _safeGenerationMediaUrl(generation.sourceImageAsset?.url);
  final normalized = _safeGenerationMediaUrl(generation.normalizedImageUrl);
  final generationIsVideo = isVideoGenerationResult(generation);

  if (resultPreview != null && !isLikelyGenerationVideoUrl(resultPreview)) {
    return resultPreview;
  }

  if (generationIsVideo) {
    if (source != null) {
      return source;
    }
    if (normalized != null) {
      return normalized;
    }
    return output != null && isLikelyGenerationImageUrl(output) ? output : null;
  }

  if (output != null && !isLikelyGenerationVideoUrl(output)) {
    return output;
  }
  if (source != null) {
    return source;
  }
  if (normalized != null) {
    return normalized;
  }
  return null;
}

String? _safeGenerationMediaUrl(String? raw) {
  return parseSafeGenerationMediaUri(raw)?.toString();
}

bool _safeNullableMediaUrlEquals(String? left, String? right) {
  if (left == null && right == null) {
    return true;
  }
  if (left == null || right == null) {
    return false;
  }
  final leftUri = parseSafeGenerationMediaUri(left);
  final rightUri = parseSafeGenerationMediaUri(right);
  return leftUri != null &&
      rightUri != null &&
      leftUri.toString() == rightUri.toString();
}

// Generation history application cache orchestration.
