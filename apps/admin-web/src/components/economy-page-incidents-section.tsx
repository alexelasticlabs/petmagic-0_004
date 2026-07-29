"use client";

import { useMemo, useState } from "react";

import {
  AdminDataSurface,
  AdminFilterBar,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { EconomySelectField } from "@/components/economy-page-select-field";
import {
  incidentActionOptions,
  incidentCategoryOptions,
  incidentStatusOptions,
  type EconomyPageText,
} from "@/components/economy-page.content";
import styles from "@/components/economy-page.module.css";
import {
  humanizeStatus,
  humanizeTokenKind,
  safeText,
  shortGuid,
  statusColor,
} from "@/components/economy-page.shared";
import { Button } from "@/components/ui/button";
import {
  ECONOMY_INCIDENT_EXTERNAL_REFERENCE_MAX_LENGTH,
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
  selectedIncidentError: string | null;
  incidentItems: AdminEconomyIncident[];
  incidentCategory: string;
  incidentStatus: string;
  incidentType: string;
  incidentPage: number;
  incidentsHasMore: boolean;
  incidentsIsFetching: boolean;
  runReconciliationPending: boolean;
  actionPending: boolean;
  setIncidentCategory: (value: string) => void;
  setIncidentStatus: (value: string) => void;
  setIncidentType: (value: string) => void;
  setIncidentPage: (value: number | ((current: number) => number)) => void;
  onSelectIncident: (incident: AdminEconomyIncident) => void;
  onRetrySelectedIncident: () => void;
  onRunReconciliation: () => void;
  onResolveIncident: (incident: AdminEconomyIncident) => Promise<boolean>;
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
  selectedIncidentError,
  incidentItems,
  incidentCategory,
  incidentStatus,
  incidentType,
  incidentPage,
  incidentsHasMore,
  incidentsIsFetching,
  runReconciliationPending,
  actionPending,
  setIncidentCategory,
  setIncidentStatus,
  setIncidentType,
  setIncidentPage,
  onSelectIncident,
  onRetrySelectedIncident,
  onRunReconciliation,
  onResolveIncident,
  onApplyIncidentAction,
}: EconomyPageIncidentsSectionProps) {
  const [incidentPendingResolve, setIncidentPendingResolve] = useState<AdminEconomyIncident | null>(
    null
  );

  return (
    <>
      <AdminDataSurface title={text.incidentsTitle} description={text.incidentsDescription}>
        <AdminFilterBar className={styles.tableFilterBar}>
          <EconomySelectField
            label={text.incidentStatusFilterLabel}
            value={incidentStatus}
            onChange={setIncidentStatus}
            options={incidentStatusOptions[locale]}
            className={styles.compactSelect}
            disabled={incidentsIsFetching && incidentItems.length === 0}
          />
          <EconomySelectField
            label={text.incidentCategoryFilterLabel}
            value={incidentCategory}
            onChange={setIncidentCategory}
            options={incidentCategoryOptions[locale]}
            className={styles.compactSelect}
            disabled={incidentsIsFetching && incidentItems.length === 0}
          />
          <label className={styles.filterField}>
            <span>{text.incidentTypeFilterLabel}</span>
            <input
              className={styles.input}
              disabled={incidentsIsFetching && incidentItems.length === 0}
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
        </AdminFilterBar>
        {incidentsIsFetching && incidentItems.length === 0 ? (
          <AdminStateCard tone="info" title={text.loadingTitle} />
        ) : incidentItems.length === 0 ? (
          <AdminStateCard tone="info" title={text.noIncidents} />
        ) : (
          <>
            <div className={styles.economyDesktopTable}>
              <div className={adminTableStyles.tableWrap} aria-busy={incidentsIsFetching}>
                <table className={`${adminTableStyles.table} ${styles.wideTable}`}>
                  <thead>
                    <tr>
                      <th scope="col">{text.timeColumn}</th>
                      <th scope="col">{text.incidentColumn}</th>
                      <th scope="col">{text.categoryColumn}</th>
                      <th scope="col">{text.severityColumn}</th>
                      <th scope="col">{text.providerColumn}</th>
                      <th scope="col">{text.userColumn}</th>
                      <th scope="col">{text.retryColumn}</th>
                      <th scope="col">{text.statusColumn}</th>
                      <th scope="col">{text.actionsColumn}</th>
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
                              {item.nextRetryAtUtc
                                ? formatDateTime(item.nextRetryAtUtc, locale)
                                : "-"}
                            </span>
                          </div>
                        </td>
                        <td>
                          <AdminStatusBadge color={statusColor(item.status)}>
                            {humanizeStatus(item.status, locale)}
                          </AdminStatusBadge>
                        </td>
                        <td>
                          <IncidentRowActions
                            item={item}
                            locale={locale}
                            text={text}
                            actionPending={actionPending}
                            selectedIncidentId={selectedIncidentId}
                            selectedIncidentError={selectedIncidentError}
                            onResolve={() => setIncidentPendingResolve(item)}
                            onRetrySelectedIncident={onRetrySelectedIncident}
                            onSelectIncident={() => onSelectIncident(item)}
                          />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
            <ul
              className={styles.economyMobileList}
              aria-label={text.incidentsTitle}
              aria-busy={incidentsIsFetching}
            >
              {incidentItems.map((item) => (
                <li key={item.incidentId}>
                  <article
                    className={styles.economyMobileCard}
                    data-severity={item.severity.toLowerCase()}
                  >
                    <div className={styles.economyMobileCardHeader}>
                      <div className={styles.economyMobileIdentity}>
                        <strong>{safeText(item.type, 80)}</strong>
                        <span>{safeText(item.summary, 180)}</span>
                      </div>
                      <div className={styles.economyMobileBadges}>
                        <AdminStatusBadge color={severityColor(item.severity)}>
                          {safeText(item.severity, 32)}
                        </AdminStatusBadge>
                        <AdminStatusBadge color={statusColor(item.status)}>
                          {humanizeStatus(item.status, locale)}
                        </AdminStatusBadge>
                      </div>
                    </div>
                    <dl className={styles.economyMobileFacts}>
                      <div>
                        <dt>{text.categoryColumn}</dt>
                        <dd>{safeText(item.category, 64)}</dd>
                      </div>
                      <div>
                        <dt>{text.providerColumn}</dt>
                        <dd>{safeText(item.provider ?? "-")}</dd>
                      </div>
                      <div>
                        <dt>{text.userColumn}</dt>
                        <dd className={adminTableStyles.mono}>
                          {item.userId ? shortGuid(item.userId) : "-"}
                        </dd>
                      </div>
                      <div>
                        <dt>{text.retryColumn}</dt>
                        <dd>
                          {item.nextRetryAtUtc
                            ? `${item.retryCount} · ${formatDateTime(item.nextRetryAtUtc, locale)}`
                            : String(item.retryCount)}
                        </dd>
                      </div>
                      <div>
                        <dt>{text.timeColumn}</dt>
                        <dd>{formatDateTime(item.lastDetectedAtUtc, locale)}</dd>
                      </div>
                    </dl>
                    {item.lastError ? (
                      <details className={styles.economyMobileDiagnostic}>
                        <summary>{text.incidentDiagnosticLabel}</summary>
                        <span>{safeText(item.lastError, 96)}</span>
                      </details>
                    ) : null}
                    <div className={styles.economyMobileActions}>
                      <IncidentRowActions
                        item={item}
                        locale={locale}
                        text={text}
                        actionPending={actionPending}
                        selectedIncidentId={selectedIncidentId}
                        selectedIncidentError={selectedIncidentError}
                        onResolve={() => setIncidentPendingResolve(item)}
                        onRetrySelectedIncident={onRetrySelectedIncident}
                        onSelectIncident={() => onSelectIncident(item)}
                      />
                    </div>
                  </article>
                </li>
              ))}
            </ul>
            <div className={styles.sectionStack}>
              {!selectedIncidentId ? (
                <AdminStateCard tone="info" title={text.incidentNoDetail} />
              ) : selectedIncidentLoading && !selectedIncidentDetail ? (
                <AdminStateCard tone="info" title={text.loadingTitle} />
              ) : selectedIncidentError ? (
                <AdminStateCard
                  tone="danger"
                  title={text.incidentDetailLoadError}
                  description={selectedIncidentError}
                  action={
                    <Button type="button" variant="secondary" onClick={onRetrySelectedIncident}>
                      {text.retry}
                    </Button>
                  }
                />
              ) : selectedIncidentDetail ? (
                <div className={styles.packMeta}>
                  <h3>{text.incidentDetailTitle}</h3>
                  <div className={styles.filterRow}>
                    <span className={adminTableStyles.mono}>
                      {shortGuid(selectedIncidentDetail.incident.incidentId)}
                    </span>
                    <AdminStatusBadge color={statusColor(selectedIncidentDetail.incident.status)}>
                      {humanizeStatus(selectedIncidentDetail.incident.status, locale)}
                    </AdminStatusBadge>
                    <AdminStatusBadge
                      color={severityColor(selectedIncidentDetail.incident.severity)}
                    >
                      {safeText(selectedIncidentDetail.incident.severity, 32)}
                    </AdminStatusBadge>
                  </div>
                  <IncidentActionForm
                    key={selectedIncidentId ?? selectedIncidentDetail.incident.incidentId}
                    locale={locale}
                    text={text}
                    incident={selectedIncidentDetail.incident}
                    actionPending={actionPending}
                    onApplyIncidentAction={onApplyIncidentAction}
                  />
                  <IncidentLinks detail={selectedIncidentDetail} text={text} locale={locale} />
                </div>
              ) : null}
            </div>
            <div className={styles.pager}>
              <button
                type="button"
                className={styles.pagerButton}
                disabled={incidentPage === 0 || incidentsIsFetching}
                aria-label={`${text.incidentsTitle}: ${text.previousPage}`}
                onClick={() => setIncidentPage((current) => Math.max(0, current - 1))}
              >
                {text.previousPage}
              </button>
              <button
                type="button"
                className={styles.pagerButton}
                disabled={!incidentsHasMore || incidentsIsFetching}
                aria-label={`${text.incidentsTitle}: ${text.nextPage}`}
                onClick={() => setIncidentPage((current) => current + 1)}
              >
                {text.nextPage}
              </button>
            </div>
          </>
        )}
      </AdminDataSurface>
      <ConfirmationDialog
        open={incidentPendingResolve !== null}
        title={text.resolveIncidentConfirmTitle}
        description={
          incidentPendingResolve
            ? `${text.resolveIncidentConfirmDescription} ${safeText(incidentPendingResolve.type, 80)} · ${shortGuid(incidentPendingResolve.incidentId)}`
            : text.resolveIncidentConfirmDescription
        }
        confirmLabel={text.resolveIncidentAction}
        cancelLabel={text.confirmationCancel}
        isSubmitting={actionPending}
        onCancel={() => {
          if (!actionPending) {
            setIncidentPendingResolve(null);
          }
        }}
        onConfirm={() => {
          if (!incidentPendingResolve || actionPending) {
            return;
          }

          void onResolveIncident(incidentPendingResolve).then((succeeded) => {
            if (succeeded) {
              setIncidentPendingResolve(null);
            }
          });
        }}
      />
    </>
  );
}

