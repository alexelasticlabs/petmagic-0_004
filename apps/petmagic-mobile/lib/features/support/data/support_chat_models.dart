class SupportChatAttachment {
  const SupportChatAttachment({
    required this.fileUrl,
    required this.type,
    required this.mimeType,
    required this.fileName,
    required this.sizeBytes,
    this.isDeleted = false,
    this.expiresAtUtc,
    this.deletedAtUtc,
    this.durationSeconds,
    this.width,
    this.height,
  });

  final String fileUrl;
  final String type;
  final String mimeType;
  final String fileName;
  final int sizeBytes;
  final bool isDeleted;
  final DateTime? expiresAtUtc;
  final DateTime? deletedAtUtc;
  final double? durationSeconds;
  final int? width;
  final int? height;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');

  factory SupportChatAttachment.fromJson(Map<String, dynamic> json) {
    return SupportChatAttachment(
      fileUrl: json['fileUrl'] as String? ?? '',
      type: json['type'] as String? ?? 'file',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      fileName: json['fileName'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      isDeleted: json['isDeleted'] as bool? ?? false,
      expiresAtUtc: DateTime.tryParse(json['expiresAtUtc'] as String? ?? ''),
      deletedAtUtc: DateTime.tryParse(json['deletedAtUtc'] as String? ?? ''),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }
}

class SupportChatUploadAttachment {
  const SupportChatUploadAttachment({
    required this.filePath,
    required this.fileName,
    required this.contentType,
  });

  final String filePath;
  final String fileName;
  final String contentType;
}

class SupportChatPendingAttachment {
  const SupportChatPendingAttachment({
    required this.fileName,
    required this.mimeType,
    this.sizeBytes,
  });

  final String fileName;
  final String mimeType;
  final int? sizeBytes;

  factory SupportChatPendingAttachment.fromJson(Map<String, dynamic> json) {
    return SupportChatPendingAttachment(
      fileName: json['fileName'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
    );
  }
}

class SupportChatMessage {
  const SupportChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.isFromAdmin,
    required this.senderType,
    required this.body,
    required this.isRead,
    required this.createdAtUtc,
    required this.attachments,
    this.replyToMessageId,
    this.replyToPreview,
    this.attachmentUploadStatus,
    this.attachmentUploadErrorCode,
    this.pendingAttachment,
    this.readAtUtc,
    this.deliveredAtUtc,
  });

  final String messageId;
  final String conversationId;
  final String senderUserId;
  final String senderDisplayName;
  final bool isFromAdmin;
  final String senderType;
  final String body;
  final String? replyToMessageId;
  final String? replyToPreview;
  final bool isRead;
  final DateTime createdAtUtc;
  final List<SupportChatAttachment> attachments;
  final String? attachmentUploadStatus;
  final String? attachmentUploadErrorCode;
  final SupportChatPendingAttachment? pendingAttachment;
  final DateTime? readAtUtc;
  final DateTime? deliveredAtUtc;

  bool get isSystemMessage => senderType == 'System';
  bool get isBotMessage => senderType == 'Bot';
  bool get isUserMessage => senderType == 'User';

  SupportChatAttachment? get primaryAttachment =>
      attachments.isEmpty ? null : attachments.first;

  String? get attachmentDisplayFileName {
    final attachment = primaryAttachment;
    if (attachment != null && attachment.fileName.trim().isNotEmpty) {
      return attachment.fileName.trim();
    }

    final pendingFileName = pendingAttachment?.fileName.trim();
    if (pendingFileName == null || pendingFileName.isEmpty) {
      return null;
    }

    return pendingFileName;
  }

  int? get attachmentDisplaySizeBytes =>
      primaryAttachment?.sizeBytes ?? pendingAttachment?.sizeBytes;

  bool get hasAttachment => attachments.isNotEmpty;

  bool get hasImageAttachment =>
      attachments.length == 1 && (primaryAttachment?.isImage ?? false);

  bool get hasVideoAttachment =>
      attachments.length == 1 && (primaryAttachment?.isVideo ?? false);

  bool get hasMediaGroup => attachments.length > 1;

  String? get normalizedAttachmentUploadStatus {
    final value = attachmentUploadStatus?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  bool get isAttachmentUploading =>
      normalizedAttachmentUploadStatus?.toLowerCase() == 'uploading';

  bool get isAttachmentUploaded =>
      normalizedAttachmentUploadStatus?.toLowerCase() == 'uploaded';

  bool get isAttachmentFailed =>
      normalizedAttachmentUploadStatus?.toLowerCase() == 'failed';

  bool get canRetryAttachment => isAttachmentFailed;

  SupportChatMessage copyWith({
    bool? isRead,
    DateTime? readAtUtc,
    String? attachmentUploadStatus,
    String? attachmentUploadErrorCode,
    SupportChatPendingAttachment? pendingAttachment,
    List<SupportChatAttachment>? attachments,
    DateTime? deliveredAtUtc,
    String? replyToMessageId,
    String? replyToPreview,
    bool clearAttachmentUploadErrorCode = false,
    bool clearReadAt = false,
  }) {
    return SupportChatMessage(
      messageId: messageId,
      conversationId: conversationId,
      senderUserId: senderUserId,
      senderDisplayName: senderDisplayName,
      isFromAdmin: isFromAdmin,
      senderType: senderType,
      body: body,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToPreview: replyToPreview ?? this.replyToPreview,
      isRead: isRead ?? this.isRead,
      createdAtUtc: createdAtUtc,
      attachments: attachments ?? this.attachments,
      attachmentUploadStatus:
          attachmentUploadStatus ?? this.attachmentUploadStatus,
      attachmentUploadErrorCode: clearAttachmentUploadErrorCode
          ? null
          : (attachmentUploadErrorCode ?? this.attachmentUploadErrorCode),
      pendingAttachment: pendingAttachment ?? this.pendingAttachment,
      readAtUtc: clearReadAt ? null : (readAtUtc ?? this.readAtUtc),
      deliveredAtUtc: deliveredAtUtc ?? this.deliveredAtUtc,
    );
  }

  factory SupportChatMessage.fromJson(Map<String, dynamic> json) {
    final parsedAttachments = _parseAttachments(json);
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
      attachments: parsedAttachments,
      attachmentUploadStatus: json['attachmentUploadStatus'] as String?,
      attachmentUploadErrorCode: json['attachmentUploadErrorCode'] as String?,
      pendingAttachment: pendingAttachmentJson is Map<String, dynamic>
          ? SupportChatPendingAttachment.fromJson(pendingAttachmentJson)
          : null,
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAtUtc: DateTime.tryParse(json['readAtUtc'] as String? ?? ''),
      deliveredAtUtc: DateTime.tryParse(
        json['deliveredAtUtc'] as String? ?? '',
      ),
    );
  }

  static List<SupportChatAttachment> _parseAttachments(
    Map<String, dynamic> json,
  ) {
    return (json['attachments'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SupportChatAttachment.fromJson)
        .where((attachment) => attachment.fileUrl.trim().isNotEmpty)
        .toList(growable: false);
  }
}

class SupportChatConversation {
  const SupportChatConversation({
    required this.conversationId,
    required this.initiatorUserId,
    required this.userEmail,
    required this.userDisplayName,
    required this.assignedAdminId,
    required this.assignedAdminDisplayName,
    required this.status,
    required this.priority,
    required this.source,
    required this.userUnreadCount,
    required this.adminUnreadCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.lastMessageAtUtc,
    required this.messages,
    this.hasOlderMessages = false,
    this.oldestLoadedMessageCreatedAtUtc,
    this.assistantScenario,
    this.relatedGenerationId,
    this.relatedPaymentId,
    this.relatedSubscriptionId,
    this.resolvedAtUtc,
    this.reopenUntilUtc,
    this.closedAtUtc,
    this.feedbackRating,
    this.feedbackComment,
    this.feedbackSubmittedAtUtc,
    this.isReadOnly = false,
    this.canReopen = false,
  });

  final String conversationId;
  final String initiatorUserId;
  final String userEmail;
  final String? userDisplayName;
  final String? assignedAdminId;
  final String? assignedAdminDisplayName;
  final String status;
  final String priority;
  final String source;
  final String? assistantScenario;
  final String? relatedGenerationId;
  final String? relatedPaymentId;
  final String? relatedSubscriptionId;
  final int userUnreadCount;
  final int adminUnreadCount;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? lastMessageAtUtc;
  final DateTime? resolvedAtUtc;
  final DateTime? reopenUntilUtc;
  final DateTime? closedAtUtc;
  final int? feedbackRating;
  final String? feedbackComment;
  final DateTime? feedbackSubmittedAtUtc;
  final bool isReadOnly;
  final bool canReopen;
  final bool hasOlderMessages;
  final DateTime? oldestLoadedMessageCreatedAtUtc;
  final List<SupportChatMessage> messages;

  bool get isFromMobileAssistant => source == 'MobileAssistant';

  SupportChatConversation copyWith({
    String? assignedAdminId,
    String? assignedAdminDisplayName,
    String? status,
    int? userUnreadCount,
    int? adminUnreadCount,
    DateTime? updatedAtUtc,
    DateTime? lastMessageAtUtc,
    DateTime? resolvedAtUtc,
    DateTime? reopenUntilUtc,
    DateTime? closedAtUtc,
    int? feedbackRating,
    String? feedbackComment,
    DateTime? feedbackSubmittedAtUtc,
    bool? isReadOnly,
    bool? canReopen,
    bool? hasOlderMessages,
    DateTime? oldestLoadedMessageCreatedAtUtc,
    List<SupportChatMessage>? messages,
    bool clearAssignedAdmin = false,
    bool clearLastMessageAt = false,
    bool clearResolvedAt = false,
    bool clearReopenUntil = false,
    bool clearClosedAt = false,
    bool clearFeedback = false,
  }) {
    return SupportChatConversation(
      conversationId: conversationId,
      initiatorUserId: initiatorUserId,
      userEmail: userEmail,
      userDisplayName: userDisplayName,
      assignedAdminId: clearAssignedAdmin
          ? null
          : (assignedAdminId ?? this.assignedAdminId),
      assignedAdminDisplayName: clearAssignedAdmin
          ? null
          : (assignedAdminDisplayName ?? this.assignedAdminDisplayName),
      status: status ?? this.status,
      priority: priority,
      source: source,
      assistantScenario: assistantScenario,
      relatedGenerationId: relatedGenerationId,
      relatedPaymentId: relatedPaymentId,
      relatedSubscriptionId: relatedSubscriptionId,
      userUnreadCount: userUnreadCount ?? this.userUnreadCount,
      adminUnreadCount: adminUnreadCount ?? this.adminUnreadCount,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      lastMessageAtUtc: clearLastMessageAt
          ? null
          : (lastMessageAtUtc ?? this.lastMessageAtUtc),
      resolvedAtUtc: clearResolvedAt
          ? null
          : (resolvedAtUtc ?? this.resolvedAtUtc),
      reopenUntilUtc: clearReopenUntil
          ? null
          : (reopenUntilUtc ?? this.reopenUntilUtc),
      closedAtUtc: clearClosedAt ? null : (closedAtUtc ?? this.closedAtUtc),
      feedbackRating: clearFeedback
          ? null
          : (feedbackRating ?? this.feedbackRating),
      feedbackComment: clearFeedback
          ? null
          : (feedbackComment ?? this.feedbackComment),
      feedbackSubmittedAtUtc: clearFeedback
          ? null
          : (feedbackSubmittedAtUtc ?? this.feedbackSubmittedAtUtc),
      isReadOnly: isReadOnly ?? this.isReadOnly,
      canReopen: canReopen ?? this.canReopen,
      hasOlderMessages: hasOlderMessages ?? this.hasOlderMessages,
      oldestLoadedMessageCreatedAtUtc:
          oldestLoadedMessageCreatedAtUtc ??
          this.oldestLoadedMessageCreatedAtUtc,
      messages: messages ?? this.messages,
    );
  }

  factory SupportChatConversation.fromJson(Map<String, dynamic> json) {
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
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAtUtc:
          DateTime.tryParse(json['updatedAtUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastMessageAtUtc: DateTime.tryParse(
        json['lastMessageAtUtc'] as String? ?? '',
      ),
      resolvedAtUtc: DateTime.tryParse(json['resolvedAtUtc'] as String? ?? ''),
      reopenUntilUtc: DateTime.tryParse(
        json['reopenUntilUtc'] as String? ?? '',
      ),
      closedAtUtc: DateTime.tryParse(json['closedAtUtc'] as String? ?? ''),
      feedbackRating: json['feedbackRating'] as int?,
      feedbackComment: json['feedbackComment'] as String?,
      feedbackSubmittedAtUtc: DateTime.tryParse(
        json['feedbackSubmittedAtUtc'] as String? ?? '',
      ),
      isReadOnly: json['isReadOnly'] as bool? ?? false,
      canReopen: json['canReopen'] as bool? ?? false,
      hasOlderMessages: json['hasOlderMessages'] as bool? ?? false,
      oldestLoadedMessageCreatedAtUtc: DateTime.tryParse(
        json['oldestLoadedMessageCreatedAtUtc'] as String? ?? '',
      ),
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SupportChatMessage.fromJson)
          .toList(growable: false),
    );
  }
}
