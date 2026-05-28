import type {
  AdminSupportConversation,
  AdminSupportConversationSummary,
  AdminUserAnalytics,
} from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

type RelativeTimeFormat = "compact" | "verbose";

export type SupportTimelineItem = {
  id: string;
  title: string;
  subtitle: string;
  occurredAtUtc: string;
  tone: "neutral" | "primary" | "info" | "success" | "warning" | "danger";
};

export function formatDateTime(value: string | null | undefined, locale: Locale) {
  if (!value) {
    return "—";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export function formatClockTime(value: string, locale: Locale) {
  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(value));
}

export function formatRelativeTime(
  value: string | null | undefined,
  locale: Locale,
  format: RelativeTimeFormat = "compact"
) {
  if (!value) {
    return "—";
  }

  const timestamp = new Date(value).getTime();
  const diffMinutes = Math.max(0, Math.round((Date.now() - timestamp) / 60000));
  if (diffMinutes < 1) {
    return locale === "ru" ? "только что" : "just now";
  }

  if (diffMinutes < 60) {
    if (locale === "ru") {
      return `${diffMinutes} мин назад`;
    }

    return format === "verbose" ? `${diffMinutes} min ago` : `${diffMinutes}m ago`;
  }

  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) {
    return locale === "ru" ? `${diffHours} ч назад` : `${diffHours}h ago`;
  }

  const diffDays = Math.round(diffHours / 24);
  return locale === "ru" ? `${diffDays} дн назад` : `${diffDays}d ago`;
}

export function getConversationSla(
  value: string | null | undefined,
  locale: Locale,
  unreadCount = 0
) {
  const diffMinutes = Math.max(
    0,
    Math.round((Date.now() - new Date(value ?? Date.now()).getTime()) / 60000)
  );

  let level: "good" | "warning" | "risk" | "critical" = "critical";
  if (diffMinutes < 30) {
    level = "good";
  } else if (diffMinutes < 180) {
    level = "warning";
  } else if (diffMinutes < 720) {
    level = "risk";
  }

  const waitLabel = `${getWaitPrefix(locale)} ${formatWaitTime(value, locale)}`;

  return {
    level,
    waitLabel,
    primaryLabel:
      unreadCount > 0
        ? locale === "ru"
          ? "Новый ответ пользователя"
          : "New user reply"
        : waitLabel,
  };
}

export function formatWaitTime(value: string | null | undefined, locale: Locale) {
  if (!value) {
    return "—";
  }

  const diffMinutes = Math.max(0, Math.round((Date.now() - new Date(value).getTime()) / 60000));
  if (diffMinutes < 60) {
    return locale === "ru" ? `${diffMinutes} мин` : `${diffMinutes} min`;
  }

  const diffHours = Math.floor(diffMinutes / 60);
  const restMinutes = diffMinutes % 60;
  if (restMinutes === 0) {
    return locale === "ru" ? `${diffHours} ч` : `${diffHours} h`;
  }

  return locale === "ru"
    ? `${diffHours} ч ${restMinutes} мин`
    : `${diffHours} h ${restMinutes} min`;
}

export function getWaitPrefix(locale: Locale) {
  return locale === "ru" ? "Ожидает" : "Waiting";
}

export function formatAccountAge(value: string | null | undefined, locale: Locale) {
  if (!value) {
    return locale === "ru" ? "новый" : "new";
  }

  const diffDays = Math.max(1, Math.floor((Date.now() - new Date(value).getTime()) / 86400000));
  if (diffDays < 30) {
    return locale === "ru" ? `${diffDays} дн` : `${diffDays}d`;
  }

  if (diffDays < 365) {
    const diffMonths = Math.max(1, Math.floor(diffDays / 30));
    return locale === "ru" ? `${diffMonths} мес` : `${diffMonths} mo`;
  }

  const diffYears = Math.max(1, Math.floor(diffDays / 365));
  return locale === "ru" ? `${diffYears} г` : `${diffYears} yr`;
}

export function formatAccountAgeFact(value: string | null | undefined, locale: Locale) {
  return locale === "ru"
    ? `Аккаунт ${formatAccountAge(value, locale)}`
    : `Account ${formatAccountAge(value, locale)}`;
}

