"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";

import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminMetricStrip,
  AdminStateCard,
  AdminStatusBadge,
} from "@/components/admin/admin-primitives";
import { AdminInspector, AdminQueueLayout } from "@/components/admin/admin-queue-layout";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { Toast } from "@/components/ui/toast";
import styles from "@/components/users-email-broadcasts-workspace.module.css";
import { getUsersEmailBroadcastsText } from "@/components/users-email-broadcasts.content";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { readAdminUrlState, updateAdminUrlState } from "@/lib/admin-url-state";
import {
  fetchAdminEmailBroadcast,
  fetchAdminEmailBroadcasts,
  retryFailedAdminEmailBroadcast,
  type AdminEmailBroadcastDetail,
  type AdminEmailBroadcastListItem,
  type AdminEmailBroadcastStatus,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import type { Locale } from "@/lib/i18n";
import { sanitizeSensitiveText, shortIdentifier } from "@/lib/sensitive-display";

const PAGE_SIZE = 10;
const broadcastIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type BroadcastStatusFilter = AdminEmailBroadcastStatus | "all";

function readPositiveInteger(value: string | undefined) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : 1;
}

function normalizeStatus(value: string | undefined): BroadcastStatusFilter {
  return value === "legacy" ||
    value === "queued" ||
    value === "processing" ||
    value === "completed" ||
    value === "partially-failed" ||
    value === "failed"
    ? value
    : "all";
}

function isTerminalStatus(status: AdminEmailBroadcastStatus) {
  return status === "completed" || status === "partially-failed" || status === "failed";
}

function statusColor(status: AdminEmailBroadcastStatus) {
  if (status === "completed") return "var(--success)";
  if (status === "partially-failed" || status === "failed") return "var(--danger)";
  if (status === "processing") return "var(--primary)";
  return "var(--warning)";
}

function progressPercent(
  value: Pick<AdminEmailBroadcastListItem, "recipientCount" | "sentCount" | "failedCount">
) {
  if (value.recipientCount <= 0) return 0;
  return Math.min(
    100,
    Math.round(((value.sentCount + value.failedCount) / value.recipientCount) * 100)
  );
}

