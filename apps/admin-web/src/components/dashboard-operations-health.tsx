"use client";

import { useQuery } from "@tanstack/react-query";

import {
  AdminBadge,
  AdminCard,
  AdminSectionHeader,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import styles from "@/components/dashboard-view.module.css";
import { Button } from "@/components/ui/button";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchAdminOperationsStatus, type AdminOperationsSourceStatus } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type DashboardOperationsHealthProps = {
  locale: Locale;
  enabled: boolean;
};

const copy = {
  ru: {
    title: "Операционное здоровье",
    description:
      "Актуальный статус доставок, очередей и worker. Обновляется автоматически каждые 30 секунд.",
    unavailable: "Операционные агрегаты недоступны",
    retry: "Повторить",
    backlog: "ожидают отправки",
    deadLetters: "неотправленных",
    oldest: "старейшая",
    email: "Доставка email",
    audit: "Журнал аудита",
    push: "Доставка push-уведомлений",
    generations: "Очередь генераций",
    economy: "Платёжные инциденты",
    workers: "Worker генераций",
    queue: "в очереди",
    open: "открыто",
    critical: "критично",
    heartbeat: "heartbeat",
    noHeartbeat: "нет heartbeat",
    healthy: "Норма",
    degraded: "Внимание",
    unhealthy: "Критично",
    unknown: "Нет данных",
    queueHealthy: "Новых отправок не ожидается; доставка работает штатно.",
    queueBacklog: (count: number) => `${count} отправл. ожидают обработки.`,
    queueDeadLetter: (count: number) =>
      `${count} отправл. не будет доставлено автоматически: все попытки исчерпаны.`,
    queueNextStep:
      "Проверьте запись в журнале worker, устраните причину и инициируйте событие повторно. Повтор сам по себе не запускается, чтобы не отправить дубль.",
  },
  en: {
    title: "Operations health",
    description:
      "Current delivery, queue, and worker status. Refreshes automatically every 30 seconds.",
    unavailable: "Operations aggregates are unavailable",
    retry: "Retry",
    backlog: "queued",
    deadLetters: "dead letter",
    oldest: "oldest",
    email: "Email delivery",
    audit: "Audit outbox",
    push: "Push notification delivery",
    generations: "Generation queue",
    economy: "Economy incidents",
    workers: "Workers",
    queue: "queued",
    open: "open",
    critical: "critical",
    heartbeat: "heartbeat",
    noHeartbeat: "no heartbeat",
    healthy: "Healthy",
    degraded: "Attention",
    unhealthy: "Critical",
    unknown: "Unavailable",
    queueHealthy: "No new deliveries are waiting; this path is operating normally.",
    queueBacklog: (count: number) => `${count} delivery item(s) are waiting to be processed.`,
    queueDeadLetter: (count: number) =>
      `${count} delivery item(s) will not be retried automatically because all attempts were exhausted.`,
    queueNextStep:
      "Review the worker journal entry, fix the cause, and trigger the event again. It is not retried automatically to avoid duplicate delivery.",
  },
} as const;

function tone(status: AdminOperationsSourceStatus) {
  if (status === "healthy") return "success" as const;
  if (status === "degraded") return "warning" as const;
  if (status === "unhealthy") return "danger" as const;
  return "neutral" as const;
}

