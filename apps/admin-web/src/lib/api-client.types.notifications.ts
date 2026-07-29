export type AdminNotificationPriority = "normal" | "warning" | "critical";
export type AdminNotificationState = "active" | "unread" | "read" | "archived" | "all";

export type AdminNotificationAcknowledgement = {
  actorUserId: string;
  acknowledgedAtUtc: string;
  reason: string;
};

export type AdminNotificationEvent = {
  notificationId: string;
  type: string;
  schemaVersion: number;
  payload: Record<string, unknown>;
  category: string;
  priority: AdminNotificationPriority;
  href?: string | null;
  source: string;
  createdAtUtc: string;
  expiresAtUtc?: string | null;
  readAtUtc?: string | null;
  archivedAtUtc?: string | null;
  acknowledgement?: AdminNotificationAcknowledgement | null;
  version: number;
};

export type AdminNotificationsPage = {
  items: AdminNotificationEvent[];
  nextCursor?: string | null;
  unreadCount: number;
  criticalUnacknowledgedCount: number;
  asOfUtc: string;
};