type IncidentRowActionsProps = {
  item: AdminEconomyIncident;
  locale: Locale;
  text: EconomyPageText;
  actionPending: boolean;
  selectedIncidentId: string | null;
  selectedIncidentError: string | null;
  onResolve: () => void;
  onRetrySelectedIncident: () => void;
  onSelectIncident: () => void;
};

function IncidentRowActions({
  item,
  locale,
  text,
  actionPending,
  selectedIncidentId,
  selectedIncidentError,
  onResolve,
  onRetrySelectedIncident,
  onSelectIncident,
}: IncidentRowActionsProps) {
  return (
    <>
      {item.status.toLowerCase() === "open" ? (
        <Button
          type="button"
          size="sm"
          variant="secondary"
          disabled={actionPending}
          aria-label={`${text.resolveIncidentAction}: ${safeText(item.type, 80)}`}
          onClick={onResolve}
        >
          {text.resolveIncidentAction}
        </Button>
      ) : (
        <span className={styles.mutedText}>{humanizeStatus(item.status, locale)}</span>
      )}
      <Button
        type="button"
        size="sm"
        variant="ghost"
        disabled={
          actionPending || (selectedIncidentId === item.incidentId && !selectedIncidentError)
        }
        aria-label={`${text.viewIncidentAction}: ${safeText(item.type, 80)}`}
        onClick={() => {
          if (selectedIncidentId === item.incidentId && selectedIncidentError) {
            onRetrySelectedIncident();
            return;
          }

          onSelectIncident();
        }}
      >
        {text.viewIncidentAction}
      </Button>
    </>
  );
}

