import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';

void logSupportTicketFailure(
  String stage,
  Object error,
  StackTrace stackTrace, {
  Map<String, Object?> context = const {},
}) {
  final payload = <String, Object>{'stage': stage};
  for (final entry in context.entries) {
    final value = entry.value;
    if (value != null) {
      payload[entry.key] = value.toString();
    }
  }

  AppLogger.warn(
    feature: 'Support.TicketForm',
    operation: stage,
    message: 'Support ticket step failed',
    context: payload,
    error: error,
    stackTrace: stackTrace,
  );
}

String resolveSupportTicketContentType(String path) {
  final normalized = path.toLowerCase();
  if (normalized.endsWith('.png')) {
    return 'image/png';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

String? supportTicketGuidOrNull(String? raw) {
  if (raw == null) {
    return null;
  }

  final value = raw.trim();
  final guidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  return guidPattern.hasMatch(value) ? value : null;
}

String mapSupportTicketError(AppLocalizations text, String code) {
  final authMessage = mapCommonAuthFeedbackMessage(text, code);
  if (authMessage != null) {
    return authMessage;
  }

  final normalized = code.toLowerCase();
  if (normalized.contains('attachment_file_too_large')) {
    return text.supportChatAttachmentTooLargeError;
  }
  if (normalized.contains('attachment_file_required') ||
      normalized.contains('attachment_file_name_required') ||
      normalized.contains('attachment_file_name_too_long') ||
      normalized.contains('attachment_content_type_too_long') ||
      normalized.contains('attachment_content_type_not_allowed')) {
    return text.supportChatAttachmentUnavailableError;
  }
  return text.supportChatUnavailableError;
}
