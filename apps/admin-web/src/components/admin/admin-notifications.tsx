"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { usePathname } from "next/navigation";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import { useAdminNotificationsRealtime } from "@/lib/admin-notifications-realtime";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  archiveAdminNotification,
  fetchAdminNotifications,
  markAdminNotificationRead,
  markAllAdminNotificationsRead,
  useAuthSession,
  type AdminNotificationEvent,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type AdminNotificationCategory =
  "support" | "users" | "templates" | "economy" | "promo" | "system";
export type AdminNotificationTone = "info" | "success" | "warning" | "error";
export type AdminNotificationPriority = "normal" | "critical";

export type AdminNotificationItem = {
  id: string;
  title: string;
  message: string;
  category: AdminNotificationCategory;
  tone: AdminNotificationTone;
  priority: AdminNotificationPriority;
  href?: string;
  source: string;
  createdAt: string;
  read: boolean;
  archived: boolean;
  event?: AdminNotificationEvent;
};

type AddAdminNotificationInput = {
  title: string;
  message: string;
  category: AdminNotificationCategory;
  source: string;
  tone?: AdminNotificationTone;
  priority?: AdminNotificationPriority;
  href?: string;
  dedupeKey?: string;
};

type AdminNotificationsContextValue = {
  items: AdminNotificationItem[];
  unreadCount: number;
  criticalUnacknowledgedCount: number;
  asOfUtc?: string;
  isLoading: boolean;
  addNotification: (input: AddAdminNotificationInput) => void;
  markAsRead: (notificationId: string) => void;
  markCategoryAsRead: (category: AdminNotificationCategory) => void;
  markAllAsRead: () => void;
  clearRead: () => void;
  removeNotification: (notificationId: string) => void;
  refresh: () => void;
};

type ToastLike = { type: "success" | "error"; message: string };
type SyncToastOptions = {
  category: AdminNotificationCategory;
  source: string;
  title: string | ((toast: ToastLike) => string);
  href?: string;
};
type FeedbackLike = { tone: "success" | "danger" | "info"; message: string };
type SyncFeedbackOptions = {
  category: AdminNotificationCategory;
  source: string;
  title: string | ((feedback: FeedbackLike) => string);
  href?: string;
};

const ADMIN_NOTIFICATIONS_STORAGE_KEY_PREFIX = "petmagic.admin.notifications.v2";
const LEGACY_ADMIN_NOTIFICATIONS_STORAGE_KEY = "petmagic.admin.notifications.v1";
const MAX_NOTIFICATION_DEDUPE_KEY_LENGTH = 360;
const AdminNotificationsContext = createContext<AdminNotificationsContextValue | null>(null);
let adminNotificationIdSequence = 0;

export function getAdminNotificationStorageKey(userId: string | null | undefined): string | null {
  const normalizedUserId = userId?.trim();
  return normalizedUserId
    ? `${ADMIN_NOTIFICATIONS_STORAGE_KEY_PREFIX}:${encodeURIComponent(normalizedUserId)}`
    : null;
}

