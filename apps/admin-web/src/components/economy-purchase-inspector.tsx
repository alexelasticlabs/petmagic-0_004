"use client";

import { AdminDetailsDrawer } from "@/components/admin/admin-details-drawer";
import { AdminEntityLink } from "@/components/admin/admin-entity-link";
import { AdminBadge, AdminStateCard, AdminStatusBadge } from "@/components/admin/admin-primitives";
import styles from "@/components/economy-page.module.css";
import {
  formatCurrency,
  humanizeProvider,
  humanizeStatus,
  safeText,
  shortGuid,
  statusColor,
} from "@/components/economy-page.shared";
import { Button } from "@/components/ui/button";
import type { AdminEconomyPurchase, AdminEconomyPurchaseDetail } from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

type EconomyPurchaseInspectorProps = {
  locale: Locale;
  orderId: string | null;
  detail: AdminEconomyPurchaseDetail | null;
  isLoading: boolean;
  error: string | null;
  isRefundPending: boolean;
  onClose: () => void;
  onRetry: () => void;
  onRefund: (purchase: AdminEconomyPurchase) => void;
};

const copy = {
  ru: {
    title: "Инспектор покупки",
    description: "Статус оплаты, возврата и связанные операционные события.",
    close: "Закрыть инспектор покупки",
    loading: "Загружаем покупку",
    error: "Не удалось загрузить покупку",
    retry: "Повторить",
    refund: "Оформить возврат",
    retryRefund: "Повторить возврат",
    summary: "Сводка",
    settlement: "Расчёт",
    amount: "Сумма",
    grant: "Начислено",
    capabilities: "Доступные действия",
    canRefund: "Возврат разрешён",
    cannotRefund: "Возврат недоступен",
    manualReview: "Требуется ручная проверка",
    timeline: "Хронология возврата",
    noTimeline: "События возврата ещё не зафиксированы.",
    links: "Связанные сущности",
    user: "Пользователь",
    noIncidents: "Связанных инцидентов нет.",
    created: "Покупка создана",
    payment_confirmed: "Платёж подтверждён",
    refund_requested: "Возврат запрошен",
    refund_settled: "Возврат завершён",
    manual_review_required: "Передано на ручную проверку",
  },
  en: {
    title: "Purchase inspector",
    description: "Payment, refund, and related operational state.",
    close: "Close purchase inspector",
    loading: "Loading purchase",
    error: "Could not load purchase",
    retry: "Retry",
    refund: "Issue refund",
    retryRefund: "Retry refund",
    summary: "Summary",
    settlement: "Settlement",
    amount: "Amount",
    grant: "Granted",
    capabilities: "Available actions",
    canRefund: "Refund is available",
    cannotRefund: "Refund is unavailable",
    manualReview: "Manual review required",
    timeline: "Refund timeline",
    noTimeline: "No refund events have been recorded yet.",
    links: "Related entities",
    user: "User",
    noIncidents: "No related incidents.",
    created: "Purchase created",
    payment_confirmed: "Payment confirmed",
    refund_requested: "Refund requested",
    refund_settled: "Refund settled",
    manual_review_required: "Sent to manual review",
  },
} as const;

