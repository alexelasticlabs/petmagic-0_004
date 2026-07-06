"use client";

import { useMemo, useState } from "react";

import {
  AdminCard,
  AdminSelectField,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import {
  incidentActionOptions,
  incidentCategoryOptions,
  incidentStatusOptions,
  type EconomyPageText,
} from "@/components/economy-page.content";
import styles from "@/components/economy-page.module.css";
import {
  humanizeTokenKind,
  safeText,
  shortGuid,
  statusColor,
} from "@/components/economy-page.shared";
import { Button } from "@/components/ui/button";
import {
  ECONOMY_QUERY_FILTER_MAX_LENGTH,
  ECONOMY_INCIDENT_REASON_MAX_LENGTH,
  type AdminEconomyIncident,
  type AdminEconomyIncidentDetail,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

type EconomyPageIncidentsSectionProps = {
  locale: Locale;
  text: EconomyPageText;
  selectedIncidentId: string | null;
  selectedIncidentDetail: AdminEconomyIncidentDetail | null;
  selectedIncidentLoading: boolean;
  incidentItems: AdminEconomyIncident[];
  incidentCategory: string;
  incidentStatus: string;
  incidentType: string;
  incidentPage: number;
  incidentsHasMore: boolean;
  incidentsIsFetching: boolean;
  incidentsIsRefreshing: boolean;
  runReconciliationPending: boolean;
  actionPending: boolean;
  setIncidentCategory: (value: string) => void;
  setIncidentStatus: (value: string) => void;
  setIncidentType: (value: string) => void;
  setIncidentPage: (value: number | ((current: number) => number)) => void;
  onSelectIncident: (incident: AdminEconomyIncident) => void;
  onRunReconciliation: () => void;
  onResolveIncident: (incident: AdminEconomyIncident) => void;
  onApplyIncidentAction: (payload: {
    incidentId: string;
    action: string;
    reason: string;
    amount?: number;
    externalReferenceId?: string;
  }) => void;
};

export function EconomyPageIncidentsSection({
  locale,
  text,
  selectedIncidentId,
  selectedIncidentDetail,
  selectedIncidentLoading,
  incidentItems,
  incidentCategory,
  incidentStatus,
  incidentType,
  incidentPage,
  incidentsHasMore,
  incidentsIsFetching,
  incidentsIsRefreshing,
  runReconciliationPending,
  actionPending,
  setIncidentCategory,
  setIncidentStatus,
  setIncidentType,
  setIncidentPage,
  onSelectIncident,
  onRunReconciliation,
  onResolveIncident,
  onApplyIncidentAction,
}: EconomyPageIncidentsSectionProps) {
  const [action, setAction] = useState("retry_settlement");
  const [reason, setReason] = useState("");
  const [amount, setAmount] = useState("");
  const [externalReferenceId, setExternalReferenceId] = useState("");
  const selectedIncident = selectedIncidentDetail?.incident ?? null;
  const actionOptions = useMemo(() => incidentActionOptions[locale], [locale]);

  const submitAction = () => {
    if (!selectedIncident || !reason.trim()) {
      return;
    }

    const parsedAmount = Number.parseInt(amount.trim(), 10);
    onApplyIncidentAction({
      incidentId: selectedIncident.incidentId,
      action,
      reason,
      amount: Number.isFinite(parsedAmount) ? parsedAmount : undefined,
      externalReferenceId: externalReferenceId.trim() || undefined,
    });
  };

  return (
    <AdminCard
      title={text.incidentsTitle}
      description={text.incidentsDescription}
      action={
        <div className={styles.filterRow}>
          <AdminSelectField
            label={text.incidentStatusFilterLabel}
            value={incidentStatus}
            onChange={setIncidentStatus}
            options={incidentStatusOptions[locale]}
            className={styles.compactSelect}
            disabled={incidentsIsFetching || incidentsIsRefreshing}
          />
          <AdminSelectField
            label={text.incidentCategoryFilterLabel}
            value={incidentCategory}
            onChange={setIncidentCategory}
            options={incidentCategoryOptions[locale]}
            className={styles.compactSelect}
            disabled={incidentsIsFetching || incidentsIsRefreshing}
          />
          <label className={styles.filterField}>
            <span>{text.incidentTypeFilterLabel}</span>
            <input
              className={styles.input}
              disabled={incidentsIsFetching || incidentsIsRefreshing}
              value={incidentType}
              onChange={(event) =>
                setIncidentType(event.target.value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH))
              }
              maxLength={ECONOMY_QUERY_FILTER_MAX_LENGTH}
              placeholder={text.incidentTypePlaceholder}
            />
          </label>
          <Button
            type="button"
            variant="secondary"
            disabled={runReconciliationPending}
            onClick={onRunReconciliation}
          >
            {text.runReconciliationAction}
          </Button>
        </div>
      }
    >
      {incidentsIsRefreshing ? (
        <AdminStateCard tone="info" title={text.loadingTitle} />
      ) : incidentItems.length === 0 ? (
        <AdminStateCard tone="info" title={text.noIncidents} />
      ) : (
        <>
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.timeColumn}</th>
                  <th>{text.incidentColumn}</th>
                  <th>{text.categoryColumn}</th>
                  <th>{text.severityColumn}</th>
                  <th>{text.providerColumn}</th>
                  <th>{text.userColumn}</th>
                  <th>{text.retryColumn}</th>
                  <th>{text.statusColumn}</th>
                  <th>{text.actionsColumn}</th>
                </tr>
              </thead>
              <tbody>
                {incidentItems.map((item) => (
                  <tr key={item.incidentId}>
                    <td>{formatDateTime(item.lastDetectedAtUtc, locale)}</td>
                    <td>
                      <div className={styles.packMeta}>
                        <strong>{safeText(item.type, 80)}</strong>
                        <span>{safeText(item.summary, 180)}</span>
                        {item.lastError ? <span>{safeText(item.lastError, 96)}</span> : null}
                      </div>
                    </td>
                    <td>{safeText(item.category, 64)}</td>
                    <td>
                      <AdminStatusBadge color={severityColor(item.severity)}>
                        {safeText(item.severity, 32)}
                      </AdminStatusBadge>
                    </td>
                    <td>{safeText(item.provider ?? "-")}</td>
                    <td className={adminTableStyles.mono}>
                      {item.userId ? shortGuid(item.userId) : "-"}
                    </td>
                    <td>
                      <div className={styles.packMeta}>
                        <strong>{String(item.retryCount)}</strong>
                        <span>
                          {item.nextRetryAtUtc ? formatDateTime(item.nextRetryAtUtc, locale) : "-"}
                        </span>
                      </div>
                    </td>
                    <td>
                      <AdminStatusBadge color={statusColor(item.status)}>
                        {safeText(item.status, 32)}
                      </AdminStatusBadge>
                    </td>
                    <td>
                      {item.status.toLowerCase() === "open" ? (
                        <Button
                          type="button"
                          size="sm"
                          variant="secondary"
                          disabled={actionPending}
                          onClick={() => onResolveIncident(item)}
                        >
                          {text.resolveIncidentAction}
                        </Button>
                      ) : (
                        <span className={styles.mutedText}>{safeText(item.status, 32)}</span>
                      )}
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        disabled={selectedIncidentId === item.incidentId}
                        onClick={() => onSelectIncident(item)}
                      >
                        {text.viewIncidentAction}
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className={styles.sectionStack}>
            {!selectedIncidentId ? (
              <AdminStateCard tone="info" title={text.incidentNoDetail} />
            ) : selectedIncidentLoading && !selectedIncidentDetail ? (
              <AdminStateCard tone="info" title={text.loadingTitle} />
            ) : selectedIncidentDetail ? (
              <div className={styles.packMeta}>
                <h3>{text.incidentDetailTitle}</h3>
                <div className={styles.filterRow}>
                  <span className={adminTableStyles.mono}>
                    {shortGuid(selectedIncidentDetail.incident.incidentId)}
                  </span>
                  <AdminStatusBadge color={statusColor(selectedIncidentDetail.incident.status)}>
                    {safeText(selectedIncidentDetail.incident.status, 32)}
                  </AdminStatusBadge>
                  <AdminStatusBadge color={severityColor(selectedIncidentDetail.incident.severity)}>
                    {safeText(selectedIncidentDetail.incident.severity, 32)}
                  </AdminStatusBadge>
                </div>
                <div className={styles.filterRow}>
                  <AdminSelectField
                    label={text.incidentActionLabel}
                    value={action}
                    onChange={setAction}
                    options={actionOptions}
                    className={styles.compactSelect}
                    disabled={actionPending}
                  />
                  <label className={styles.filterField}>
                    <span>{text.incidentReasonLabel}</span>
                    <input
                      className={styles.input}
                      value={reason}
                      disabled={actionPending}
                      maxLength={ECONOMY_INCIDENT_REASON_MAX_LENGTH}
                      onChange={(event) => setReason(event.target.value)}
                    />
                  </label>
                  <label className={styles.filterField}>
                    <span>{text.incidentAmountLabel}</span>
                    <input
                      className={styles.input}
                      value={amount}
                      disabled={actionPending}
                      onChange={(event) => setAmount(event.target.value.replace(/[^\d-]/g, ""))}
                    />
                  </label>
                  <label className={styles.filterField}>
                    <span>{text.incidentExternalReferenceLabel}</span>
                    <input
                      className={styles.input}
                      value={externalReferenceId}
                      disabled={actionPending}
                      maxLength={ECONOMY_QUERY_FILTER_MAX_LENGTH}
                      onChange={(event) => setExternalReferenceId(event.target.value)}
                    />
                  </label>
                  <Button
                    type="button"
                    variant="secondary"
                    disabled={actionPending || !reason.trim()}
                    onClick={submitAction}
                  >
                    {text.incidentActionSubmit}
                  </Button>
                </div>
                {!reason.trim() ? (
                  <span className={styles.mutedText}>{text.incidentReasonRequired}</span>
                ) : null}
                <IncidentLinks detail={selectedIncidentDetail} text={text} locale={locale} />
              </div>
            ) : null}
          </div>
          <div className={styles.pager}>
            <button
              type="button"
              className={styles.pagerButton}
              disabled={incidentPage === 0 || incidentsIsFetching}
              onClick={() => setIncidentPage((current) => Math.max(0, current - 1))}
            >
              {text.previousPage}
            </button>
            <button
              type="button"
              className={styles.pagerButton}
              disabled={!incidentsHasMore || incidentsIsFetching}
              onClick={() => setIncidentPage((current) => current + 1)}
            >
              {text.nextPage}
            </button>
          </div>
        </>
      )}
    </AdminCard>
  );
}

function severityColor(value: string) {
  return value.toLowerCase() === "critical" ? "var(--danger)" : "var(--warning)";
}

function IncidentLinks({
  detail,
  text,
  locale,
}: {
  detail: AdminEconomyIncidentDetail;
  text: EconomyPageText;
  locale: Locale;
}) {
  return (
    <>
      <h4>{text.incidentLinksTitle}</h4>
      <div className={styles.filterRow}>
        <span>
          {text.userColumn}:{" "}
          <strong>{detail.incident.userId ? shortGuid(detail.incident.userId) : "-"}</strong>
        </span>
        <span>
          {text.providerColumn}: <strong>{safeText(detail.incident.provider ?? "-")}</strong>
        </span>
        <span>
          {text.purchaseFilterLabel}:{" "}
          <strong>{detail.purchaseOrder ? shortGuid(detail.purchaseOrder.orderId) : "-"}</strong>
        </span>
        <span>
          {text.subscriptionEventsTitle}:{" "}
          <strong>
            {detail.subscription ? shortGuid(detail.subscription.subscriptionId) : "-"}
          </strong>
        </span>
        <span>
          {text.incidentWalletTitle}:{" "}
          <strong>{detail.wallet ? String(detail.wallet.balance) : "-"}</strong>
        </span>
        <span>
          {text.incidentGenerationTitle}:{" "}
          <strong>
            {detail.generation
              ? `${shortGuid(detail.generation.generationId)} / ${safeText(detail.generation.status, 32)}`
              : "-"}
          </strong>
        </span>
        {detail.generation ? (
          <span>
            {text.tokensShort}: <strong>{detail.generation.tokenCost}</strong> ·{" "}
            {text.incidentChargedLabel}:{" "}
            <strong>
              {detail.generation.chargedAtUtc
                ? formatDateTime(detail.generation.chargedAtUtc, locale)
                : "-"}
            </strong>{" "}
            · {text.incidentRefundedLabel}:{" "}
            <strong>
              {detail.generation.refundedAtUtc
                ? formatDateTime(detail.generation.refundedAtUtc, locale)
                : "-"}
            </strong>
          </span>
        ) : null}
      </div>
      <h4>{text.incidentLedgerTitle}</h4>
      {detail.ledgerEntries.length === 0 ? (
        <span className={styles.mutedText}>{text.noLedger}</span>
      ) : (
        <div className={adminTableStyles.tableWrap}>
          <table className={adminTableStyles.table}>
            <thead>
              <tr>
                <th>{text.timeColumn}</th>
                <th>{text.sourceColumn}</th>
                <th>{text.tokenKindColumn}</th>
                <th>{text.deltaColumn}</th>
                <th>{text.balanceColumn}</th>
                <th>{text.reasonColumn}</th>
              </tr>
            </thead>
            <tbody>
              {detail.ledgerEntries.map((item) => (
                <tr key={item.entryId}>
                  <td>{formatDateTime(item.createdAtUtc, locale)}</td>
                  <td>{safeText(item.source, 64)}</td>
                  <td>{humanizeTokenKind(item.tokenKind, locale, text.tokenKindLegacyLabel)}</td>
                  <td>{item.delta}</td>
                  <td>{item.balanceAfter}</td>
                  <td>{safeText(item.reason, 160)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <h4>{text.incidentWebhookTitle}</h4>
      {detail.webhookEvents.length === 0 ? (
        <span className={styles.mutedText}>{text.noSubscriptionEvents}</span>
      ) : (
        detail.webhookEvents.map((event) => (
          <div className={styles.packMeta} key={event.eventId}>
            <strong>
              {safeText(event.provider, 32)} / {safeText(event.eventType, 80)}
            </strong>
            <span>
              {safeText(event.status, 32)} ·{" "}
              {event.externalEventId ? safeText(event.externalEventId, 120) : "-"} ·{" "}
              {formatDateTime(event.createdAtUtc, locale)}
            </span>
            {event.payloadSnapshotJson ? (
              <code>
                {text.incidentSafePayloadLabel}: {safeText(event.payloadSnapshotJson, 500)}
              </code>
            ) : null}
          </div>
        ))
      )}
      <h4>{text.incidentAuditTitle}</h4>
      {detail.auditTrail.length === 0 ? (
        <span className={styles.mutedText}>{text.incidentNoAudit}</span>
      ) : (
        detail.auditTrail.map((entry) => (
          <div className={styles.packMeta} key={entry.auditEntryId}>
            <strong>{safeText(entry.action, 80)}</strong>
            <span>{safeText(entry.reason, 200)}</span>
            <span>{formatDateTime(entry.createdAtUtc, locale)}</span>
          </div>
        ))
      )}
    </>
  );
}
