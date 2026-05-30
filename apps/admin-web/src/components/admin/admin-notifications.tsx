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

export type AdminNotificationCategory =
  | "support"
  | "users"
  | "templates"
  | "economy"
  | "promo"
  | "system";
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

const AdminNotificationsContext = createContext<AdminNotificationsContextValue | null>(null);

export function AdminNotificationsProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<AdminNotificationItem[]>([]);
  const dedupeMapRef = useRef<Map<string, number>>(new Map());

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    try {
      const raw = window.localStorage.getItem(ADMIN_NOTIFICATIONS_STORAGE_KEY);
      if (!raw) {
        return;
      }

      const parsed = JSON.parse(raw) as AdminNotificationItem[];
      if (!Array.isArray(parsed)) {
        return;
      }

      const now = Date.now();
      const hydratedItems = parsed
        .filter((item) => {
          const createdAt = new Date(item.createdAt).getTime();
          return Number.isFinite(createdAt) && now - createdAt <= MAX_PERSISTED_AGE_MS;
        })
        .map((item) => {
          const tone = item.tone ?? "info";
          return {
            ...item,
            tone,
            priority:
              item.priority ?? (tone === "error" || tone === "warning" ? "critical" : "normal"),
          };
        })
        .filter((item) =>
          isActionableAdminNotification({
            source: item.source,
            tone: item.tone,
          })
        )
        .slice(0, MAX_ADMIN_NOTIFICATIONS);

      setItems(hydratedItems);
    } catch {
      window.localStorage.removeItem(ADMIN_NOTIFICATIONS_STORAGE_KEY);
    }
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    window.localStorage.setItem(ADMIN_NOTIFICATIONS_STORAGE_KEY, JSON.stringify(items));
  }, [items]);

  const addNotification = useCallback((input: AddAdminNotificationInput) => {
    const tone = input.tone ?? "info";
    if (
      !isActionableAdminNotification({
        source: input.source,
        tone,
      })
    ) {
      return;
    }

    const now = Date.now();
    const dedupeKey =
      input.dedupeKey ??
      [input.source, input.category, tone, input.title, input.message, input.href]
        .filter(Boolean)
        .join("::");
    const previousTimestamp = dedupeMapRef.current.get(dedupeKey);

    if (previousTimestamp && now - previousTimestamp < DEDUPE_WINDOW_MS) {
      return;
    }

    dedupeMapRef.current.set(dedupeKey, now);

    const notification: AdminNotificationItem = {
      id: `${now}-${Math.random().toString(36).slice(2, 8)}`,
      title: input.title,
      message: input.message,
      category: input.category,
      tone,
      priority: input.priority ?? (tone === "error" || tone === "warning" ? "critical" : "normal"),
      href: input.href,
      source: input.source,
      createdAt: new Date(now).toISOString(),
      read: false,
    };

    setItems((current) => [notification, ...current].slice(0, MAX_ADMIN_NOTIFICATIONS));
  }, []);

  const markAsRead = useCallback((notificationId: string) => {
    setItems((current) =>
      current.map((item) => (item.id === notificationId ? { ...item, read: true } : item))
    );
  }, []);

  const markCategoryAsRead = useCallback((category: AdminNotificationCategory) => {
    setItems((current) =>
      current.map((item) =>
        item.category === category && !item.read ? { ...item, read: true } : item
      )
    );
  }, []);

  const markAllAsRead = useCallback(() => {
    setItems((current) => current.map((item) => (item.read ? item : { ...item, read: true })));
  }, []);

  const clearRead = useCallback(() => {
    setItems((current) => current.filter((item) => !item.read));
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
      dedupeKey: `${source}:${toast.type}:${toast.message}:${href ?? ""}`,
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
      dedupeKey: `${source}:${feedback.tone}:${feedback.message}:${href ?? ""}`,
    });
  }, [addNotification, category, feedback, href, source, title]);
}