export function formatCountFact(value: number, locale: Locale, kind: "messages" | "purchases") {
  if (locale === "ru") {
    if (kind === "messages") {
      return `${value} ${pluralizeRu(value, "сообщение", "сообщения", "сообщений")}`;
    }

    return `${value} ${pluralizeRu(value, "покупка", "покупки", "покупок")}`;
  }

  if (kind === "messages") {
    return `${value} ${value === 1 ? "message" : "messages"}`;
  }

  return `${value} ${value === 1 ? "purchase" : "purchases"}`;
}

export function pluralizeRu(value: number, one: string, few: string, many: string) {
  const abs = Math.abs(value) % 100;
  const last = abs % 10;

  if (abs > 10 && abs < 20) {
    return many;
  }

  if (last === 1) {
    return one;
  }

  if (last >= 2 && last <= 4) {
    return few;
  }

  return many;
}

export function formatMoney(amount: number, currencyCode: string, locale: Locale) {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    style: "currency",
    currency: currencyCode,
    maximumFractionDigits: 2,
  }).format(amount);
}

export function hasAttachment(
  message: Pick<
    AdminSupportConversation["messages"][number],
    "attachments" | "attachmentUrl" | "attachmentContentType" | "attachmentFileName" | "attachmentFileSizeBytes"
  >
) {
  return getMessageAttachments(message).length > 0;
}

export function hasImageAttachment(
  message: Pick<
    AdminSupportConversation["messages"][number],
    "attachments" | "attachmentUrl" | "attachmentContentType" | "attachmentFileName" | "attachmentFileSizeBytes"
  >
) {
  const attachments = getMessageAttachments(message);
  return attachments.length === 1 && attachments[0]?.mimeType?.startsWith("image/");
}

export function hasVideoAttachment(
  message: Pick<
    AdminSupportConversation["messages"][number],
    "attachments" | "attachmentUrl" | "attachmentContentType" | "attachmentFileName" | "attachmentFileSizeBytes"
  >
) {
  const attachments = getMessageAttachments(message);
  return attachments.length === 1 && attachments[0]?.mimeType?.startsWith("video/");
}

export function getMessageAttachments(
  message: Pick<
    AdminSupportConversation["messages"][number],
    "attachments" | "attachmentUrl" | "attachmentContentType" | "attachmentFileName" | "attachmentFileSizeBytes"
  >
) {
  const parsedAttachments =
    message.attachments
      ?.filter((attachment) => attachment.isDeleted || Boolean(attachment.fileUrl?.trim()))
      .map((attachment) => ({
        fileUrl: attachment.fileUrl,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        sizeBytes: attachment.sizeBytes,
        durationSeconds: attachment.durationSeconds ?? null,
        isDeleted: attachment.isDeleted ?? false,
        expiresAtUtc: attachment.expiresAtUtc ?? null,
        deletedAtUtc: attachment.deletedAtUtc ?? null,
      })) ?? [];
  if (parsedAttachments.length > 0) {
    return parsedAttachments;
  }

  if (!message.attachmentUrl?.trim() || !message.attachmentContentType?.trim()) {
    return [];
  }

  return [
      {
        fileUrl: message.attachmentUrl,
        fileName: message.attachmentFileName ?? "attachment",
        mimeType: message.attachmentContentType,
        sizeBytes: message.attachmentFileSizeBytes ?? 0,
        durationSeconds: null,
        isDeleted: false,
        expiresAtUtc: null,
        deletedAtUtc: null,
      },
    ];
}

export function shouldRenderMessageBody(
  message: Pick<
    AdminSupportConversation["messages"][number],
    "body" | "attachments" | "attachmentFileName" | "attachmentUrl" | "attachmentContentType" | "attachmentFileSizeBytes"
  >
) {
  const normalizedBody = message.body.trim();
  if (!normalizedBody) {
    return false;
  }

  const attachments = getMessageAttachments(message);
  if (attachments.length === 0) {
    return true;
  }

  const normalizedBodyLower = normalizedBody.toLowerCase();
  const attachmentNames = new Set(
    attachments
      .map((attachment) => attachment.fileName?.trim().toLowerCase())
      .filter((value): value is string => Boolean(value))
  );
  const bodyParts = normalizedBodyLower
    .split(/[\n,]/)
    .map((part) => part.trim())
    .filter(Boolean);
  const isAttachmentNameList = bodyParts.length > 1 && bodyParts.every((part) => attachmentNames.has(part));
  const isMimeTypeOnly = /^[a-z0-9.+-]+\/[a-z0-9.+-]+(?:\s*;.*)?$/i.test(normalizedBody);
  const isTechnicalPrefix = /^(file name|filename|mime|content[- ]type|upload status|upload state|debug)\s*[:=-]/i.test(
    normalizedBodyLower.replace(/\s+/g, " ")
  );
  const isUploadStatusOnly =
    /^(uploaded|uploading|upload failed|retry|attachment uploaded|file uploaded)$/i.test(
      normalizedBodyLower
    );
  const isAttachmentUrl =
    /^https?:\/\/\S+$/i.test(normalizedBody) &&
    attachments.some((attachment) => attachment.fileUrl.trim() === normalizedBody);

  if (
    attachmentNames.has(normalizedBodyLower) ||
    isAttachmentNameList ||
    isMimeTypeOnly ||
    isTechnicalPrefix ||
    isUploadStatusOnly ||
    isAttachmentUrl
  ) {
    return false;
  }

  return true;
}