function formatAge(seconds: number | null | undefined, locale: Locale) {
  if (seconds === null || seconds === undefined) return "—";
  if (seconds < 60) return `${Math.floor(seconds)}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  const hours = Math.floor(seconds / 3600);
  return locale === "ru" ? `${hours} ч` : `${hours}h`;
}

export function getQueueExplanation(
  locale: Locale,
  backlogCount: number,
  deadLetterCount: number
): { summary: string; nextStep?: string } {
  const text = copy[locale];
  if (deadLetterCount > 0) {
    return {
      summary: text.queueDeadLetter(deadLetterCount),
      nextStep: text.queueNextStep,
    };
  }

  if (backlogCount > 0) {
    return { summary: text.queueBacklog(backlogCount) };
  }

  return { summary: text.queueHealthy };
}

export function DashboardOperationsHealth({ locale, enabled }: DashboardOperationsHealthProps) {
  const text = copy[locale];
  const query = useQuery({
    queryKey: adminQueryKeys.operationsStatus,
    queryFn: ({ signal }) => fetchAdminOperationsStatus(signal),
    enabled,
    staleTime: 15_000,
    refetchInterval: 30_000,
  });
  const data = query.data;

  return (
    <section id="operations-health" className={styles.systemStatusSection}>
      <AdminSectionHeader title={text.title} description={text.description} />
      {query.isError && !data ? (
        <AdminStateCard
          tone="warning"
          title={text.unavailable}
          action={
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={query.isFetching}
              onClick={() => void query.refetch()}
            >
              {text.retry}
            </Button>
          }
        />
      ) : data ? (
        <AdminCard
          className={styles.systemStatusCard}
          title={text.title}
          description={new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
            dateStyle: "medium",
            timeStyle: "short",
          }).format(new Date(data.generatedAtUtc))}
          action={
            <AdminBadge tone={tone(data.overallStatus)}>{text[data.overallStatus]}</AdminBadge>
          }
        >
          <ul className={styles.systemStatusGrid} aria-busy={query.isFetching}>
            {(
              [
                {
                  key: "email",
                  label: text.email,
                  status: data.email.status,
                  metrics: `${data.email.backlogCount} ${text.backlog} · ${data.email.deadLetterCount} ${text.deadLetters} · ${text.oldest} ${formatAge(data.email.oldestItemAgeSeconds, locale)}`,
                  ...getQueueExplanation(
                    locale,
                    data.email.backlogCount,
                    data.email.deadLetterCount
                  ),
                },
                {
                  key: "audit",
                  label: text.audit,
                  status: data.auditOutbox.status,
                  metrics: `${data.auditOutbox.backlogCount} ${text.backlog} · ${data.auditOutbox.deadLetterCount} ${text.deadLetters} · ${text.oldest} ${formatAge(data.auditOutbox.oldestItemAgeSeconds, locale)}`,
                  ...getQueueExplanation(
                    locale,
                    data.auditOutbox.backlogCount,
                    data.auditOutbox.deadLetterCount
                  ),
                },
                {
                  key: "push",
                  label: text.push,
                  status: data.pushOutbox.status,
                  metrics: `${data.pushOutbox.backlogCount} ${text.backlog} · ${data.pushOutbox.deadLetterCount} ${text.deadLetters} · ${text.oldest} ${formatAge(data.pushOutbox.oldestItemAgeSeconds, locale)}`,
                  ...getQueueExplanation(
                    locale,
                    data.pushOutbox.backlogCount,
                    data.pushOutbox.deadLetterCount
                  ),
                },
                {
                  key: "generations",
                  label: text.generations,
                  status: data.generations.status,
                  summary:
                    data.generations.queueDepth > 0
                      ? `${data.generations.queueDepth} ${text.queue}.`
                      : locale === "ru"
                        ? "Новых заданий в очереди нет."
                        : "No new jobs are waiting.",
                  metrics: `${data.generations.queueDepth} ${text.queue} · ${text.oldest} ${formatAge(data.generations.oldestQueuedItemAgeSeconds, locale)}`,
                },
                {
                  key: "economy",
                  label: text.economy,
                  status: data.economy.status,
                  summary:
                    data.economy.criticalIncidentCount > 0
                      ? locale === "ru"
                        ? "Есть критичные платёжные инциденты, требующие решения."
                        : "Critical payment incidents require resolution."
                      : locale === "ru"
                        ? "Открытых критичных платёжных инцидентов нет."
                        : "No critical payment incidents are open.",
                  metrics: `${data.economy.openIncidentCount} ${text.open} · ${data.economy.criticalIncidentCount} ${text.critical}`,
                },
                {
                  key: "workers",
                  label: text.workers,
                  status: data.workers.status,
                  summary:
                    data.workers.generationWorkerHeartbeatAgeSeconds === null ||
                    data.workers.generationWorkerHeartbeatAgeSeconds === undefined
                      ? locale === "ru"
                        ? "Worker пока не подтвердил работу."
                        : "The worker has not confirmed activity yet."
                      : locale === "ru"
                        ? "Worker на связи."
                        : "The worker is reporting activity.",
                  metrics:
                    data.workers.generationWorkerHeartbeatAgeSeconds === null ||
                    data.workers.generationWorkerHeartbeatAgeSeconds === undefined
                      ? text.noHeartbeat
                      : `${text.heartbeat} ${formatAge(data.workers.generationWorkerHeartbeatAgeSeconds, locale)}`,
                },
              ] as Array<{
                key: string;
                label: string;
                status: AdminOperationsSourceStatus;
                summary: string;
                metrics: string;
                nextStep?: string;
              }>
            ).map((item) => (
              <li key={item.key} className={styles.systemStatusCheck}>
                <div className={styles.systemStatusCheckHeader}>
                  <strong>{item.label}</strong>
                  <AdminBadge tone={tone(item.status)}>{text[item.status]}</AdminBadge>
                </div>
                <p>{item.summary}</p>
                {item.nextStep ? (
                  <p className={styles.systemStatusNextStep}>{item.nextStep}</p>
                ) : null}
                <span className={styles.systemStatusMetrics}>{item.metrics}</span>
              </li>
            ))}
          </ul>
        </AdminCard>
      ) : (
        <AdminStateCard tone="info" title={text.title} />
      )}
    </section>
  );
}
