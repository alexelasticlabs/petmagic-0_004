import 'package:petmagic_mobile/features/support/domain/support_chat_models.dart';

SupportChatConversation mapSupportChatConversationDto(
  Map<String, dynamic> json,
) {
  return SupportChatConversation(
    conversationId: json['conversationId'] as String? ?? '',
    initiatorUserId: json['initiatorUserId'] as String? ?? '',
    userEmail: json['userEmail'] as String? ?? '',
    userDisplayName: json['userDisplayName'] as String?,
    assignedAdminId: json['assignedAdminId'] as String?,
    assignedAdminDisplayName: json['assignedAdminDisplayName'] as String?,
    status: json['status'] as String? ?? 'New',
    priority: json['priority'] as String? ?? 'Normal',
    source: json['source'] as String? ?? 'MobileChat',
    assistantScenario: json['assistantScenario'] as String?,
    relatedGenerationId: json['relatedGenerationId'] as String?,
    relatedPaymentId: json['relatedPaymentId'] as String?,
    relatedSubscriptionId: json['relatedSubscriptionId'] as String?,
    userUnreadCount: json['userUnreadCount'] as int? ?? 0,
    adminUnreadCount: json['adminUnreadCount'] as int? ?? 0,
    createdAtUtc: _dateTimeOrEpoch(json['createdAtUtc']),
    updatedAtUtc: _dateTimeOrEpoch(json['updatedAtUtc']),
    lastMessageAtUtc: _dateTime(json['lastMessageAtUtc']),
    resolvedAtUtc: _dateTime(json['resolvedAtUtc']),
    reopenUntilUtc: _dateTime(json['reopenUntilUtc']),
    closedAtUtc: _dateTime(json['closedAtUtc']),
    feedbackRating: json['feedbackRating'] as int?,
    feedbackComment: json['feedbackComment'] as String?,
    feedbackSubmittedAtUtc: _dateTime(json['feedbackSubmittedAtUtc']),
    isReadOnly: json['isReadOnly'] as bool? ?? false,
    canReopen: json['canReopen'] as bool? ?? false,
    hasOlderMessages: json['hasOlderMessages'] as bool? ?? false,
    oldestLoadedMessageCreatedAtUtc: _dateTime(
      json['oldestLoadedMessageCreatedAtUtc'],
    ),
    messages: (json['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(mapSupportChatMessageDto)
        .toList(growable: false),
  );
}

SupportChatMessage mapSupportChatMessageDto(Map<String, dynamic> json) {
  final pendingAttachmentJson = json['pendingAttachment'];
  return SupportChatMessage(
    messageId: json['messageId'] as String? ?? '',
    conversationId: json['conversationId'] as String? ?? '',
    senderUserId: json['senderUserId'] as String? ?? '',
    senderDisplayName: json['senderDisplayName'] as String? ?? '',
    isFromAdmin: json['isFromAdmin'] as bool? ?? false,
    senderType: json['senderType'] as String? ?? 'User',
    body: json['body'] as String? ?? '',
    replyToMessageId: json['replyToMessageId'] as String?,
    replyToPreview: json['replyToPreview'] as String?,
    isRead: json['isRead'] as bool? ?? false,
    attachments: (json['attachments'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_mapSupportChatAttachmentDto)
        .where((attachment) => attachment.fileUrl.trim().isNotEmpty)
        .toList(growable: false),
    attachmentUploadStatus: json['attachmentUploadStatus'] as String?,
    attachmentUploadErrorCode: json['attachmentUploadErrorCode'] as String?,
    pendingAttachment: pendingAttachmentJson is Map<String, dynamic>
        ? _mapSupportChatPendingAttachmentDto(pendingAttachmentJson)
        : null,
    createdAtUtc: _dateTimeOrEpoch(json['createdAtUtc']),
    readAtUtc: _dateTime(json['readAtUtc']),
    deliveredAtUtc: _dateTime(json['deliveredAtUtc']),
  );
}

SupportChatAttachment _mapSupportChatAttachmentDto(Map<String, dynamic> json) {
  return SupportChatAttachment(
    fileUrl: json['fileUrl'] as String? ?? '',
    type: json['type'] as String? ?? 'file',
    mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
    fileName: json['fileName'] as String? ?? '',
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    isDeleted: json['isDeleted'] as bool? ?? false,
    expiresAtUtc: _dateTime(json['expiresAtUtc']),
    deletedAtUtc: _dateTime(json['deletedAtUtc']),
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
  );
}

SupportChatPendingAttachment _mapSupportChatPendingAttachmentDto(
  Map<String, dynamic> json,
) {
  return SupportChatPendingAttachment(
    fileName: json['fileName'] as String? ?? '',
    mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
  );
}

DateTime? _dateTime(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}

DateTime _dateTimeOrEpoch(Object? value) {
  return _dateTime(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}
