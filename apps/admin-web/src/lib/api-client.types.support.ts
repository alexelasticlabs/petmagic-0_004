export type SupportConversationStatus = "New" | "InProgress" | "WaitingForUser" | "Closed";

export type SupportConversationSource =
  "MobileChat" | "MobileAssistant" | "AdminCreated" | "System" | "Direct";

export type SupportConversationPriority = "Low" | "Normal" | "High";

export type SupportInboxAssignmentScope = "all" | "mine" | "unassigned";

export type AdminSupportMessageAttachment = {
  fileUrl: string;

  type: string;

  mimeType: string;

  fileName: string;

  sizeBytes: number;

  isDeleted?: boolean;

  expiresAtUtc?: string | null;

  deletedAtUtc?: string | null;

  durationSeconds?: number | null;

  width?: number | null;

  height?: number | null;
};

export type AdminSupportMessage = {
  messageId: string;

  conversationId: string;

  senderUserId: string;

  senderDisplayName: string;

  isFromAdmin: boolean;

  senderType: string;

  body: string;

  replyToMessageId?: string | null;

  replyToPreview?: string | null;

  attachmentUrl?: string | null;

  attachmentFileName?: string | null;

  attachmentContentType?: string | null;

  attachmentFileSizeBytes?: number | null;

  attachmentUploadStatus?: string | null;

  attachmentUploadErrorCode?: string | null;

  attachments?: AdminSupportMessageAttachment[] | null;

  isRead: boolean;

  readAtUtc?: string | null;

  deliveredAtUtc?: string | null;

  isInternalNote: boolean;

  createdAtUtc: string;
};

export type AdminSupportConversationSummary = {
  conversationId: string;

  initiatorUserId: string;

  userEmail: string;

  userDisplayName?: string;

  assignedAdminId?: string | null;

  assignedAdminDisplayName?: string | null;

  status: SupportConversationStatus;

  priority: SupportConversationPriority;

  tags?: string[];

  source: SupportConversationSource;

  assistantScenario?: string | null;

  lastMessagePreview?: string | null;

  lastMessageAtUtc?: string | null;

  lastMessageSenderType?: string | null;

  waitingSinceUtc?: string | null;

  waitingMinutes: number;

  unreadForAdmin: boolean;

  userUnreadCount: number;

  adminUnreadCount: number;

  createdAtUtc: string;

  updatedAtUtc: string;

  resolvedAtUtc?: string | null;

  reopenUntilUtc?: string | null;

  closedAtUtc?: string | null;

  closedByUserId?: string | null;

  reopenedAtUtc?: string | null;

  reopenedByUserId?: string | null;

  feedbackRating?: number | null;

  isReadOnly: boolean;

  canReopen: boolean;
};

export type AdminSupportInboxPage = {
  items: AdminSupportConversationSummary[];

  page: number;

  pageSize: number;

  totalCount: number;

  hasMore: boolean;
};

export type AdminSupportInboxMetrics = {
  totalConversations: number;

  openConversations: number;

  closedConversations: number;

  unassignedConversations: number;

  unreadForAdminConversations: number;
};

export type AdminSupportConversation = {
  conversationId: string;

  initiatorUserId: string;

  userEmail: string;

  userDisplayName?: string;

  assignedAdminId?: string | null;

  assignedAdminDisplayName?: string | null;

  status: SupportConversationStatus;

  priority: SupportConversationPriority;

  tags?: string[];

  source: SupportConversationSource;

  assistantScenario?: string | null;

  relatedGenerationId?: string | null;

  relatedPaymentId?: string | null;

  relatedSubscriptionId?: string | null;

  userUnreadCount: number;

  adminUnreadCount: number;

  createdAtUtc: string;

  updatedAtUtc: string;

  lastMessageAtUtc?: string | null;

  lastMessagePreview?: string | null;

  lastMessageSenderType?: string | null;

  waitingSinceUtc?: string | null;

  waitingMinutes: number;

  resolvedAtUtc?: string | null;

  reopenUntilUtc?: string | null;

  closedAtUtc?: string | null;

  closedByUserId?: string | null;

  reopenedAtUtc?: string | null;

  reopenedByUserId?: string | null;

  feedbackRating?: number | null;

  feedbackComment?: string | null;

  feedbackSubmittedAtUtc?: string | null;

  isReadOnly: boolean;

  canReopen: boolean;

  availableActions: string[];

  hasOlderMessages?: boolean;

  oldestLoadedMessageCreatedAtUtc?: string | null;

  messages: AdminSupportMessage[];
};

export type AdminSupportReplyTemplate = {
  templateId: string;

  title: string;

  body: string;

  isEnabled: boolean;

  sortOrder: number;

  createdAtUtc: string;

  updatedAtUtc: string;
};
