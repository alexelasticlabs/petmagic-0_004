"use client";

import { useInfiniteQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useMemo, useState } from "react";

import { localizeAdminNotification } from "@/components/admin/admin-notifications";
import {
  AdminBadge,
  AdminCard,
  AdminMetricStrip,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import styles from "@/components/admin-notifications-view.module.css";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  acknowledgeAdminNotification,
  archiveAdminNotification,
  fetchAdminNotifications,
  markAdminNotificationRead,
  type AdminNotificationEvent,
  type AdminNotificationPriority,
  type AdminNotificationState,
} from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

const states: AdminNotificationState[] = ["active", "unread", "read", "archived", "all"];
const priorities = ["all", "normal", "warning", "critical"] as const;

export function AdminNotificationsView({ locale }: { locale: Locale }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const queryClient = useQueryClient();
  const state = states.includes(searchParams.get("state") as AdminNotificationState)
    ? (searchParams.get("state") as AdminNotificationState)
    : "active";
  const priorityValue = searchParams.get("priority");
  const priority = priorities.includes(priorityValue as (typeof priorities)[number])
    ? (priorityValue as (typeof priorities)[number])
    : "all";
  const category = searchParams.get("category")?.slice(0, 32) || "all";
  const queryKey = adminQueryKeys.notifications({ state, priority, category });
  const query = useInfiniteQuery({
    queryKey,
    initialPageParam: undefined as string | undefined,
    queryFn: ({ pageParam, signal }) =>
      fetchAdminNotifications(
        {
          cursor: pageParam,
          take: 30,
          state,
          priority: priority === "all" ? undefined : (priority as AdminNotificationPriority),
          category: category === "all" ? undefined : category,
        },
        signal
      ),
    getNextPageParam: (page) => page.nextCursor ?? undefined,
  });
  const page = query.data?.pages[0];
  const items = query.data?.pages.flatMap((item) => item.items) ?? [];
  const copy = locale === "ru" ? ruCopy : enCopy;

  function setFilter(key: "state" | "priority" | "category", value: string) {
    const params = new URLSearchParams(searchParams.toString());
    if (value === "all" || (key === "state" && value === "active")) params.delete(key);
    else params.set(key, value);
    const suffix = params.toString();
    router.replace(`/${locale}/notifications${suffix ? `?${suffix}` : ""}`);
  }

  const refresh = () =>
    void queryClient.invalidateQueries({ queryKey: adminQueryKeys.notificationsRoot });

  return (
    <div className={styles.page}>
      <section className={styles.contextBar} aria-label={copy.contextLabel}>
        <div>
          <strong>{copy.contextTitle}</strong>
          <span>
            {page?.asOfUtc ? copy.updated(formatDate(page.asOfUtc, locale)) : copy.syncing}
          </span>
        </div>
        <button
          type="button"
          className="ui-button ui-button--secondary ui-button--sm"
          onClick={refresh}
        >
          {copy.refresh}
        </button>
      </section>

      <AdminMetricStrip
        items={[
          { label: copy.unread, value: page?.unreadCount ?? "—" },
          { label: copy.critical, value: page?.criticalUnacknowledgedCount ?? "—" },
          { label: copy.visible, value: items.length },
        ]}
      />

      <AdminCard padding="md" className={styles.filters}>
        <label>
          <span>{copy.state}</span>
          <select value={state} onChange={(event) => setFilter("state", event.target.value)}>
            {states.map((value) => (
              <option key={value} value={value}>
                {copy.states[value]}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span>{copy.priority}</span>
          <select value={priority} onChange={(event) => setFilter("priority", event.target.value)}>
            {priorities.map((value) => (
              <option key={value} value={value}>
                {copy.priorities[value]}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span>{copy.category}</span>
          <select value={category} onChange={(event) => setFilter("category", event.target.value)}>
            {Object.entries(copy.categories).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
      </AdminCard>

      {query.isLoading ? <AdminStateCard title={copy.loading} /> : null}
      {query.isError ? (
        <AdminStateCard
          tone="danger"
          title={copy.error}
          description={copy.errorHint}
          action={
            <button
              type="button"
              className="ui-button ui-button--primary ui-button--sm"
              onClick={() => void query.refetch()}
            >
              {copy.retry}
            </button>
          }
        />
      ) : null}
      {!query.isLoading && !query.isError && items.length === 0 ? (
        <AdminStateCard title={copy.empty} description={copy.emptyHint} />
      ) : null}

      {items.length > 0 ? (
        <section className={styles.list} aria-label={copy.listLabel}>
          {items.map((item) => (
            <NotificationRow
              key={item.notificationId}
              item={item}
              locale={locale}
              onChanged={refresh}
            />
          ))}
        </section>
      ) : null}

      {query.hasNextPage ? (
        <button
          type="button"
          className="ui-button ui-button--secondary ui-button--sm"
          disabled={query.isFetchingNextPage}
          onClick={() => void query.fetchNextPage()}
        >
          {query.isFetchingNextPage ? copy.loading : copy.loadMore}
        </button>
      ) : null}
    </div>
  );
}

function NotificationRow({
  item,
  locale,
  onChanged,
}: {
  item: AdminNotificationEvent;
  locale: Locale;
  onChanged: () => void;
}) {
  const [ackOpen, setAckOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [mutationFeedback, setMutationFeedback] = useState<{
    tone: "info" | "error";
    message: string;
  } | null>(null);
  const localized = useMemo(() => localizeAdminNotification(item, locale), [item, locale]);
  const copy = locale === "ru" ? ruCopy : enCopy;
  const href = item.href ? `/${locale}${item.href}` : undefined;
  const criticalPending = item.priority === "critical" && !item.acknowledgement;

  async function run(action: () => Promise<unknown>, closeAcknowledgementOnSuccess = false) {
    setBusy(true);
    setMutationFeedback(null);
    try {
      await action();
      if (closeAcknowledgementOnSuccess) {
        setAckOpen(false);
        setReason("");
      }
      onChanged();
    } catch (error) {
      const isConflict =
        typeof error === "object" && error !== null && "status" in error && error.status === 409;
      setMutationFeedback({
        tone: isConflict ? "info" : "error",
        message: isConflict ? copy.conflict : copy.mutationError,
      });
      // A conflict response contains the current server snapshot. Refetching the
      // shared query also updates the topbar inbox and keeps this row authoritative.
      onChanged();
    } finally {
      setBusy(false);
    }
  }

  return (
    <article className={`${styles.item} ${!item.readAtUtc ? styles.unread : ""}`}>
      <div className={styles.itemMain}>
        <div className={styles.itemMeta}>
          <AdminBadge
            tone={
              item.priority === "critical"
                ? "danger"
                : item.priority === "warning"
                  ? "warning"
                  : "info"
            }
          >
            {copy.priorities[item.priority]}
          </AdminBadge>
          <span>
            {copy.categories[item.category as keyof typeof copy.categories] ?? item.category}
          </span>
          <time dateTime={item.createdAtUtc}>{formatDate(item.createdAtUtc, locale)}</time>
        </div>
        <strong>{localized.title}</strong>
        <p>{localized.message}</p>
        {item.acknowledgement ? (
          <small>
            {copy.acknowledged(
              formatDate(item.acknowledgement.acknowledgedAtUtc, locale),
              item.acknowledgement.reason
            )}
          </small>
        ) : null}
      </div>
      <div className={styles.actions}>
        {href ? (
          <Link href={href} className="ui-button ui-button--secondary ui-button--sm">
            {copy.open}
          </Link>
        ) : null}
        {!item.readAtUtc ? (
          <button
            type="button"
            className="ui-button ui-button--secondary ui-button--sm"
            disabled={busy}
            onClick={() => void run(() => markAdminNotificationRead(item.notificationId))}
          >
            {copy.read}
          </button>
        ) : null}
        {criticalPending ? (
          <button
            type="button"
            className="ui-button ui-button--primary ui-button--sm"
            disabled={busy}
            onClick={() => setAckOpen((value) => !value)}
          >
            {copy.ack}
          </button>
        ) : null}
        <button
          type="button"
          className="ui-button ui-button--secondary ui-button--sm"
          disabled={busy}
          onClick={() => void run(() => archiveAdminNotification(item.notificationId))}
        >
          {copy.archive}
        </button>
      </div>
      {mutationFeedback ? (
        <p
          className={`${styles.mutationFeedback} ${
            mutationFeedback.tone === "error" ? styles.mutationError : ""
          }`}
          role={mutationFeedback.tone === "error" ? "alert" : "status"}
        >
          {mutationFeedback.message}
        </p>
      ) : null}
      {ackOpen ? (
        <form
          className={styles.ackForm}
          onSubmit={(event) => {
            event.preventDefault();
            if (reason.trim().length >= 3)
              void run(
                () =>
                  acknowledgeAdminNotification(item.notificationId, item.version, reason.trim()),
                true
              );
          }}
        >
          <label>
            <span>{copy.reason}</span>
            <textarea
              value={reason}
              minLength={3}
              maxLength={500}
              required
              onChange={(event) => setReason(event.target.value)}
            />
          </label>
          <button
            type="submit"
            className="ui-button ui-button--primary ui-button--sm"
            disabled={busy || reason.trim().length < 3}
          >
            {copy.confirmAck}
          </button>
        </form>
      ) : null}
    </article>
  );
}

function formatDate(value: string, locale: Locale) {
  return new Intl.DateTimeFormat(locale === "ru" ? "ru-BY" : "en-GB", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(value));
}

const ruCopy = {
  contextLabel: "Контекст inbox",
  contextTitle: "Командный inbox",
  syncing: "Синхронизация…",
  updated: (value: string) => `Обновлено ${value}`,
  refresh: "Обновить",
  unread: "Непрочитанные",
  critical: "Критические без подтверждения",
  visible: "В выборке",
  state: "Состояние",
  priority: "Приоритет",
  category: "Категория",
  loading: "Загружаем события…",
  error: "Не удалось загрузить inbox",
  errorHint: "Проверьте соединение и повторите запрос.",
  retry: "Повторить",
  empty: "Событий нет",
  emptyHint: "Для выбранных фильтров нет операционных событий.",
  listLabel: "Операционные уведомления",
  loadMore: "Показать ещё",
  open: "Открыть",
  read: "Прочитано",
  ack: "Подтвердить",
  archive: "В архив",
  reason: "Причина подтверждения",
  confirmAck: "Подтвердить событие",
  conflict: "Событие уже изменил другой оператор. Загружено актуальное состояние.",
  mutationError: "Не удалось выполнить действие. Состояние обновлено — повторите попытку.",
  acknowledged: (at: string, reason: string) => `Подтверждено ${at}: ${reason}`,
  states: {
    active: "Активные",
    unread: "Непрочитанные",
    read: "Прочитанные",
    archived: "Архив",
    all: "Все",
  },
  priorities: { all: "Все", normal: "Обычный", warning: "Внимание", critical: "Критический" },
  categories: {
    all: "Все",
    support: "Поддержка",
    generation: "Генерации",
    capacity: "Ёмкость",
    economy: "Экономика",
    content: "Контент",
    moderation: "Модерация",
    system: "Система",
  },
};
const enCopy = {
  contextLabel: "Inbox context",
  contextTitle: "Team inbox",
  syncing: "Syncing…",
  updated: (value: string) => `Updated ${value}`,
  refresh: "Refresh",
  unread: "Unread",
  critical: "Critical unacknowledged",
  visible: "In view",
  state: "State",
  priority: "Priority",
  category: "Category",
  loading: "Loading events…",
  error: "Could not load inbox",
  errorHint: "Check the connection and retry.",
  retry: "Retry",
  empty: "No events",
  emptyHint: "No operational events match these filters.",
  listLabel: "Operational notifications",
  loadMore: "Load more",
  open: "Open",
  read: "Mark read",
  ack: "Acknowledge",
  archive: "Archive",
  reason: "Acknowledgement reason",
  confirmAck: "Confirm acknowledgement",
  conflict: "Another operator already changed this event. The latest state has been loaded.",
  mutationError: "The action could not be completed. State was refreshed; try again.",
  acknowledged: (at: string, reason: string) => `Acknowledged ${at}: ${reason}`,
  states: { active: "Active", unread: "Unread", read: "Read", archived: "Archived", all: "All" },
  priorities: { all: "All", normal: "Normal", warning: "Warning", critical: "Critical" },
  categories: {
    all: "All",
    support: "Support",
    generation: "Generations",
    capacity: "Capacity",
    economy: "Economy",
    content: "Content",
    moderation: "Moderation",
    system: "System",
  },
};
