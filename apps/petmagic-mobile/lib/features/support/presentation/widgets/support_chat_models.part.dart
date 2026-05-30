part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

const _supportSecondaryGreen = Color(0xFF76DBAE);
const _supportMessageGreen = Color(0xFF2F8068);
const _supportMessageGreenBorder = Color(0xFF4A9D83);
const _supportComposerSendGreen = Color(0xFF34BC81);
const _supportComposerIconColor = Color(0xFFA0AEC0);
const _supportComposerHintColor = Color(0xFF8A97A8);
const _supportAttachmentMaxCount = 5;
const _supportMediaGroupVisibleCellCount = 6;
const _supportAttachmentRecentAssetCount = 48;
const _supportAttachmentImageMaxFileSizeBytes = 10 * 1024 * 1024;
const _supportAttachmentVideoMaxFileSizeBytes = 50 * 1024 * 1024;
const _supportAttachmentVideoMaxDuration = Duration(seconds: 60);

bool _isSupportSystemMessage(SupportChatMessage message) {
  if (message.isSystemMessage) {
    return true;
  }

  if (!message.isFromAdmin) {
    return false;
  }

  final body = message.body.trim().toLowerCase();
  if (body.isEmpty) {
    return false;
  }

  return body.startsWith('сообщение получено') ||
      body.startsWith('message received') ||
      body.startsWith('сообщение доставлено') ||
      body.startsWith('message delivered') ||
      body.startsWith('message status') ||
      body.startsWith('delivery status') ||
      body.startsWith('статус доставки') ||
      body.startsWith('conversation status') ||
      body.startsWith('system:') ||
      body.startsWith('debug:');
}

List<SupportChatMessage> _visibleSupportThreadMessages(
  Iterable<SupportChatMessage> messages,
) {
  return messages
      .where((message) => !_isSupportSystemMessage(message))
      .toList(growable: false);
}

String _mapSupportError(AppLocalizations text, String raw) {
  final value = raw.toLowerCase();

  if (value.contains('support.attachment_file_too_large')) {
    return text.supportChatAttachmentTooLargeError;
  }

  if (value.contains('support.attachment_unavailable')) {
    return text.supportChatAttachmentUnavailableError;
  }

  if (value.contains('support.attachment_content_type_not_allowed') ||
      value.contains('support.attachment_mime_mismatch')) {
    return text.supportChatAttachmentUnsupportedFormatError;
  }

  if (value.contains('support.attachment_retry_not_allowed')) {
    return text.supportChatAttachmentUnavailableError;
  }

  if (value.contains('support.attachment_storage_failed')) {
    return text.supportChatAttachmentUnavailableError;
  }

  if (value.contains('support.unavailable') ||
      value.contains('support.request_failed')) {
    return text.supportChatUnavailableError;
  }

  if (value.contains('support.conversation_not_found') ||
      value.contains('support conversation was not found')) {
    return text.supportChatUnavailableError;
  }

  if (value.contains('auth.sign_in_required')) {
    return text.authSignInRequired;
  }

  if (value.contains('auth.session_expired')) {
    return text.authSessionExpired;
  }

  return raw;
}

enum _SupportAttachmentQuickAction { camera, video, files }

class _SupportQuickActionData {
  const _SupportQuickActionData({
    required this.icon,
    required this.label,
    required this.prompt,
  });

  final IconData icon;
  final String label;
  final String prompt;
}

class _PendingSupportAttachment {
  const _PendingSupportAttachment({
    required this.filePath,
    required this.fileName,
    required this.contentType,
    required this.isVideo,
    this.sourceAssetId,
  });

  final String filePath;
  final String fileName;
  final String contentType;
  final bool isVideo;
  final String? sourceAssetId;
}
