type SupportInboxMetricsLike = {
  unreadForAdminConversations?: number;
};

export function getSupportUnreadCount(data: unknown): number {
  if (!data || typeof data !== "object") {
    return 0;
  }

  const metrics = data as SupportInboxMetricsLike;
  if (typeof metrics.unreadForAdminConversations === "number") {
    return metrics.unreadForAdminConversations;
  }

  return 0;
}
