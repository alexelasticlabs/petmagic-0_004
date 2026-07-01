part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

extension _SupportChatPagePreviewActions on _SupportChatPageState {
  Future<void> _openImageFullscreenImpl({
    required String imageUrl,
    String? fileName,
  }) async {
    final safeUri = parseSafeSupportExternalUri(imageUrl);
    if (safeUri == null) {
      if (mounted) {
        _showSupportToast(
          AppLocalizations.of(context).supportChatUnavailableError,
          tone: PetMagicToastTone.warning,
        );
      }
      return;
    }

    final safeImageUrl = safeUri.toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SupportImagePreviewDialog(
          imageUrl: safeImageUrl,
          fileName: fileName,
          onSaveImage: () => _saveImageToDeviceImpl(
            imageUrl: safeImageUrl,
            fileName: fileName,
          ),
          onShareImage: () =>
              _shareImageImpl(imageUrl: safeImageUrl, fileName: fileName),
          onOpenOriginal: () => _openAttachmentExternallyImpl(safeImageUrl),
        );
      },
    );
  }

  Future<void> _openVideoFullscreenImpl({
    required String videoUrl,
    String? fileName,
  }) async {
    final safeUri = parseSafeSupportExternalUri(videoUrl);
    if (safeUri == null) {
      if (mounted) {
        _showSupportToast(
          AppLocalizations.of(context).supportChatUnavailableError,
          tone: PetMagicToastTone.warning,
        );
      }
      return;
    }

    final safeVideoUrl = safeUri.toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SupportVideoPreviewDialog(
          videoUrl: safeVideoUrl,
          fileName: fileName,
          onOpenOriginal: () => _openAttachmentExternallyImpl(safeVideoUrl),
        );
      },
    );
  }

  String _formatDayLabelImpl(DateTime value) {
    final localValue = value.toLocal();
    final localNow = DateTime.now();
    if (_isSameDayImpl(localValue, localNow)) {
      return AppLocalizations.of(context).supportChatTodayLabel;
    }

    return DateFormat(
      'MMM d',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(localValue);
  }

  bool _isSameDayImpl(DateTime left, DateTime right) {
    final localLeft = left.toLocal();
    final localRight = right.toLocal();
    return localLeft.year == localRight.year &&
        localLeft.month == localRight.month &&
        localLeft.day == localRight.day;
  }
}
