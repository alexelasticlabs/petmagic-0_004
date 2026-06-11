type LegacySupportConversation = {
  unreadForAdmin?: boolean;
};

type LegacySupportInboxPage = {
  items?: LegacySupportConversation[];
};

type SupportInboxMetricsLike = {
  unreadForAdminConversations?: number;
};

function countLegacyUnread(items: LegacySupportConversation[]): number {
  return items.filter((conversation) => conversation.unreadForAdmin).length;
}

export function getSupportUnreadCount(data: unknown): number {
  if (!data || typeof data !== "object") {
    return 0;
  }

  const metrics = data as SupportInboxMetricsLike;
  if (typeof metrics.unreadForAdminConversations === "number") {
    return metrics.unreadForAdminConversations;
  }

  if (Array.isArray(data)) {
    return countLegacyUnread(data as LegacySupportConversation[]);
  }

  const page = data as LegacySupportInboxPage;
  if (Array.isArray(page.items)) {
    return countLegacyUnread(page.items);
  }

  return 0;
}
