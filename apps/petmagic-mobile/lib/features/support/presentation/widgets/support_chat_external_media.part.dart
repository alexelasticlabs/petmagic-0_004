part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

const _supportMediaDownloadTimeout = Duration(seconds: 20);

extension _SupportChatPageExternalMediaActions on _SupportChatPageState {
  Future<void> _openAttachmentExternallyImpl(String value) async {
    final uri = parseSafeExternalUri(value);
    if (uri == null) {
      if (!mounted) {
        return;
      }

      final text = AppLocalizations.of(context);
      _showSupportToast(
        text.supportChatUnavailableError,
        tone: PetMagicToastTone.warning,
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _saveImageToDeviceImpl({
    required String imageUrl,
    String? fileName,
  }) async {
    final text = AppLocalizations.of(context);
    try {
      final bytes = await _downloadImageBytesImpl(imageUrl);
      final safeFileName = _safeImageFileNameImpl(fileName);
      final wasSaved = await saveBytesToDevice(
        bytes: bytes,
        dialogTitle: text.supportChatSaveImageAction,
        fileName: safeFileName,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (!wasSaved) {
        return;
      }

      if (!mounted) {
        return;
      }

      _showSupportToast(
        text.supportChatImageSavedMessage,
        tone: PetMagicToastTone.success,
      );
    } on Object {
      if (!mounted) {
        return;
      }

      _showSupportToast(
        text.supportChatSaveImageFailedError,
        tone: PetMagicToastTone.warning,
      );
    }
  }

  Future<void> _shareImageImpl({
    required String imageUrl,
    String? fileName,
  }) async {
    final text = AppLocalizations.of(context);
    try {
      final safeUri = parseSafeExternalUri(imageUrl);
      if (safeUri == null) {
        throw const FormatException('unsupported_external_uri');
      }

      await shareRemoteMediaFile(
        mediaUrl: safeUri.toString(),
        fileName: _safeImageFileNameImpl(fileName),
        title: fileName ?? text.supportChatImageLabel,
        downloadTimeout: _supportMediaDownloadTimeout,
      );
    } on Object {
      if (!mounted) {
        return;
      }

      _showSupportToast(
        text.supportChatShareImageFailedError,
        tone: PetMagicToastTone.warning,
      );
    }
  }

  Future<List<int>> _downloadImageBytesImpl(String imageUrl) async {
    final safeUri = parseSafeExternalUri(imageUrl);
    if (safeUri == null) {
      throw const FormatException('unsupported_external_uri');
    }

    return downloadFileBytes(
      safeUri.toString(),
      timeout: _supportMediaDownloadTimeout,
    );
  }

  String _safeImageFileNameImpl(String? value) {
    final fallback =
        'support-image-${DateTime.now().millisecondsSinceEpoch}.jpg';
    return sanitizeFileName(value, fallback: fallback);
  }
}
