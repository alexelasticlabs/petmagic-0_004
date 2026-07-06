"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

import { isActionableAdminNotification } from "@/lib/admin-notification-policy";
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
  addNotification: (input: AddAdminNotificationInput) => void;
  markAsRead: (notificationId: string) => void;
  markCategoryAsRead: (category: AdminNotificationCategory) => void;
  markAllAsRead: () => void;
  clearRead: () => void;
  removeNotification: (notificationId: string) => void;
};

type ToastLike = {
  type: "success" | "error";
  message: string;
};

type SyncToastOptions = {
  category: AdminNotificationCategory;
  source: string;
  title: string | ((toast: ToastLike) => string);
  href?: string;
};

type FeedbackLike = {
  tone: "success" | "danger" | "info";
  message: string;
};

type SyncFeedbackOptions = {
  category: AdminNotificationCategory;
  source: string;
  title: string | ((feedback: FeedbackLike) => string);
  href?: string;
};

const MAX_ADMIN_NOTIFICATIONS = 24;
const DEDUPE_WINDOW_MS = 4000;
const ADMIN_NOTIFICATIONS_STORAGE_KEY = "petmagic.admin.notifications.v1";
const MAX_PERSISTED_AGE_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_NOTIFICATION_TITLE_LENGTH = 120;
const MAX_NOTIFICATION_MESSAGE_LENGTH = 280;
const MAX_NOTIFICATION_SOURCE_LENGTH = 120;
const MAX_NOTIFICATION_HREF_LENGTH = 240;
const MAX_NOTIFICATION_DEDUPE_KEY_LENGTH = 360;

const notificationCategories = new Set<AdminNotificationCategory>([
  "support",
  "users",
  "templates",
  "economy",
  "promo",
  "system",
]);
const notificationTones = new Set<AdminNotificationTone>(["info", "success", "warning", "error"]);
const notificationPriorities = new Set<AdminNotificationPriority>(["normal", "critical"]);
let adminNotificationIdSequence = 0;

