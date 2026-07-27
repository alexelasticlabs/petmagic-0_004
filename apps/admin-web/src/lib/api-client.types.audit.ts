import type { OffsetPagedResponse } from "./api-client.types.shared";

export type AdminAuditCategory =
  "identity" | "economy" | "content" | "support" | "gamification" | "system";

export type AdminAuditIdentity = {
  userId?: string | null;
  displayName?: string | null;
  email?: string | null;
};

export type AdminAuditEventListItem = {
  auditEventId: string;
  action: string;
  category: AdminAuditCategory;
  actorUserId?: string | null;
  actorDisplayName?: string | null;
  actorEmail?: string | null;
  actorRole?: string | null;
  subjectUserId?: string | null;
  subjectDisplayName?: string | null;
  subjectEmail?: string | null;
  targetType?: string | null;
  targetId?: string | null;
  correlationId?: string | null;
  occurredAtUtc: string;
};

export type AdminAuditEventsSummary = {
  totalEvents: number;
  uniqueActors: number;
  accessEvents: number;
  systemEvents: number;
};

export type AdminAuditEventsPage = OffsetPagedResponse<AdminAuditEventListItem> & {
  totalCount: number;
  summary: AdminAuditEventsSummary;
};

export type AdminAuditEventDetail = AdminAuditEventListItem & {
  oldValue?: string | null;
  newValue?: string | null;
  details: string;
  ipAddress?: string | null;
  userAgent?: string | null;
  createdAtUtc: string;
};