type IncidentActionFormProps = {
  locale: Locale;
  text: EconomyPageText;
  incident: AdminEconomyIncident;
  actionPending: boolean;
  onApplyIncidentAction: EconomyPageIncidentsSectionProps["onApplyIncidentAction"];
};

function IncidentActionForm({
  locale,
  text,
  incident,
  actionPending,
  onApplyIncidentAction,
}: IncidentActionFormProps) {
  const [action, setAction] = useState("");
  const [reason, setReason] = useState("");
  const [amount, setAmount] = useState("");
  const [externalReferenceId, setExternalReferenceId] = useState("");
  const [isActionConfirmationOpen, setIsActionConfirmationOpen] = useState(false);
  const actionOptions = useMemo(
    () => [{ value: "", label: text.incidentActionLabel }, ...incidentActionOptions[locale]],
    [locale, text.incidentActionLabel]
  );
  const actionRequirements = getIncidentActionRequirements(action);
  const parsedAmount = parseIncidentActionAmount(amount);
  const isAmountValid =
    !actionRequirements.requiresAmount || isIncidentActionAmountValid(action, parsedAmount);
  const hasExternalReference = Boolean(externalReferenceId.trim());
  const canSubmitAction =
    Boolean(action) &&
    Boolean(reason.trim()) &&
    isAmountValid &&
    (!actionRequirements.requiresExternalReference || hasExternalReference);

  const requestActionConfirmation = () => {
    if (!canSubmitAction) {
      return;
    }

    setIsActionConfirmationOpen(true);
  };

  const submitAction = () => {
    if (!canSubmitAction) {
      return;
    }

    onApplyIncidentAction({
      incidentId: incident.incidentId,
      action,
      reason,
      amount: actionRequirements.requiresAmount && parsedAmount !== null ? parsedAmount : undefined,
      externalReferenceId: actionRequirements.requiresExternalReference
        ? externalReferenceId.trim()
        : undefined,
    });
    setIsActionConfirmationOpen(false);
  };

  return (
    <>
      <div className={styles.filterRow}>
        <EconomySelectField
          label={text.incidentActionLabel}
          value={action}
          onChange={(nextAction) => {
            const nextRequirements = getIncidentActionRequirements(nextAction);
            setAction(nextAction);
            setAmount((current) => (nextRequirements.requiresAmount ? current : ""));
            if (!nextRequirements.requiresExternalReference) {
              setExternalReferenceId("");
            }
          }}
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
        {actionRequirements.requiresAmount ? (
          <label className={styles.filterField}>
            <span>{text.incidentAmountLabel}</span>
            <input
              className={styles.input}
              value={amount}
              disabled={actionPending}
              inputMode="numeric"
              pattern={actionRequirements.allowsSignedAmount ? "-?[0-9]*" : "[0-9]*"}
              maxLength={11}
              aria-required
              aria-invalid={!isAmountValid || undefined}
              onChange={(event) => setAmount(event.target.value)}
            />
          </label>
        ) : null}
        {actionRequirements.requiresExternalReference ? (
          <label className={styles.filterField}>
            <span>{text.incidentExternalReferenceLabel}</span>
            <input
              className={styles.input}
              value={externalReferenceId}
              disabled={actionPending}
              maxLength={ECONOMY_INCIDENT_EXTERNAL_REFERENCE_MAX_LENGTH}
              aria-required
              aria-invalid={!hasExternalReference || undefined}
              onChange={(event) => setExternalReferenceId(event.target.value)}
            />
          </label>
        ) : null}
        <Button
          type="button"
          variant="secondary"
          disabled={actionPending || !canSubmitAction}
          onClick={requestActionConfirmation}
        >
          {text.incidentActionSubmit}
        </Button>
      </div>
      {!reason.trim() ? (
        <span className={styles.mutedText}>{text.incidentReasonRequired}</span>
      ) : null}
      {actionRequirements.requiresAmount && !isAmountValid ? (
        <span className={styles.validationMessage}>{text.incidentAmountRequired}</span>
      ) : null}
      {actionRequirements.requiresExternalReference && !hasExternalReference ? (
        <span className={styles.validationMessage}>{text.incidentExternalReferenceRequired}</span>
      ) : null}
      <ConfirmationDialog
        open={isActionConfirmationOpen}
        title={text.incidentActionConfirmTitle}
        description={formatIncidentActionConfirmation(
          text,
          actionOptions.find((option) => option.value === action)?.label ?? action,
          reason,
          actionRequirements.requiresAmount ? amount : null,
          actionRequirements.requiresExternalReference ? externalReferenceId : null
        )}
        confirmLabel={text.incidentActionSubmit}
        cancelLabel={text.confirmationCancel}
        isSubmitting={actionPending}
        onCancel={() => setIsActionConfirmationOpen(false)}
        onConfirm={submitAction}
      />
    </>
  );
}

