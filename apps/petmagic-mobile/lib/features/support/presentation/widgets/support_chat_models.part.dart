part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

const _supportSecondaryGreen = Color(0xFF69D8A7);
const _supportMessageGreen = Color(0xFF129369);
const _supportMessageGreenBorder = Color(0xFF0D7752);
const _supportComposerSendGreen = Color(0xFF34B77A);
const _supportComposerIconColor = Color(0xFFA0AEC0);
const _supportComposerHintColor = Color(0xFF7B8794);
const _supportAttachmentMaxFileSizeBytes = 10 * 1024 * 1024;

bool _isSupportSystemMessage(SupportChatMessage message) {
  if (!message.isFromAdmin) {
    return false;
  }

  final body = message.body.toLowerCase();
  return body.startsWith('сообщение получено') ||
      body.startsWith('message received') ||
      body.startsWith('сообщение доставлено') ||
      body.startsWith('message delivered');
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
    return text.supportChatAttachmentUnavailableError;
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

  if (value.contains('auth.sign_in_required')) {
    return text.authSignInRequired;
  }

  if (value.contains('auth.session_expired')) {
    return text.authSessionExpired;
  }

  return raw;
}

enum _SupportAttachmentAction { gallery }

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

class _SupportFaqItemData {
  const _SupportFaqItemData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _PendingSupportAttachment {
  const _PendingSupportAttachment({
    required this.filePath,
    required this.fileName,
    required this.contentType,
  });

  final String filePath;
  final String fileName;
  final String contentType;
}