export function EconomyPurchaseInspector({
  locale,
  orderId,
  detail,
  isLoading,
  error,
  isRefundPending,
  onClose,
  onRetry,
  onRefund,
}: EconomyPurchaseInspectorProps) {
  const text = copy[locale];
  const refundTimeline =
    detail?.timeline.filter(
      (item) => item.eventType !== "created" && item.eventType !== "payment_confirmed"
    ) ?? [];

  return (
    <AdminDetailsDrawer
      id="economy-purchase-inspector"
      open={Boolean(orderId)}
      title={text.title}
      description={detail ? shortGuid(detail.orderId) : text.description}
      closeLabel={text.close}
      onClose={onClose}
      footer={
        detail?.capabilities.canRefund ? (
          <Button
            type="button"
            variant="danger"
            disabled={isRefundPending}
            onClick={() => onRefund(detail)}
          >
            {detail.capabilities.canRetryRefund ? text.retryRefund : text.refund}
          </Button>
        ) : undefined
      }
    >
      {isLoading && !detail ? (
        <AdminStateCard tone="info" title={text.loading} />
      ) : error ? (
        <AdminStateCard
          tone="danger"
          title={text.error}
          description={error}
          action={
            <Button type="button" variant="secondary" onClick={onRetry}>
              {text.retry}
            </Button>
          }
        />
      ) : detail ? (
        <div className={styles.purchaseInspectorStack}>
          <section className={styles.purchaseInspectorSection}>
            <div className={styles.purchaseInspectorHeading}>
              <h3>{text.summary}</h3>
              <AdminStatusBadge color={statusColor(detail.status)}>
                {humanizeStatus(detail.status, locale)}
              </AdminStatusBadge>
            </div>
            <dl className={styles.purchaseInspectorFacts}>
              <div>
                <dt>{text.amount}</dt>
                <dd>{formatCurrency(detail.priceAmount, locale, detail.currencyCode)}</dd>
              </div>
              <div>
                <dt>{text.grant}</dt>
                <dd>{detail.sparkToGrant} PawSpark</dd>
              </div>
              <div>
                <dt>{text.settlement}</dt>
                <dd>{humanizeStatus(detail.settlementState, locale)}</dd>
              </div>
              <div>
                <dt>{text.created}</dt>
                <dd>{formatDateTime(detail.createdAtUtc, locale)}</dd>
              </div>
            </dl>
            <p className={styles.purchaseInspectorProvider}>
              {safeText(detail.packDisplayName, 120)} ·{" "}
              {humanizeProvider(detail.paymentProvider, locale)}
            </p>
          </section>

          <section className={styles.purchaseInspectorSection}>
            <h3>{text.capabilities}</h3>
            <div className={styles.purchaseInspectorBadges}>
              <AdminBadge tone={detail.capabilities.canRefund ? "success" : "neutral"}>
                {detail.capabilities.canRefund ? text.canRefund : text.cannotRefund}
              </AdminBadge>
              {detail.capabilities.requiresManualReview ? (
                <AdminBadge tone="warning">{text.manualReview}</AdminBadge>
              ) : null}
            </div>
          </section>

          <section className={styles.purchaseInspectorSection}>
            <h3>{text.timeline}</h3>
            {refundTimeline.length ? (
              <ol className={styles.purchaseTimeline}>
                {refundTimeline.map((item, index) => (
                  <li key={`${item.eventType}-${item.occurredAtUtc}-${index}`}>
                    <span aria-hidden="true" />
                    <div>
                      <strong>
                        {text[item.eventType as keyof typeof text] ?? safeText(item.eventType, 64)}
                      </strong>
                      <time dateTime={item.occurredAtUtc}>
                        {formatDateTime(item.occurredAtUtc, locale)}
                      </time>
                    </div>
                  </li>
                ))}
              </ol>
            ) : (
              <p className={styles.mutedText}>{text.noTimeline}</p>
            )}
          </section>

          <section className={styles.purchaseInspectorSection}>
            <h3>{text.links}</h3>
            <div className={styles.purchaseEntityLinks}>
              <AdminEntityLink
                href={`/${locale}/users/${encodeURIComponent(detail.userId)}`}
                label={text.user}
                secondaryLabel={shortGuid(detail.userId)}
              />
              {detail.incidents.map((incident) => (
                <AdminEntityLink
                  key={incident.incidentId}
                  href={`/${locale}/economy?workspace=payments&incident=${encodeURIComponent(incident.incidentId)}`}
                  label={safeText(incident.type, 80)}
                  secondaryLabel={`${safeText(incident.severity, 24)} · ${humanizeStatus(incident.status, locale)}`}
                />
              ))}
            </div>
            {!detail.incidents.length ? (
              <p className={styles.mutedText}>{text.noIncidents}</p>
            ) : null}
          </section>
        </div>
      ) : null}
    </AdminDetailsDrawer>
  );
}
