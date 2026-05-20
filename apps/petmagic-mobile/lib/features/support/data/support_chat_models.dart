class SupportChatMessage {
  const SupportChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.isFromAdmin,
    required this.body,
    required this.isRead,
    required this.createdAtUtc,
    this.attachmentUrl,
    this.attachmentFileName,
    this.attachmentContentType,
    this.attachmentFileSizeBytes,
    this.readAtUtc,
  });

  final String messageId;
  final String conversationId;
  final String senderUserId;
  final String senderDisplayName;
  final bool isFromAdmin;
  final String body;
  final bool isRead;
  final DateTime createdAtUtc;
  final String? attachmentUrl;
  final String? attachmentFileName;
  final String? attachmentContentType;
  final int? attachmentFileSizeBytes;
  final DateTime? readAtUtc;

  bool get hasImageAttachment =>
      attachmentUrl?.isNotEmpty == true &&
      (attachmentContentType?.startsWith('image/') ?? false);

  SupportChatMessage copyWith({
    bool? isRead,
    DateTime? readAtUtc,
    bool clearReadAt = false,
  }) {
    return SupportChatMessage(
      messageId: messageId,
      conversationId: conversationId,
      senderUserId: senderUserId,
      senderDisplayName: senderDisplayName,
      isFromAdmin: isFromAdmin,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAtUtc: createdAtUtc,
      attachmentUrl: attachmentUrl,
      attachmentFileName: attachmentFileName,
      attachmentContentType: attachmentContentType,
      attachmentFileSizeBytes: attachmentFileSizeBytes,
      readAtUtc: clearReadAt ? null : (readAtUtc ?? this.readAtUtc),
    );
  }

  factory SupportChatMessage.fromJson(Map<String, dynamic> json) {
    return SupportChatMessage(
      messageId: json['messageId'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderUserId: json['senderUserId'] as String? ?? '',
      senderDisplayName: json['senderDisplayName'] as String? ?? '',
      isFromAdmin: json['isFromAdmin'] as bool? ?? false,
      body: json['body'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentFileName: json['attachmentFileName'] as String?,
      attachmentContentType: json['attachmentContentType'] as String?,
      attachmentFileSizeBytes: json['attachmentFileSizeBytes'] as int?,
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAtUtc: DateTime.tryParse(json['readAtUtc'] as String? ?? ''),
    );
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
    required this.userUnreadCount,
    required this.adminUnreadCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.lastMessageAtUtc,
    required this.messages,
  });

  final String conversationId;
  final String initiatorUserId;
  final String userEmail;
  final String? userDisplayName;
  final String? assignedAdminId;
  final String? assignedAdminDisplayName;
  final String status;
  final String priority;
  final int userUnreadCount;
  final int adminUnreadCount;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? lastMessageAtUtc;
  final List<SupportChatMessage> messages;

  SupportChatConversation copyWith({
    String? assignedAdminId,
    String? assignedAdminDisplayName,
    String? status,
    int? userUnreadCount,
    int? adminUnreadCount,
    DateTime? updatedAtUtc,
    DateTime? lastMessageAtUtc,
    List<SupportChatMessage>? messages,
    bool clearAssignedAdmin = false,
    bool clearLastMessageAt = false,
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
      userUnreadCount: userUnreadCount ?? this.userUnreadCount,
      adminUnreadCount: adminUnreadCount ?? this.adminUnreadCount,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      lastMessageAtUtc: clearLastMessageAt
          ? null
          : (lastMessageAtUtc ?? this.lastMessageAtUtc),
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
      status: json['status'] as String? ?? 'Open',
      priority: json['priority'] as String? ?? 'Normal',
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
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SupportChatMessage.fromJson)
          .toList(growable: false),
    );
  }
}