export function createAdminNotificationId(now: number = Date.now()): string {
  const crypto = globalThis.crypto;
  if (typeof crypto?.randomUUID === "function") return `${now}-${crypto.randomUUID()}`;
  if (typeof crypto?.getRandomValues === "function") {
    const bytes = new Uint8Array(8);
    crypto.getRandomValues(bytes);
    return `${now}-${Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
  }
  adminNotificationIdSequence = (adminNotificationIdSequence + 1) % Number.MAX_SAFE_INTEGER;
  return `${now}-${adminNotificationIdSequence.toString(36)}`;
}

export function sanitizeAdminNotificationText(value: string, maxLength: number): string {
  return sanitizeSensitiveText(value, maxLength);
}

export function sanitizeAdminNotificationDedupeKey(value: string): string {
  return sanitizeAdminNotificationText(value, MAX_NOTIFICATION_DEDUPE_KEY_LENGTH);
}

export function sanitizeAdminNotificationSource(value: string): string {
  const trimmed = value.trim();
  return trimmed ? sanitizeAdminNotificationText(trimmed, 120) : "";
}

export function buildAdminNotificationDedupeKey(
  source: string,
  type: string,
  message: string,
  href?: string
): string {
  return sanitizeAdminNotificationDedupeKey(
    [
      sanitizeAdminNotificationSource(source),
      sanitizeAdminNotificationText(type, 120),
      sanitizeAdminNotificationText(message, 280),
      sanitizeNotificationHref(href) ?? "",
    ].join(":")
  );
}

export function localizeAdminNotification(
  event: AdminNotificationEvent,
  locale: "ru" | "en"
): Pick<AdminNotificationItem, "title" | "message" | "category" | "tone"> {
  const payload = event.payload;
  const id = (key: string) => compactId(payload[key]);
  switch (event.type) {
    case "support.message.received": {
      const attachmentCount = getBoundedPayloadCount(payload.attachmentCount);
      const hasText = payload.hasText !== false;
      const receivedWhat = formatSupportNotificationContent({ attachmentCount, hasText, locale });
      return {
        title: locale === "ru" ? "Новое сообщение в поддержке" : "New support message",
        message:
          locale === "ru"
            ? `${receivedWhat} Диалог ${id("conversationId")} ждёт ответа оператора.`
            : `${receivedWhat} Conversation ${id("conversationId")} is waiting for an operator response.`,
        category: "support",
        tone: "info",
      };
    }
    case "generation.failed":
      return {
        title: locale === "ru" ? "Генерация завершилась ошибкой" : "Generation failed",
        message:
          locale === "ru"
            ? `Задание ${id("generationId")} требует проверки. Код: ${safePayloadText(payload.failureCode)}.`
            : `Job ${id("generationId")} needs review. Code: ${safePayloadText(payload.failureCode)}.`,
        category: "templates",
        tone: "warning",
      };
    case "generation.refund_exhausted":
      return {
        title: locale === "ru" ? "Возврат списания не выполнен" : "Charge refund exhausted",
        message:
          locale === "ru"
            ? `Автоматические попытки для ${id("generationId")} исчерпаны. Нужна ручная проверка.`
            : `Automatic attempts for ${id("generationId")} are exhausted. Manual review is required.`,
        category: "economy",
        tone: "error",
      };
    case "economy.incident.detected":
      return {
        title: locale === "ru" ? "Обнаружен финансовый инцидент" : "Economy incident detected",
        message:
          locale === "ru"
            ? `Инцидент ${id("incidentId")} требует сверки и решения.`
            : `Incident ${id("incidentId")} requires reconciliation and resolution.`,
        category: "economy",
        tone: event.priority === "critical" ? "error" : "warning",
      };
    case "capacity.provider_alert":
      return {
        title: locale === "ru" ? "Ограничение провайдера" : "Provider capacity alert",
        message:
          locale === "ru"
            ? "Проверьте доступную ёмкость и очередь генераций."
            : "Review provider capacity and the generation queue.",
        category: "templates",
        tone: event.priority === "critical" ? "error" : "warning",
      };
    default:
      return {
        title: locale === "ru" ? "Требуется внимание оператора" : "Operator attention required",
        message:
          locale === "ru"
            ? "Откройте связанный раздел и проверьте актуальное состояние."
            : "Open the related workspace and review the current state.",
        category: mapCategory(event.category),
        tone:
          event.priority === "critical"
            ? "error"
            : event.priority === "warning"
              ? "warning"
              : "info",
      };
  }
}

export function AdminNotificationsProvider({ children }: { children: ReactNode }) {
  const session = useAuthSession();
  const pathname = usePathname();
  const locale: "ru" | "en" = pathname.startsWith("/ru") ? "ru" : "en";
  const queryClient = useQueryClient();
  const [transientFeedback, setTransientFeedback] = useState<AddAdminNotificationInput | null>(
    null
  );
  const queryKey = adminQueryKeys.notifications({ state: "active", take: 24 });
  const query = useQuery({
    queryKey,
    queryFn: ({ signal }) => fetchAdminNotifications({ state: "active", take: 24 }, signal),
    enabled: Boolean(session?.user.userId),
    refetchInterval: 30_000,
    refetchOnWindowFocus: true,
    staleTime: 5_000,
  });

  useEffect(() => {
    if (!query.data || typeof window === "undefined") return;
    try {
      window.localStorage.removeItem(LEGACY_ADMIN_NOTIFICATIONS_STORAGE_KEY);
      const userStorageKey = getAdminNotificationStorageKey(session?.user.userId);
      if (userStorageKey) window.localStorage.removeItem(userStorageKey);
    } catch (error) {
      clientLogger.warn("admin.notifications_legacy_cleanup_failed", {
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
    }
  }, [query.data, session?.user.userId]);

  const invalidate = useCallback(() => {
    void queryClient.invalidateQueries({ queryKey: adminQueryKeys.notificationsRoot });
  }, [queryClient]);
  useAdminNotificationsRealtime(session?.accessToken, invalidate);
  const items = useMemo(
    () =>
      (query.data?.items ?? []).map((event): AdminNotificationItem => ({
        id: event.notificationId,
        ...localizeAdminNotification(event, locale),
        priority: event.priority === "critical" ? "critical" : "normal",
        href: localizeHref(event.href, locale),
        source: event.source,
        createdAt: event.createdAtUtc,
        read: Boolean(event.readAtUtc),
        archived: Boolean(event.archivedAtUtc),
        event,
      })),
    [locale, query.data?.items]
  );

  const markAsRead = useCallback(
    (notificationId: string) => {
      void markAdminNotificationRead(notificationId).then(invalidate).catch(logMutationFailure);
    },
    [invalidate]
  );
  const markAllAsRead = useCallback(() => {
    const cutoffUtc = query.data?.asOfUtc ?? new Date().toISOString();
    void markAllAdminNotificationsRead(cutoffUtc).then(invalidate).catch(logMutationFailure);
  }, [invalidate, query.data?.asOfUtc]);
  const removeNotification = useCallback(
    (notificationId: string) => {
      void archiveAdminNotification(notificationId).then(invalidate).catch(logMutationFailure);
    },
    [invalidate]
  );
  const markCategoryAsRead = useCallback(
    (category: AdminNotificationCategory) => {
      void Promise.all(
        items
          .filter((item) => item.category === category && !item.read)
          .map((item) => markAdminNotificationRead(item.id))
      )
        .then(invalidate)
        .catch(logMutationFailure);
    },
    [invalidate, items]
  );
  const clearRead = useCallback(() => {
    void Promise.all(
      items.filter((item) => item.read).map((item) => archiveAdminNotification(item.id))
    )
      .then(invalidate)
      .catch(logMutationFailure);
  }, [invalidate, items]);
  const addNotification = useCallback((input: AddAdminNotificationInput) => {
    setTransientFeedback({
      ...input,
      title: sanitizeAdminNotificationText(input.title, 96),
      message: sanitizeAdminNotificationText(input.message, 280),
    });
  }, []);

  useEffect(() => {
    if (!transientFeedback) return;
    const timer = window.setTimeout(() => setTransientFeedback(null), 3_200);
    return () => window.clearTimeout(timer);
  }, [transientFeedback]);

  const value = useMemo<AdminNotificationsContextValue>(
    () => ({
      items,
      unreadCount: query.data?.unreadCount ?? 0,
      criticalUnacknowledgedCount: query.data?.criticalUnacknowledgedCount ?? 0,
      asOfUtc: query.data?.asOfUtc,
      isLoading: query.isLoading,
      addNotification,
      markAsRead,
      markCategoryAsRead,
      markAllAsRead,
      clearRead,
      removeNotification,
      refresh: invalidate,
    }),
    [
      addNotification,
      clearRead,
      invalidate,
      items,
      markAllAsRead,
      markAsRead,
      markCategoryAsRead,
      query.data,
      query.isLoading,
      removeNotification,
    ]
  );

  return (
    <AdminNotificationsContext.Provider value={value}>
      {children}
      {transientFeedback ? (
        <div
          className={`ui-toast ui-toast--${transientFeedback.tone === "error" ? "error" : "success"}`}
          role={transientFeedback.tone === "error" ? "alert" : "status"}
          aria-live={transientFeedback.tone === "error" ? "assertive" : "polite"}
        >
          <strong>{transientFeedback.title}</strong>
          <div>{transientFeedback.message}</div>
        </div>
      ) : null}
    </AdminNotificationsContext.Provider>
  );
}

export function useAdminNotifications() {
  const context = useContext(AdminNotificationsContext);
  if (!context)
    throw new Error("useAdminNotifications must be used within AdminNotificationsProvider");
  return context;
}

export function useSyncToastToAdminNotifications(
  _toast: ToastLike | null,
  _options: SyncToastOptions
) {
  void _toast;
  void _options;
  // Deliberately empty: action results are already rendered as transient toasts.
}

export function useSyncFeedbackToAdminNotifications(
  _feedback: FeedbackLike | null,
  _options: SyncFeedbackOptions
) {
  void _feedback;
  void _options;
  // Deliberately empty: persistent inbox events originate from trusted server transitions.
}

function sanitizeNotificationHref(href: unknown): string | undefined {
  if (typeof href !== "string") return undefined;
  const trimmed = href.trim();
  if (!trimmed.startsWith("/") || trimmed.startsWith("//") || trimmed.includes("\\"))
    return undefined;
  return trimmed.length <= 512 ? trimmed : undefined;
}

function localizeHref(href: string | null | undefined, locale: "ru" | "en") {
  const safeHref = sanitizeNotificationHref(href);
  if (!safeHref) return undefined;
  if (/^\/(ru|en)(?:\/|$)/.test(safeHref)) return safeHref;
  return `/${locale}${safeHref}`;
}

function safePayloadText(value: unknown) {
  return typeof value === "string" ? sanitizeAdminNotificationText(value, 80) : "—";
}

function getBoundedPayloadCount(value: unknown): number {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0
    ? Math.min(value, 99)
    : 0;
}

function formatSupportNotificationContent({
  attachmentCount,
  hasText,
  locale,
}: {
  attachmentCount: number;
  hasText: boolean;
  locale: "ru" | "en";
}) {
  if (attachmentCount === 0) {
    return locale === "ru" ? "Пользователь написал сообщение." : "The customer sent a message.";
  }

  const attachmentLabel =
    locale === "ru"
      ? `Пользователь ${hasText ? "написал сообщение и прикрепил" : "прикрепил"} ${attachmentCount} ${formatRussianAttachmentWord(attachmentCount)}.`
      : `The customer ${hasText ? "sent a message with" : "attached"} ${attachmentCount} ${attachmentCount === 1 ? "file" : "files"}.`;

  return attachmentLabel;
}

function formatRussianAttachmentWord(count: number) {
  const lastTwoDigits = count % 100;
  const lastDigit = count % 10;
  if (lastTwoDigits >= 11 && lastTwoDigits <= 14) return "файлов";
  if (lastDigit === 1) return "файл";
  if (lastDigit >= 2 && lastDigit <= 4) return "файла";
  return "файлов";
}

function compactId(value: unknown) {
  const raw = typeof value === "string" ? value.trim() : "";
  const safe = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(raw) ? raw : safePayloadText(value);
  const prefixLength = /^\d{6}/.test(safe) ? 4 : 8;
  return safe.length > 12 ? `${safe.slice(0, prefixLength)}…${safe.slice(-4)}` : safe;
}

function mapCategory(category: string): AdminNotificationCategory {
  if (category === "support") return "support";
  if (category === "economy") return "economy";
  if (
    category === "content" ||
    category === "generation" ||
    category === "capacity" ||
    category === "moderation"
  )
    return "templates";
  return "system";
}

function logMutationFailure(error: unknown) {
  clientLogger.warn("admin.notifications_mutation_failed", {
    errorName: error instanceof Error ? error.name : "UnknownError",
  });
}