export function formatFileSize(value: number | null | undefined, locale: Locale) {
  if (!value || value <= 0) {
    return locale === "ru" ? "Размер не указан" : "Size unavailable";
  }

  if (value < 1024) {
    return `${value} B`;
  }

  const kilobytes = value / 1024;
  if (kilobytes < 1024) {
    return locale === "ru" ? `${kilobytes.toFixed(1)} КБ` : `${kilobytes.toFixed(1)} KB`;
  }

  const megabytes = kilobytes / 1024;
  return locale === "ru" ? `${megabytes.toFixed(1)} МБ` : `${megabytes.toFixed(1)} MB`;
}

export function initialsFor(value: string) {
  return (
    value
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? "")
      .join("") || "PM"
  );
}

export function shortId(value: string) {
  return value.length > 8 ? `#${value.slice(0, 8)}` : value;
}

type SupportQueueItem = Pick<
  AdminSupportConversationSummary,
  "adminUnreadCount" | "createdAtUtc" | "lastMessageAtUtc" | "priority" | "status" | "updatedAtUtc"
>;

export function sortSupportQueueItems<T extends SupportQueueItem>(items: readonly T[]) {
  return items.slice().sort((left, right) => {
    const urgencyDelta = getSupportQueueUrgency(right) - getSupportQueueUrgency(left);
    if (urgencyDelta !== 0) {
      return urgencyDelta;
    }

    return Date.parse(right.updatedAtUtc) - Date.parse(left.updatedAtUtc);
  });
}

function getSupportQueueUrgency(item: SupportQueueItem) {
  const statusWeight: Record<string, number> = {
    New: 700,
    InProgress: 420,
    WaitingForUser: 260,
    Closed: 0,
    Open: 700,
    WaitingForSupport: 700,
    Resolved: 0,
  };
  const priorityWeight: Record<string, number> = {
    High: 120,
    Normal: 60,
    Low: 0,
  };
  const waitingSince = Date.parse(item.lastMessageAtUtc ?? item.createdAtUtc);
  const waitingMinutes = Number.isNaN(waitingSince)
    ? 0
    : Math.max(0, Math.round((Date.now() - waitingSince) / 60000));

  return (
    (statusWeight[item.status] ?? 0) +
    (priorityWeight[item.priority] ?? 0) +
    item.adminUnreadCount * 800 +
    Math.min(waitingMinutes, 1440) / 4
  );
}

export type SupportConversationFeedItem =
  | {
      kind: "message";
      id: string;
      occurredAtUtc: string;
      message: AdminSupportConversation["messages"][number];
    }
  | {
      kind: "system";
      id: string;
      occurredAtUtc: string;
      label: string;
      tone: "neutral" | "info" | "warning" | "success";
    };

export type SupportConversationFeedGroup = {
  key: "today" | "yesterday" | "earlier";
  label: string;
  items: SupportConversationFeedItem[];
};