type IncidentActionRequirements = {
  requiresAmount: boolean;
  allowsSignedAmount: boolean;
  requiresExternalReference: boolean;
};

const INCIDENT_ACTION_AMOUNT_MIN = -2_147_483_648;
const INCIDENT_ACTION_AMOUNT_MAX = 2_147_483_647;

export function getIncidentActionRequirements(action: string): IncidentActionRequirements {
  const normalizedAction = action.trim().toLowerCase();
  const allowsSignedAmount = normalizedAction === "manual_wallet_correction";

  return {
    requiresAmount:
      normalizedAction === "manual_bonus_grant" ||
      normalizedAction === "manual_revoke" ||
      allowsSignedAmount,
    allowsSignedAmount,
    requiresExternalReference: normalizedAction === "manual_refund_mark",
  };
}

export function parseIncidentActionAmount(value: string): number | null {
  const normalizedValue = value.trim();
  if (!/^-?\d+$/.test(normalizedValue)) {
    return null;
  }

  const parsedAmount = Number(normalizedValue);
  return Number.isInteger(parsedAmount) &&
    parsedAmount >= INCIDENT_ACTION_AMOUNT_MIN &&
    parsedAmount <= INCIDENT_ACTION_AMOUNT_MAX
    ? parsedAmount
    : null;
}

