import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/support/domain/support_chat_models.dart';

bool isSupportConversationNotFound(AppException error) {
  return error.isSupportConversationNotFound;
}

bool isSupportConversationReadOnlyForUser(
  SupportChatConversation conversation,
) {
  final normalizedStatus = conversation.status.trim().toLowerCase();
  if (normalizedStatus == 'closed') {
    return false;
  }

  return conversation.isReadOnly;
}