export function createAdminNotificationId(now: number = Date.now()): string {
  const crypto = globalThis.crypto;
  if (typeof crypto?.randomUUID === "function") {
    return `${now}-${crypto.randomUUID()}`;
  }

  if (typeof crypto?.getRandomValues === "function") {
    const bytes = new Uint8Array(8);
    crypto.getRandomValues(bytes);
    const randomHex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
    return `${now}-${randomHex}`;
  }

  adminNotificationIdSequence = (adminNotificationIdSequence + 1) % Number.MAX_SAFE_INTEGER;
  return `${now}-${adminNotificationIdSequence.toString(36)}`;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function getAdminNotificationStorageErrorDetails(error: unknown): {
  errorName: string;
  errorDigest?: string;
} {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function removeStoredAdminNotifications(storageFailureEvent: string): void {
  if (typeof window === "undefined") {
    return;
  }

  try {
    window.localStorage.removeItem(ADMIN_NOTIFICATIONS_STORAGE_KEY);
  } catch (error) {
    clientLogger.warn(storageFailureEvent, getAdminNotificationStorageErrorDetails(error));
  }
}

function sanitizeNotificationHref(href: unknown): string | undefined {
  if (typeof href !== "string") {
    return undefined;
  }

  const trimmed = href.trim();
  if (!trimmed || !trimmed.startsWith("/") || trimmed.startsWith("//")) {
    return undefined;
  }

  const sanitizedPath = trimmed.split(/[?#]/, 1)[0];
  if (!sanitizedPath || sanitizedPath.length > MAX_NOTIFICATION_HREF_LENGTH) {
    return undefined;
  }

  return sanitizedPath;
}

export function sanitizeAdminNotificationText(value: string, maxLength: number): string {
  return sanitizeSensitiveText(value, maxLength);
}

export function sanitizeAdminNotificationDedupeKey(value: string): string {
  return sanitizeAdminNotificationText(value, MAX_NOTIFICATION_DEDUPE_KEY_LENGTH);
}

export function sanitizeAdminNotificationSource(value: string): string {
  const trimmed = value.trim();
  return trimmed ? sanitizeAdminNotificationText(trimmed, MAX_NOTIFICATION_SOURCE_LENGTH) : "";
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
      sanitizeAdminNotificationText(type, MAX_NOTIFICATION_TITLE_LENGTH),
      sanitizeAdminNotificationText(message, MAX_NOTIFICATION_MESSAGE_LENGTH),
      sanitizeNotificationHref(href) ?? "",
    ].join(":")
  );
}

function toHydratedNotificationItem(rawValue: unknown, now: number): AdminNotificationItem | null {
  if (!isRecord(rawValue)) {
    return null;
  }

  const id = typeof rawValue.id === "string" ? rawValue.id : "";
  const title =
    typeof rawValue.title === "string"
      ? sanitizeAdminNotificationText(rawValue.title, MAX_NOTIFICATION_TITLE_LENGTH)
      : "";
  const message =
    typeof rawValue.message === "string"
      ? sanitizeAdminNotificationText(rawValue.message, MAX_NOTIFICATION_MESSAGE_LENGTH)
      : "";
  const source =
    typeof rawValue.source === "string" ? sanitizeAdminNotificationSource(rawValue.source) : "";
  const createdAt = typeof rawValue.createdAt === "string" ? rawValue.createdAt : "";
  const read = typeof rawValue.read === "boolean" ? rawValue.read : false;
  const category = rawValue.category;
  const tone = rawValue.tone;
  const priority = rawValue.priority;

  if (!id || !title || !message || !source || !createdAt) {
    return null;
  }

  if (!notificationCategories.has(category as AdminNotificationCategory)) {
    return null;
  }

  const createdAtTs = new Date(createdAt).getTime();
  if (!Number.isFinite(createdAtTs) || now - createdAtTs > MAX_PERSISTED_AGE_MS) {
    return null;
  }

  const resolvedTone: AdminNotificationTone = notificationTones.has(tone as AdminNotificationTone)
    ? (tone as AdminNotificationTone)
    : "info";
  const resolvedPriority: AdminNotificationPriority = notificationPriorities.has(
    priority as AdminNotificationPriority
  )
    ? (priority as AdminNotificationPriority)
    : resolvedTone === "error" || resolvedTone === "warning"
      ? "critical"
      : "normal";

  return {
    id,
    title,
    message,
    source,
    createdAt,
    read,
    category: category as AdminNotificationCategory,
    tone: resolvedTone,
    priority: resolvedPriority,
    href: sanitizeNotificationHref(rawValue.href),
  };
}

function readInitialAdminNotifications(): AdminNotificationItem[] {
  if (typeof window === "undefined") {
    return [];
  }

  try {
    const raw = window.localStorage.getItem(ADMIN_NOTIFICATIONS_STORAGE_KEY);
    if (!raw) {
      return [];
    }

    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) {
      removeStoredAdminNotifications("admin.notifications_invalid_storage_cleanup_failed");
      return [];
    }

    const now = Date.now();
    const hydrated = parsed
      .map((item) => toHydratedNotificationItem(item, now))
      .filter((item): item is AdminNotificationItem => item !== null)
      .filter((item) =>
        isActionableAdminNotification({
          source: item.source,
          tone: item.tone,
        })
      )
      .slice(0, MAX_ADMIN_NOTIFICATIONS);

    if (hydrated.length === 0) {
      removeStoredAdminNotifications("admin.notifications_empty_hydration_cleanup_failed");
    }

    return hydrated;
  } catch (error) {
    clientLogger.warn(
      "admin.notifications_hydrate_failed",
      getAdminNotificationStorageErrorDetails(error)
    );
    removeStoredAdminNotifications("admin.notifications_hydrate_cleanup_failed");
    return [];
  }
}

const AdminNotificationsContext = createContext<AdminNotificationsContextValue | null>(null);

export function AdminNotificationsProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<AdminNotificationItem[]>(readInitialAdminNotifications);
  const dedupeMapRef = useRef<Map<string, number>>(new Map());

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    if (items.length === 0) {
      removeStoredAdminNotifications("admin.notifications_empty_persist_cleanup_failed");
      return;
    }

    try {
      window.localStorage.setItem(ADMIN_NOTIFICATIONS_STORAGE_KEY, JSON.stringify(items));
    } catch (error) {
      clientLogger.warn(
        "admin.notifications_persist_failed",
        getAdminNotificationStorageErrorDetails(error)
      );
    }
  }, [items]);

  const addNotification = useCallback((input: AddAdminNotificationInput) => {
    const tone = input.tone ?? "info";
    const safeHref = sanitizeNotificationHref(input.href);
    const sanitizedSource = sanitizeAdminNotificationSource(input.source);
    if (
      !isActionableAdminNotification({
        source: sanitizedSource,
        tone,
      })
    ) {
      return;
    }

    const now = Date.now();
    const sanitizedTitle = sanitizeAdminNotificationText(
      input.title,
      MAX_NOTIFICATION_TITLE_LENGTH
    );
    const sanitizedMessage = sanitizeAdminNotificationText(
      input.message,
      MAX_NOTIFICATION_MESSAGE_LENGTH
    );
    const sanitizedInputDedupeKey = input.dedupeKey?.trim()
      ? sanitizeAdminNotificationDedupeKey(input.dedupeKey)
      : undefined;
    const dedupeKey =
      sanitizedInputDedupeKey ??
      [sanitizedSource, input.category, tone, sanitizedTitle, sanitizedMessage, safeHref]
        .filter(Boolean)
        .join("::");
    const previousTimestamp = dedupeMapRef.current.get(dedupeKey);

    if (previousTimestamp && now - previousTimestamp < DEDUPE_WINDOW_MS) {
      return;
    }

    dedupeMapRef.current.set(dedupeKey, now);

    const notification: AdminNotificationItem = {
      id: createAdminNotificationId(now),
      title: sanitizedTitle,
      message: sanitizedMessage,
      category: input.category,
      tone,
      priority: input.priority ?? (tone === "error" || tone === "warning" ? "critical" : "normal"),
      href: safeHref,
      source: sanitizedSource,
      createdAt: new Date(now).toISOString(),
      read: false,
    };

    setItems((current) => [notification, ...current].slice(0, MAX_ADMIN_NOTIFICATIONS));
  }, []);

  const markAsRead = useCallback((notificationId: string) => {
    setItems((current) => {
      let didChange = false;
      const next = current.map((item) => {
        if (item.id !== notificationId || item.read) {
          return item;
        }

        didChange = true;
        return { ...item, read: true };
      });

      return didChange ? next : current;
    });
  }, []);

  const markCategoryAsRead = useCallback((category: AdminNotificationCategory) => {
    setItems((current) => {
      let didChange = false;
      const next = current.map((item) => {
        if (item.category !== category || item.read) {
          return item;
        }

        didChange = true;
        return { ...item, read: true };
      });

      return didChange ? next : current;
    });
  }, []);

  const markAllAsRead = useCallback(() => {
    setItems((current) => {
      let didChange = false;
      const next = current.map((item) => {
        if (item.read) {
          return item;
        }

        didChange = true;
        return { ...item, read: true };
      });

      return didChange ? next : current;
    });
  }, []);

  const clearRead = useCallback(() => {
    setItems((current) => {
      if (current.every((item) => !item.read)) {
        return current;
      }

      return current.filter((item) => !item.read);
    });
  }, []);

  const removeNotification = useCallback((notificationId: string) => {
    setItems((current) => current.filter((item) => item.id !== notificationId));
  }, []);

  const value = useMemo<AdminNotificationsContextValue>(
    () => ({
      items,
      unreadCount: items.reduce((count, item) => count + (item.read ? 0 : 1), 0),
      addNotification,
      markAsRead,
      markCategoryAsRead,
      markAllAsRead,
      clearRead,
      removeNotification,
    }),
    [
      addNotification,
      clearRead,
      items,
      markAllAsRead,
      markAsRead,
      markCategoryAsRead,
      removeNotification,
    ]
  );

  return (
    <AdminNotificationsContext.Provider value={value}>
      {children}
    </AdminNotificationsContext.Provider>
  );
}

