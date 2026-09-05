"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo } from "react";

import {
  AdminBadge,
  AdminCard,
  AdminContextBar,
  AdminDataSurface,
  AdminPage,
  AdminStateCard,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import styles from "@/components/operations-problems-page.module.css";
import { Button } from "@/components/ui/button";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminOperationsProblems,
  type AdminOperationsProblemSource,
  useAuthSession,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

type OperationsProblemsPageProps = { locale: Locale };

const sources = [
  "email",
  "audit",
  "push",
] as const satisfies readonly AdminOperationsProblemSource[];

const copy = {
  ru: {
    title: "Проблемы операций",
    description: "Незавершённые и failed записи очередей. Данные обновляются вручную.",
    source: { email: "Доставка email", audit: "Журнал аудита", push: "Доставка push-уведомлений" },
    back: "К операционному здоровью",
    refresh: "Обновить",
    refreshing: "Обновление…",
    empty: "Для выбранной очереди проблемных записей нет.",
    error: "Не удалось загрузить проблемные записи.",
    module: "Модуль",
    kind: "Тип",
    status: "Статус",
    attempts: "Попытки",
    created: "Создана",
    updated: "Обновлена",
    nextAttempt: "Следующая попытка",
    errorCode: "Код ошибки",
    record: "Запись",
  },
  en: {
    title: "Operations problems",
    description: "Unfinished and failed queue records. Refresh manually to get current data.",
    source: { email: "Email delivery", audit: "Audit outbox", push: "Push notification delivery" },
    back: "Back to operations health",
    refresh: "Refresh",
    refreshing: "Refreshing…",
    empty: "There are no problem records for this queue.",
    error: "Could not load problem records.",
    module: "Module",
    kind: "Kind",
    status: "Status",
    attempts: "Attempts",
    created: "Created",
    updated: "Updated",
    nextAttempt: "Next attempt",
    errorCode: "Error code",
    record: "Record",
  },
} as const;

function readSource(value: string | null): AdminOperationsProblemSource {
  return sources.includes(value as AdminOperationsProblemSource)
    ? (value as AdminOperationsProblemSource)
    : "email";
}

function tone(status: string) {
  return status === "Failed" || status === "DeadLetter"
    ? ("danger" as const)
    : ("warning" as const);
}

export function OperationsProblemsPage({ locale }: OperationsProblemsPageProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const session = useAuthSession();
  const canView = session?.user.roles.includes("Admin") ?? false;
  const source = readSource(searchParams.get("source"));
  const text = useMemo(() => copy[locale], [locale]);
  const query = useQuery({
    queryKey: adminQueryKeys.operationsProblems(source),
    queryFn: ({ signal }) => fetchAdminOperationsProblems(source, signal),
    enabled: canView,
    staleTime: 15_000,
  });

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  return (
    <AdminPage className={styles.page}>
      <AdminContextBar
        label={text.source[source]}
        actions={
          <Button
            type="button"
            variant="secondary"
            disabled={!canView || query.isFetching}
            onClick={() => void query.refetch()}
          >
            {query.isFetching ? text.refreshing : text.refresh}
          </Button>
        }
      />
      <AdminCard title={text.title} description={text.description}>
        <Link className={styles.backLink} href={`/${locale}/dashboard#operations-health`}>
          {text.back}
        </Link>
      </AdminCard>
      {query.isError ? (
        <AdminStateCard tone="warning" title={text.error} />
      ) : query.data && query.data.items.length === 0 ? (
        <AdminStateCard tone="success" title={text.empty} />
      ) : query.data ? (
        <AdminDataSurface title={text.source[source]} description={text.description}>
          <div className={adminTableStyles.tableWrap} aria-busy={query.isFetching}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th scope="col">{text.record}</th>
                  <th scope="col">{text.module}</th>
                  <th scope="col">{text.kind}</th>
                  <th scope="col">{text.status}</th>
                  <th scope="col">{text.attempts}</th>
                  <th scope="col">{text.created}</th>
                  <th scope="col">{text.updated}</th>
                  <th scope="col">{text.nextAttempt}</th>
                  <th scope="col">{text.errorCode}</th>
                </tr>
              </thead>
              <tbody>
                {query.data.items.map((item) => (
                  <tr key={`${item.module}:${item.id}`}>
                    <td className={styles.identifier}>{item.id.slice(0, 8)}</td>
                    <td>{item.module}</td>
                    <td>{item.kind}</td>
                    <td>
                      <AdminBadge tone={tone(item.status)}>{item.status}</AdminBadge>
                    </td>
                    <td>{item.attemptCount}</td>
                    <td>{formatDateTime(item.createdAtUtc, locale)}</td>
                    <td>{formatDateTime(item.updatedAtUtc, locale)}</td>
                    <td>{formatDateTime(item.nextAttemptAtUtc, locale)}</td>
                    <td className={styles.identifier}>{item.errorCode ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </AdminDataSurface>
      ) : (
        <AdminStateCard tone="info" title={text.title} />
      )}
    </AdminPage>
  );
}
