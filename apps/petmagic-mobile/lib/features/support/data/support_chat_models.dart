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
    this.attachmentUrl,
    this.attachmentFileName,
    this.attachmentContentType,
    this.attachmentFileSizeBytes,
    this.attachmentUploadStatus,
    this.attachmentUploadErrorCode,
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
  final String? attachmentUrl;
  final String? attachmentFileName;
  final String? attachmentContentType;
  final int? attachmentFileSizeBytes;
  final String? attachmentUploadStatus;
  final String? attachmentUploadErrorCode;
  final DateTime? readAtUtc;
  final DateTime? deliveredAtUtc;

  bool get isSystemMessage => senderType == 'System';
  bool get isBotMessage => senderType == 'Bot';
  bool get isUserMessage => senderType == 'User';

  SupportChatAttachment? get primaryAttachment =>
      attachments.isEmpty ? null : attachments.first;

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
    String? attachmentUrl,
    String? attachmentFileName,
    String? attachmentContentType,
    int? attachmentFileSizeBytes,
    String? attachmentUploadStatus,
    String? attachmentUploadErrorCode,
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
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentFileName: attachmentFileName ?? this.attachmentFileName,
      attachmentContentType:
          attachmentContentType ?? this.attachmentContentType,
      attachmentFileSizeBytes:
          attachmentFileSizeBytes ?? this.attachmentFileSizeBytes,
      attachmentUploadStatus:
          attachmentUploadStatus ?? this.attachmentUploadStatus,
      attachmentUploadErrorCode: clearAttachmentUploadErrorCode
          ? null
          : (attachmentUploadErrorCode ?? this.attachmentUploadErrorCode),
      readAtUtc: clearReadAt ? null : (readAtUtc ?? this.readAtUtc),
      deliveredAtUtc: deliveredAtUtc ?? this.deliveredAtUtc,
    );
  }

  factory SupportChatMessage.fromJson(Map<String, dynamic> json) {
    final parsedAttachments = _parseAttachments(
      json,
      legacyAttachmentUrl: json['attachmentUrl'] as String?,
      legacyAttachmentFileName: json['attachmentFileName'] as String?,
      legacyAttachmentContentType: json['attachmentContentType'] as String?,
      legacyAttachmentFileSizeBytes:
          (json['attachmentFileSizeBytes'] as num?)?.toInt(),
    );

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
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentFileName: json['attachmentFileName'] as String?,
      attachmentContentType: json['attachmentContentType'] as String?,
      attachmentFileSizeBytes: (json['attachmentFileSizeBytes'] as num?)?.toInt(),
      attachmentUploadStatus: json['attachmentUploadStatus'] as String?,
      attachmentUploadErrorCode: json['attachmentUploadErrorCode'] as String?,
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAtUtc: DateTime.tryParse(json['readAtUtc'] as String? ?? ''),
      deliveredAtUtc: DateTime.tryParse(json['deliveredAtUtc'] as String? ?? ''),
    );
  }

  static List<SupportChatAttachment> _parseAttachments(
    Map<String, dynamic> json, {
    required String? legacyAttachmentUrl,
    required String? legacyAttachmentFileName,
    required String? legacyAttachmentContentType,
    required int? legacyAttachmentFileSizeBytes,
  }) {
    final parsedAttachments = (json['attachments'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SupportChatAttachment.fromJson)
        .where((attachment) => attachment.fileUrl.trim().isNotEmpty)
        .toList(growable: false);

    if (parsedAttachments.isNotEmpty) {
      return parsedAttachments;
    }

    final legacyUrl = legacyAttachmentUrl?.trim();
    final legacyMimeType = legacyAttachmentContentType?.trim();
    if (legacyUrl == null ||
        legacyUrl.isEmpty ||
        legacyMimeType == null ||
        legacyMimeType.isEmpty) {
      return const [];
    }

    return [
      SupportChatAttachment(
        fileUrl: legacyUrl,
        type: legacyMimeType.startsWith('image/')
            ? 'image'
            : (legacyMimeType.startsWith('video/') ? 'video' : 'file'),
        mimeType: legacyMimeType,
        fileName: legacyAttachmentFileName?.trim().isNotEmpty == true
            ? legacyAttachmentFileName!.trim()
            : legacyUrl.split('/').last,
        sizeBytes: legacyAttachmentFileSizeBytes ?? 0,
      ),
    ];
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
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SupportChatMessage.fromJson)
          .toList(growable: false),
    );
  }
}