export function useAdminNotifications() {
  const context = useContext(AdminNotificationsContext);
  if (!context) {
    throw new Error("useAdminNotifications must be used within AdminNotificationsProvider");
  }

  return context;
}

export function useSyncToastToAdminNotifications(
  toast: ToastLike | null,
  { category, source, title, href }: SyncToastOptions
) {
  const { addNotification } = useAdminNotifications();

  useEffect(() => {
    if (!toast) {
      return;
    }

    addNotification({
      title: typeof title === "function" ? title(toast) : title,
      message: toast.message,
      category,
      source,
      tone: toast.type === "success" ? "success" : "error",
      priority: toast.type === "error" ? "critical" : "normal",
      href,
      dedupeKey: buildAdminNotificationDedupeKey(source, toast.type, toast.message, href),
    });
  }, [addNotification, category, href, source, title, toast]);
}

export function useSyncFeedbackToAdminNotifications(
  feedback: FeedbackLike | null,
  { category, source, title, href }: SyncFeedbackOptions
) {
  const { addNotification } = useAdminNotifications();

  useEffect(() => {
    if (!feedback) {
      return;
    }

    addNotification({
      title: typeof title === "function" ? title(feedback) : title,
      message: feedback.message,
      category,
      source,
      tone: feedback.tone === "success" ? "success" : feedback.tone === "danger" ? "error" : "info",
      priority: feedback.tone === "danger" ? "critical" : "normal",
      href,
      dedupeKey: buildAdminNotificationDedupeKey(source, feedback.tone, feedback.message, href),
    });
  }, [addNotification, category, feedback, href, source, title]);
}