export function groupSupportConversationFeed(
  conversation: Pick<
    AdminSupportConversation,
    "messages" | "createdAtUtc" | "resolvedAtUtc" | "closedAtUtc" | "reopenUntilUtc" | "status"
  >,
  labels: {
    today: string;
    yesterday: string;
    earlier: string;
    ticketCreated: string;
    ticketResolved: string;
    ticketReopened: string;
    ticketClosed: string;
  }
): SupportConversationFeedGroup[] {
  const items: SupportConversationFeedItem[] = [];

  if (conversation.createdAtUtc) {
    items.push({
      kind: "system",
      id: `system:created:${conversation.createdAtUtc}`,
      occurredAtUtc: conversation.createdAtUtc,
      label: labels.ticketCreated,
      tone: "info",
    });
  }

  for (const message of conversation.messages) {
    items.push({
      kind: "message",
      id: message.messageId,
      occurredAtUtc: message.createdAtUtc,
      message,
    });
  }

  if (conversation.resolvedAtUtc && conversation.status !== "Closed") {
    items.push({
      kind: "system",
      id: `system:resolved:${conversation.resolvedAtUtc}`,
      occurredAtUtc: conversation.resolvedAtUtc,
      label: labels.ticketResolved,
      tone: "success",
    });
  }

  if (conversation.closedAtUtc) {
    items.push({
      kind: "system",
      id: `system:closed:${conversation.closedAtUtc}`,
      occurredAtUtc: conversation.closedAtUtc,
      label: labels.ticketClosed,
      tone: "neutral",
    });
  }

  items.sort((left, right) => Date.parse(left.occurredAtUtc) - Date.parse(right.occurredAtUtc));

  const groups: SupportConversationFeedGroup[] = [
    { key: "earlier", label: labels.earlier, items: [] },
    { key: "yesterday", label: labels.yesterday, items: [] },
    { key: "today", label: labels.today, items: [] },
  ];

  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const startOfYesterday = new Date(startOfToday);
  startOfYesterday.setDate(startOfYesterday.getDate() - 1);

  for (const item of items) {
    const timestamp = Date.parse(item.occurredAtUtc);
    if (Number.isNaN(timestamp)) {
      groups[0].items.push(item);
      continue;
    }
    if (timestamp >= startOfToday.getTime()) {
      groups[2].items.push(item);
    } else if (timestamp >= startOfYesterday.getTime()) {
      groups[1].items.push(item);
    } else {
      groups[0].items.push(item);
    }
  }

  return groups.filter((group) => group.items.length > 0);
}

export function buildActivityTimeline(
  analytics: AdminUserAnalytics | null | undefined
): SupportTimelineItem[] {
  return [
    ...(analytics?.recentActivity ?? []).slice(0, 4).map((item) => ({
      id: `activity:${item.kind}:${item.occurredAtUtc}:${item.title}`,
      title: item.title,
      subtitle: item.details || item.kind,
      occurredAtUtc: item.occurredAtUtc,
      tone: "info" as const,
    })),
    ...(analytics?.recentAuditEvents ?? []).slice(0, 4).map((item) => ({
      id: `audit:${item.auditEventId}`,
      title: item.action,
      subtitle: item.details,
      occurredAtUtc: item.occurredAtUtc,
      tone: "warning" as const,
    })),
  ].sort(
    (left, right) =>
      new Date(right.occurredAtUtc).getTime() - new Date(left.occurredAtUtc).getTime()
  );
}

export function buildConversationTimeline({
  conversation,
  userDisplayName,
  labels,
}: {
  conversation: AdminSupportConversation | null | undefined;
  userDisplayName: string;
  labels: {
    conversationCreated: string;
    adminReply: string;
    userMessage: string;
  };
}): SupportTimelineItem[] {
  if (!conversation) {
    return [];
  }

  return [
    {
      id: `conversation:${conversation.conversationId}`,
      title: labels.conversationCreated,
      subtitle: userDisplayName,
      occurredAtUtc: conversation.createdAtUtc,
      tone: "info" as const,
    },
    ...conversation.messages.map((message) => ({
      id: message.messageId,
      title: message.isFromAdmin ? labels.adminReply : labels.userMessage,
      subtitle: `${message.senderDisplayName} • ${truncateText(message.body, 112)}`,
      occurredAtUtc: message.createdAtUtc,
      tone: message.isFromAdmin ? ("success" as const) : ("primary" as const),
    })),
  ].sort(
    (left, right) =>
      new Date(right.occurredAtUtc).getTime() - new Date(left.occurredAtUtc).getTime()
  );
}

export function mergeTemplateDraft(currentValue: string, template: string) {
  const normalizedCurrentValue = currentValue.trim();
  if (!normalizedCurrentValue) {
    return template;
  }

  return `${normalizedCurrentValue}\n\n${template}`;
}

export function truncateText(value: string, maxLength: number) {
  if (value.length <= maxLength) {
    return value;
  }

  return `${value.slice(0, maxLength - 1).trimEnd()}…`;
}
