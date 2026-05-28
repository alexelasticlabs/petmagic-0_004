enum SupportAttachmentValidationError {
  unsupportedFormat,
  fileTooLarge,
  videoTooLong,
}

class SupportAttachmentValidationResult {
  const SupportAttachmentValidationResult({
    required this.isAllowed,
    required this.isVideo,
    this.error,
  });

  final bool isAllowed;
  final bool isVideo;
  final SupportAttachmentValidationError? error;
}

class SupportAttachmentValidation {
  const SupportAttachmentValidation._();

  static const imageMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static const videoMimeTypes = <String>{
    'video/mp4',
    'video/quicktime',
  };

  static SupportAttachmentValidationResult validate({
    required String contentType,
    required int fileSizeBytes,
    required int imageMaxBytes,
    required int videoMaxBytes,
    required Duration videoMaxDuration,
    Duration? videoDuration,
  }) {
    final normalized = contentType.toLowerCase();
    final isImage = imageMimeTypes.contains(normalized);
    final isVideo = videoMimeTypes.contains(normalized);
    if (!isImage && !isVideo) {
      return const SupportAttachmentValidationResult(
        isAllowed: false,
        isVideo: false,
        error: SupportAttachmentValidationError.unsupportedFormat,
      );
    }

    if (isImage && fileSizeBytes > imageMaxBytes) {
      return const SupportAttachmentValidationResult(
        isAllowed: false,
        isVideo: false,
        error: SupportAttachmentValidationError.fileTooLarge,
      );
    }

    if (isVideo && fileSizeBytes > videoMaxBytes) {
      return const SupportAttachmentValidationResult(
        isAllowed: false,
        isVideo: true,
        error: SupportAttachmentValidationError.fileTooLarge,
      );
    }

    if (isVideo &&
        videoDuration != null &&
        videoDuration > videoMaxDuration) {
      return const SupportAttachmentValidationResult(
        isAllowed: false,
        isVideo: true,
        error: SupportAttachmentValidationError.videoTooLong,
      );
    }

    return SupportAttachmentValidationResult(
      isAllowed: true,
      isVideo: isVideo,
    );
  }
}
