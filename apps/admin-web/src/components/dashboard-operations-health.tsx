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
      "Очереди, outbox, генерации и финансовые инциденты без внутренних payload и ошибок.",
    unavailable: "Операционные агрегаты недоступны",
    retry: "Повторить",
    backlog: "в очереди",
    deadLetters: "dead letter",
    oldest: "старейшая",
    email: "Email delivery",
    audit: "Audit outbox",
    push: "Push outbox",
    generations: "Generation queue",
    economy: "Economy incidents",
    workers: "Workers",
    queue: "в очереди",
    open: "открыто",
    critical: "критично",
    heartbeat: "heartbeat",
    noHeartbeat: "нет heartbeat",
    healthy: "Норма",
    degraded: "Внимание",
    unhealthy: "Критично",
    unknown: "Нет данных",
  },
  en: {
    title: "Operations health",
    description:
      "Queues, outboxes, generation, and economy incidents without internal payloads or errors.",
    unavailable: "Operations aggregates are unavailable",
    retry: "Retry",
    backlog: "queued",
    deadLetters: "dead letter",
    oldest: "oldest",
    email: "Email delivery",
    audit: "Audit outbox",
    push: "Push outbox",
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
            {[
              {
                key: "email",
                label: text.email,
                status: data.email.status,
                detail: `${data.email.backlogCount} ${text.backlog} · ${data.email.deadLetterCount} ${text.deadLetters} · ${text.oldest} ${formatAge(data.email.oldestItemAgeSeconds, locale)}`,
              },
              {
                key: "audit",
                label: text.audit,
                status: data.auditOutbox.status,
                detail: `${data.auditOutbox.backlogCount} ${text.backlog} · ${data.auditOutbox.deadLetterCount} ${text.deadLetters} · ${text.oldest} ${formatAge(data.auditOutbox.oldestItemAgeSeconds, locale)}`,
              },
              {
                key: "push",
                label: text.push,
                status: data.pushOutbox.status,
                detail: `${data.pushOutbox.backlogCount} ${text.backlog} · ${data.pushOutbox.deadLetterCount} ${text.deadLetters} · ${text.oldest} ${formatAge(data.pushOutbox.oldestItemAgeSeconds, locale)}`,
              },
              {
                key: "generations",
                label: text.generations,
                status: data.generations.status,
                detail: `${data.generations.queueDepth} ${text.queue} · ${text.oldest} ${formatAge(data.generations.oldestQueuedItemAgeSeconds, locale)}`,
              },
              {
                key: "economy",
                label: text.economy,
                status: data.economy.status,
                detail: `${data.economy.openIncidentCount} ${text.open} · ${data.economy.criticalIncidentCount} ${text.critical}`,
              },
              {
                key: "workers",
                label: text.workers,
                status: data.workers.status,
                detail:
                  data.workers.generationWorkerHeartbeatAgeSeconds === null ||
                  data.workers.generationWorkerHeartbeatAgeSeconds === undefined
                    ? text.noHeartbeat
                    : `${text.heartbeat} ${formatAge(data.workers.generationWorkerHeartbeatAgeSeconds, locale)}`,
              },
            ].map((item) => (
              <li key={item.key} className={styles.systemStatusCheck}>
                <div className={styles.systemStatusCheckHeader}>
                  <strong>{item.label}</strong>
                  <AdminBadge tone={tone(item.status)}>{text[item.status]}</AdminBadge>
                </div>
                <p>{item.detail}</p>
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
