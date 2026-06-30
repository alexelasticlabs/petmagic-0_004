part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

Color _supportSecondaryGreen(BuildContext context) {
  final colors = context.petMagicColors;
  final isLight = Theme.of(context).brightness == Brightness.light;
  return Color.lerp(
    colors.accent,
    colors.blue,
    isLight ? 0.18 : 0.28,
  )!.withValues(alpha: isLight ? 0.98 : 0.9);
}

Color _supportMessageGreen(BuildContext context) {
  final colors = context.petMagicColors;
  final isLight = Theme.of(context).brightness == Brightness.light;
  final base = Color.lerp(colors.accent, colors.blue, isLight ? 0.22 : 0.3)!;
  return Color.alphaBlend(
    Colors.black.withValues(alpha: isLight ? 0.34 : 0.2),
    base,
  );
}

Color _supportMessageGreenBorder(BuildContext context) {
  final colors = context.petMagicColors;
  final isLight = Theme.of(context).brightness == Brightness.light;
  final bubble = _supportMessageGreen(context);
  final softLift = isLight ? Colors.white : colors.surface;
  return Color.alphaBlend(
    softLift.withValues(alpha: isLight ? 0.2 : 0.12),
    bubble,
  );
}

Color _supportComposerSendGreen(BuildContext context) {
  return context.petMagicColors.accent;
}

Color _supportComposerIconColor(BuildContext context) {
  final colors = context.petMagicColors;
  return Color.lerp(colors.textMuted, colors.textSoft, 0.42)!;
}

Color _supportComposerHintColor(BuildContext context) {
  final colors = context.petMagicColors;
  return Color.lerp(colors.textMuted, colors.textSoft, 0.28)!;
}

const _supportAttachmentMaxCount = 5;
const _supportMediaGroupVisibleCellCount = 6;
const _supportAttachmentRecentAssetCount = 48;
const _supportAttachmentImageMaxFileSizeBytes =
    UploadMediaPolicy.supportImageMaxBytes;
const _supportAttachmentVideoMaxFileSizeBytes =
    UploadMediaPolicy.supportVideoMaxBytes;
const _supportAttachmentVideoMaxDuration = Duration(seconds: 60);

bool _isSupportSystemMessage(SupportChatMessage message) {
  return message.isSystemMessage;
}

List<SupportChatMessage> _visibleSupportThreadMessages(
  Iterable<SupportChatMessage> messages,
) {
  final visibleMessages = <SupportChatMessage>[];
  final seenMessageIds = <String>{};

  for (final message in messages) {
    if (_isSupportSystemMessage(message)) {
      continue;
    }

    final messageId = message.messageId.trim();
    if (messageId.isNotEmpty && !seenMessageIds.add(messageId)) {
      continue;
    }

    visibleMessages.add(message);
  }

  return visibleMessages;
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

  final authMessage = mapCommonAuthFeedbackMessage(text, value);
  if (authMessage != null) {
    return authMessage;
  }

  return text.supportChatUnavailableError;
}

enum _SupportAttachmentQuickAction { camera, video, files }

class _SupportQuickActionData {
  const _SupportQuickActionData({
    required this.icon,
    this.isPremium = false,
    required this.label,
    required this.prompt,
  });

  final IconData icon;
  final bool isPremium;
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