export function isIncidentActionAmountValid(action: string, amount: number | null): boolean {
  const normalizedAction = action.trim().toLowerCase();
  if (normalizedAction === "manual_bonus_grant" || normalizedAction === "manual_revoke") {
    return amount !== null && amount > 0;
  }

  if (normalizedAction === "manual_wallet_correction") {
    return amount !== null && amount !== 0;
  }

  return true;
}

function formatIncidentActionConfirmation(
  text: EconomyPageText,
  actionLabel: string,
  reason: string,
  amount: string | null,
  externalReferenceId: string | null
) {
  const details = [
    actionLabel,
    `${text.incidentReasonLabel}: ${safeText(reason, ECONOMY_INCIDENT_REASON_MAX_LENGTH)}`,
    amount ? `${text.incidentAmountLabel}: ${amount}` : null,
    externalReferenceId
      ? `${text.incidentExternalReferenceLabel}: ${safeText(
          externalReferenceId,
          ECONOMY_INCIDENT_EXTERNAL_REFERENCE_MAX_LENGTH
        )}`
      : null,
  ].filter(Boolean);

  return `${text.incidentActionConfirmDescription} ${details.join(" · ")}`;
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
                <th scope="col">{text.timeColumn}</th>
                <th scope="col">{text.sourceColumn}</th>
                <th scope="col">{text.tokenKindColumn}</th>
                <th scope="col">{text.deltaColumn}</th>
                <th scope="col">{text.balanceColumn}</th>
                <th scope="col">{text.reasonColumn}</th>
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
              {humanizeStatus(event.status, locale)} ·{" "}
              {event.externalEventId ? safeText(event.externalEventId, 120) : "-"} ·{" "}
              {formatDateTime(event.createdAtUtc, locale)}
            </span>
            {event.payloadSnapshotJson ? (
              <code className={styles.incidentPayload}>
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
