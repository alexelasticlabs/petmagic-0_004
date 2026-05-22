import type { AdminSupportConversation, AdminUserAnalytics } from "@/lib/api-client";
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

export function formatRelativeTime(value: string | null | undefined, locale: Locale, format: RelativeTimeFormat = "compact") {
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

export function getConversationSla(value: string | null | undefined, locale: Locale, unreadCount = 0) {
    const diffMinutes = Math.max(0, Math.round((Date.now() - new Date(value ?? Date.now()).getTime()) / 60000));

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
        primaryLabel: unreadCount > 0
            ? (locale === "ru" ? "Новый ответ пользователя" : "New user reply")
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

    return locale === "ru" ? `${diffHours} ч ${restMinutes} мин` : `${diffHours} h ${restMinutes} min`;
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
    return locale === "ru" ? `Аккаунт ${formatAccountAge(value, locale)}` : `Account ${formatAccountAge(value, locale)}`;
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

export function hasAttachment(message: Pick<AdminSupportConversation["messages"][number], "attachmentUrl">) {
    return Boolean(message.attachmentUrl?.trim());
}

export function hasImageAttachment(message: Pick<AdminSupportConversation["messages"][number], "attachmentUrl" | "attachmentContentType">) {
    return hasAttachment(message) && Boolean(message.attachmentContentType?.startsWith("image/"));
}

export function shouldRenderMessageBody(message: Pick<AdminSupportConversation["messages"][number], "body" | "attachmentFileName" | "attachmentUrl">) {
    const normalizedBody = message.body.trim();
    if (!normalizedBody) {
        return false;
    }

    if (!hasAttachment(message)) {
        return true;
    }

    return normalizedBody !== (message.attachmentFileName?.trim() ?? "");
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
    return value
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map((part) => part[0]?.toUpperCase() ?? "")
        .join("") || "PM";
}

export function shortId(value: string) {
    return value.length > 8 ? `#${value.slice(0, 8)}` : value;
}

export function buildActivityTimeline(analytics: AdminUserAnalytics | null | undefined): SupportTimelineItem[] {
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
    ].sort((left, right) => new Date(right.occurredAtUtc).getTime() - new Date(left.occurredAtUtc).getTime());
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
            title: message.isFromAdmin
                ? labels.adminReply
                : labels.userMessage,
            subtitle: `${message.senderDisplayName} • ${truncateText(message.body, 112)}`,
            occurredAtUtc: message.createdAtUtc,
            tone: message.isFromAdmin ? "success" as const : "primary" as const,
        })),
    ].sort((left, right) => new Date(right.occurredAtUtc).getTime() - new Date(left.occurredAtUtc).getTime());
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
