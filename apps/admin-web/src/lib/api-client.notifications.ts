import { apiRequest, encodePathSegment } from "./api-client.core";

import type {
  AdminNotificationEvent,
  AdminNotificationPriority,
  AdminNotificationsPage,
  AdminNotificationState,
} from "./api-client.types.notifications";

export type FetchAdminNotificationsQuery = {
  cursor?: string;
  take?: number;
  state?: AdminNotificationState;
  category?: string;
  priority?: AdminNotificationPriority;
};

export function buildAdminNotificationsPath(query: FetchAdminNotificationsQuery = {}) {
  const params = new URLSearchParams();
  params.set("take", String(Math.min(100, Math.max(1, Math.floor(query.take ?? 20)))));
  if (query.cursor?.trim()) params.set("cursor", query.cursor.trim().slice(0, 500));
  if (query.state) params.set("state", query.state);
  if (query.category?.trim()) params.set("category", query.category.trim().slice(0, 32));
  if (query.priority) params.set("priority", query.priority);
  return `/api/admin/notifications?${params.toString()}`;
}

export function fetchAdminNotifications(
  query: FetchAdminNotificationsQuery = {},
  signal?: AbortSignal
): Promise<AdminNotificationsPage> {
  return apiRequest<AdminNotificationsPage>(buildAdminNotificationsPath(query), {
    method: "GET",
    signal,
  });
}

export function markAdminNotificationRead(notificationId: string) {
  return apiRequest<AdminNotificationEvent>(
    `/api/admin/notifications/${encodePathSegment(notificationId)}/read`,
    { method: "POST", body: JSON.stringify({}) }
  );
}

export function markAllAdminNotificationsRead(cutoffUtc: string) {
  return apiRequest<{ updatedCount: number }>("/api/admin/notifications/read-all", {
    method: "POST",
    body: JSON.stringify({ cutoffUtc }),
  });
}

export function archiveAdminNotification(notificationId: string) {
  return apiRequest<AdminNotificationEvent>(
    `/api/admin/notifications/${encodePathSegment(notificationId)}/archive`,
    { method: "POST", body: JSON.stringify({}) }
  );
}

export function acknowledgeAdminNotification(
  notificationId: string,
  version: number,
  reason: string
) {
  return apiRequest<AdminNotificationEvent>(
    `/api/admin/notifications/${encodePathSegment(notificationId)}/acknowledge`,
    {
      method: "POST",
      headers: { "If-Match": `\"${version}\"` },
      body: JSON.stringify({ reason }),
    }
  );
}