export function UsersEmailBroadcastsWorkspace({ locale }: { locale: Locale }) {
  const copy = getUsersEmailBroadcastsText(locale);
  const pathname = usePathname();
  const router = useRouter();
  const searchParams = useSearchParams();
  const queryClient = useQueryClient();
  const [retryConfirmationOpen, setRetryConfirmationOpen] = useState(false);
  const [toast, setToast] = useState<{ type: "success" | "error"; message: string } | null>(null);

  const urlState = readAdminUrlState(searchParams, {
    filterKeys: ["broadcastPage", "broadcastStatus"],
  });
  const page = readPositiveInteger(urlState.filters.broadcastPage);
  const status = normalizeStatus(urlState.filters.broadcastStatus);
  const selectedBroadcastId =
    urlState.selected && broadcastIdPattern.test(urlState.selected) ? urlState.selected : null;
  const query = {
    skip: (page - 1) * PAGE_SIZE,
    take: PAGE_SIZE,
    status,
  } as const;

  function replaceUrl(patch: Parameters<typeof updateAdminUrlState>[1]) {
    const next = updateAdminUrlState(searchParams, patch, { resetPageOnQueryChange: false });
    const queryString = next.toString();
    router.replace(queryString ? `${pathname}?${queryString}` : pathname, { scroll: false });
  }

  const broadcastsQuery = useQuery({
    queryKey: adminQueryKeys.emailBroadcasts(query),
    queryFn: ({ signal }) => fetchAdminEmailBroadcasts(query, signal),
    placeholderData: keepPreviousData,
    refetchInterval: (currentQuery) =>
      currentQuery.state.data?.items.some((item) => !isTerminalStatus(item.status))
        ? 10_000
        : false,
  });

  const detailQuery = useQuery({
    queryKey: selectedBroadcastId
      ? adminQueryKeys.emailBroadcast(selectedBroadcastId)
      : adminQueryKeys.emailBroadcast("disabled"),
    queryFn: ({ signal }) => fetchAdminEmailBroadcast(selectedBroadcastId!, signal),
    enabled: Boolean(selectedBroadcastId),
    refetchInterval: (currentQuery) => {
      const detail = currentQuery.state.data;
      return detail && !isTerminalStatus(detail.status) ? 5_000 : false;
    },
  });

  const retryMutation = useMutation({
    mutationFn: () => retryFailedAdminEmailBroadcast(selectedBroadcastId!),
    onSuccess: async (result) => {
      setRetryConfirmationOpen(false);
      setToast({ type: "success", message: copy.retrySucceeded(result.retriedCount) });
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.emailBroadcastsRoot }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.emailBroadcast(result.broadcastId),
        }),
      ]);
    },
    onError: async (error) => {
      setRetryConfirmationOpen(false);
      setToast({ type: "error", message: getAdminErrorMessage(error, copy.retryError) });
      if (selectedBroadcastId) {
        await queryClient.invalidateQueries({
          queryKey: adminQueryKeys.emailBroadcast(selectedBroadcastId),
        });
      }
    },
  });

  const items = broadcastsQuery.data?.items ?? [];
  const totalPages = Math.max(1, Math.ceil((broadcastsQuery.data?.totalCount ?? 0) / PAGE_SIZE));
  const totals = items.reduce(
    (aggregate, item) => ({
      recipients: aggregate.recipients + item.recipientCount,
      sent: aggregate.sent + item.sentCount,
      failed: aggregate.failed + item.failedCount,
    }),
    { recipients: 0, sent: 0, failed: 0 }
  );

  function statusLabel(value: AdminEmailBroadcastStatus) {
    if (value === "queued") return copy.statusQueued;
    if (value === "processing") return copy.statusProcessing;
    if (value === "completed") return copy.statusCompleted;
    if (value === "partially-failed") return copy.statusPartiallyFailed;
    if (value === "failed") return copy.statusFailed;
    return copy.statusLegacy;
  }

  function audienceLabel(value: string) {
    if (value === "all-active") return copy.audienceAllActive;
    if (value === "premium") return copy.audiencePremium;
    if (value === "selected") return copy.audienceSelected;
    return sanitizeSensitiveText(value, 48);
  }

  function renderInspector(detail: AdminEmailBroadcastDetail) {
    const progress = progressPercent(detail);
    const retryableCount = Math.max(0, detail.retryableFailedCount);
    return (
      <AdminInspector
        title={sanitizeSensitiveText(detail.subject, 120) || copy.subjectUnavailable}
        description={`${shortIdentifier(detail.broadcastId)} · ${statusLabel(detail.status)}`}
        closeLabel={copy.closeInspector}
        onClose={() => replaceUrl({ selected: null })}
        footer={
          retryableCount > 0 ? (
            <Button
              type="button"
              variant="danger"
              size="sm"
              disabled={retryMutation.isPending}
              onClick={() => setRetryConfirmationOpen(true)}
            >
              {copy.retryFailed} ({retryableCount})
            </Button>
          ) : (
            <span className={styles.inspectorMeta}>{copy.noRetryable}</span>
          )
        }
      >
        <div className={styles.progressMeta}>
          <span>{copy.progress}</span>
          <strong>{progress}%</strong>
        </div>
        <div
          className={styles.progress}
          role="progressbar"
          aria-label={copy.progress}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={progress}
        >
          <span style={{ width: `${progress}%` }} />
        </div>
        <dl className={styles.facts}>
          <div>
            <dt>{copy.audience}</dt>
            <dd>{audienceLabel(detail.audience)}</dd>
          </div>
          <div>
            <dt>{copy.recipients}</dt>
            <dd>{detail.recipientCount.toLocaleString(locale)}</dd>
          </div>
          <div>
            <dt>{copy.sent}</dt>
            <dd>{detail.sentCount.toLocaleString(locale)}</dd>
          </div>
          <div>
            <dt>{copy.pending}</dt>
            <dd>{detail.pendingCount.toLocaleString(locale)}</dd>
          </div>
          <div>
            <dt>{copy.failed}</dt>
            <dd>{detail.failedCount.toLocaleString(locale)}</dd>
          </div>
          <div>
            <dt>{copy.retryable}</dt>
            <dd>{retryableCount.toLocaleString(locale)}</dd>
          </div>
          <div>
            <dt>{copy.created}</dt>
            <dd>{formatDateTime(detail.createdAtUtc, locale)}</dd>
          </div>
          <div>
            <dt>{copy.updated}</dt>
            <dd>{formatDateTime(detail.updatedAtUtc, locale)}</dd>
          </div>
          {detail.completedAtUtc ? (
            <div>
              <dt>{copy.completed}</dt>
              <dd>{formatDateTime(detail.completedAtUtc, locale)}</dd>
            </div>
          ) : null}
        </dl>
        <p className={styles.safeNote}>{copy.safeDataDescription}</p>
      </AdminInspector>
    );
  }

  const inspector = selectedBroadcastId ? (
    detailQuery.isLoading ? (
      <AdminInspector
        title={copy.inspectorLabel}
        closeLabel={copy.closeInspector}
        onClose={() => replaceUrl({ selected: null })}
      >
        <AdminStateCard className={styles.inspectorState} title={copy.loading} />
      </AdminInspector>
    ) : detailQuery.isError || !detailQuery.data ? (
      <AdminInspector
        title={copy.inspectorLabel}
        closeLabel={copy.closeInspector}
        onClose={() => replaceUrl({ selected: null })}
      >
        <AdminStateCard
          className={styles.inspectorState}
          tone="danger"
          title={copy.loadFailed}
          action={
            <Button size="sm" onClick={() => void detailQuery.refetch()}>
              {copy.retryLoad}
            </Button>
          }
        />
      </AdminInspector>
    ) : (
      renderInspector(detailQuery.data)
    )
  ) : undefined;

  return (
    <section className={styles.section} aria-labelledby="email-broadcasts-title">
      <div className={styles.sectionHeader}>
        <div>
          <h2 id="email-broadcasts-title">{copy.title}</h2>
          <p>{copy.description}</p>
        </div>
        <div className={styles.filter}>
          <Select
            value={status}
            ariaLabel={copy.statusFilter}
            showSelectedDescription={false}
            options={[
              { value: "all", label: copy.statusAll },
              { value: "queued", label: copy.statusQueued },
              { value: "processing", label: copy.statusProcessing },
              { value: "completed", label: copy.statusCompleted },
              { value: "partially-failed", label: copy.statusPartiallyFailed },
              { value: "failed", label: copy.statusFailed },
              { value: "legacy", label: copy.statusLegacy },
            ]}
            onChange={(nextStatus) =>
              replaceUrl({
                filters: {
                  broadcastStatus: nextStatus === "all" ? null : nextStatus,
                  broadcastPage: null,
                },
                selected: null,
                tab: "broadcasts",
              })
            }
          />
        </div>
      </div>

      <AdminQueueLayout
        queueLabel={copy.queueLabel}
        workspaceLabel={copy.workspaceLabel}
        inspector={inspector}
        queue={
          <div className={styles.queue}>
            {broadcastsQuery.isLoading ? (
              <AdminStateCard className={styles.queueState} title={copy.loading} />
            ) : broadcastsQuery.isError ? (
              <AdminStateCard
                className={styles.queueState}
                tone="danger"
                title={copy.loadFailed}
                action={
                  <Button size="sm" onClick={() => void broadcastsQuery.refetch()}>
                    {copy.retryLoad}
                  </Button>
                }
              />
            ) : items.length === 0 ? (
              <AdminStateCard className={styles.queueState} title={copy.empty} />
            ) : (
              <ul className={styles.queueList} aria-busy={broadcastsQuery.isFetching || undefined}>
                {items.map((item) => (
                  <li key={item.broadcastId}>
                    <button
                      type="button"
                      className={styles.queueItem}
                      data-selected={selectedBroadcastId === item.broadcastId ? "true" : "false"}
                      aria-label={`${copy.openBroadcast}: ${sanitizeSensitiveText(item.subject, 120) || shortIdentifier(item.broadcastId)}`}
                      aria-pressed={selectedBroadcastId === item.broadcastId}
                      onClick={() => replaceUrl({ selected: item.broadcastId, tab: "broadcasts" })}
                    >
                      <span className={styles.queueItemHeader}>
                        <span className={styles.queueItemTitle}>
                          {sanitizeSensitiveText(item.subject, 120) || copy.subjectUnavailable}
                        </span>
                        <AdminStatusBadge color={statusColor(item.status)}>
                          {statusLabel(item.status)}
                        </AdminStatusBadge>
                      </span>
                      <span className={styles.queueItemMeta}>
                        <span>{audienceLabel(item.audience)}</span>
                        <span>{progressPercent(item)}%</span>
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
            <div className={styles.queueFooter}>
              <AdminPagination
                page={page}
                totalPages={totalPages}
                disabled={broadcastsQuery.isFetching}
                labels={{
                  navigation: copy.pagination,
                  previous: copy.previous,
                  next: copy.next,
                  page: copy.page,
                }}
                onPageChange={(nextPage) =>
                  replaceUrl({
                    filters: { broadcastPage: nextPage > 1 ? String(nextPage) : null },
                    selected: null,
                    tab: "broadcasts",
                  })
                }
              />
            </div>
          </div>
        }
      >
        <div className={styles.workspace}>
          <h3>{copy.safeDataTitle}</h3>
          <p>{copy.safeDataDescription}</p>
          <AdminMetricStrip
            className={styles.metrics}
            items={[
              { label: copy.recipients, value: totals.recipients.toLocaleString(locale) },
              { label: copy.sent, value: totals.sent.toLocaleString(locale) },
              { label: copy.failed, value: totals.failed.toLocaleString(locale) },
            ]}
          />
          <p className={styles.safeNote}>{copy.selectionHint}</p>
        </div>
      </AdminQueueLayout>

      <ConfirmationDialog
        open={retryConfirmationOpen && Boolean(detailQuery.data)}
        title={copy.retryTitle}
        description={copy.retryDescription(detailQuery.data?.retryableFailedCount ?? 0)}
        confirmLabel={copy.retryConfirm}
        cancelLabel={copy.retryCancel}
        tone="danger"
        isSubmitting={retryMutation.isPending}
        confirmDisabled={!detailQuery.data?.retryableFailedCount}
        onCancel={() => {
          if (!retryMutation.isPending) setRetryConfirmationOpen(false);
        }}
        onConfirm={() => retryMutation.mutate()}
      />

      {toast ? <Toast type={toast.type} message={toast.message} /> : null}
    </section>
  );
}
