"use client";

import { useEffect, type CSSProperties, type ReactNode } from "react";

import { AdminStateCard } from "@/components/admin/admin-primitives";
import { type EconomyPageText, getEconomyText } from "@/components/economy-page.content";
import styles from "@/components/economy-page.module.css";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { type AdminWatermarkSettings } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

const watermarkPositionOptions = ["bottom-right", "bottom-left", "top-right", "top-left"] as const;
const watermarkSizeOptions = ["small", "medium", "large"] as const;

export const WATERMARK_TEXT_MAX_LENGTH = 80;
export const WATERMARK_COST_MAX_LENGTH = 6;
export const WATERMARK_OPACITY_MAX_LENGTH = 4;
export const WATERMARK_LOGO_URL_MAX_LENGTH = 2_048;
export const WATERMARK_FORM_ID = "economy-watermark-settings-form";

type TableOrEmptyProps = {
  hasItems: boolean;
  emptyTitle: string;
  children: ReactNode;
};

export function TableOrEmpty({ hasItems, emptyTitle, children }: TableOrEmptyProps) {
  if (!hasItems) {
    return <AdminStateCard tone="info" title={emptyTitle} />;
  }

  return <>{children}</>;
}

export function formatEconomyLogText(value: string | null | undefined, maxLength = 96) {
  const trimmed = value?.trim();
  return trimmed ? sanitizeSensitiveText(trimmed, maxLength) : undefined;
}

export function getEconomyActionErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export function WatermarkPreviewPanel({
  text,
  settings,
}: {
  text: EconomyPageText;
  settings: AdminWatermarkSettings;
}) {
  const previewStyle = {
    "--watermark-preview-opacity": String(settings.opacity),
  } as CSSProperties;
  const badgeText = settings.text.trim() || "PetMagic";
  const position = normalizeWatermarkPosition(settings.position);
  const size = normalizeWatermarkSize(settings.size);

  function renderFrame(kind: "image" | "video", sourceUrl: string) {
    const title =
      kind === "image" ? text.watermarkPreviewImageTitle : text.watermarkPreviewVideoFrameTitle;
    const applies = kind === "image" ? settings.applyToImages : settings.applyToVideos;

    return (
      <div className={styles.watermarkPreviewCard}>
        <div className={styles.watermarkPreviewHeader}>
          <strong>{title}</strong>
          <span>{applies ? text.watermarkEnabledState : text.watermarkDisabledState}</span>
        </div>
        <div className={styles.watermarkPreviewFrame} data-kind={kind} style={previewStyle}>
          {sourceUrl ? (
            <TemplateSecureMedia
              url={sourceUrl}
              kind="image"
              alt={title}
              className={styles.watermarkPreviewMedia}
              logContext={{ surface: `economy-watermark-${kind}` }}
            />
          ) : (
            <div className={styles.watermarkPreviewPlaceholder}>
              {kind === "image"
                ? text.watermarkPreviewTestImage
                : text.watermarkPreviewTestVideoFrame}
            </div>
          )}
          {settings.enabled && applies ? (
            <div
              className={styles.watermarkPreviewBadge}
              data-position={position}
              data-size={size}
            >
              {settings.logoUrl ? (
                <TemplateSecureMedia
                  url={settings.logoUrl}
                  kind="image"
                  alt=""
                  ariaHidden
                  className={styles.watermarkPreviewLogo}
                  logContext={{ surface: "economy-watermark-logo" }}
                />
              ) : null}
              <span>{badgeText}</span>
            </div>
          ) : null}
        </div>
      </div>
    );
  }

  return (
    <div className={styles.watermarkPreviewGrid}>
      {renderFrame("image", settings.previewImageUrl)}
      {renderFrame("video", settings.previewVideoFrameUrl)}
    </div>
  );
}

export function normalizeWatermarkPosition(value: string) {
  return watermarkPositionOptions.includes(value as (typeof watermarkPositionOptions)[number])
    ? value
    : "bottom-right";
}

export function normalizeWatermarkSize(value: string) {
  return watermarkSizeOptions.includes(value as (typeof watermarkSizeOptions)[number])
    ? value
    : "small";
}

export function shortGuid(value: string) {
  return safeText(value, 32).slice(0, 8);
}

export function safeText(value: string | null | undefined, maxLength = 120) {
  const trimmed = value?.trim();
  return trimmed ? sanitizeSensitiveText(trimmed, maxLength) : "-";
}

export function formatTokens(value: number, locale: Locale) {
  const intlLocale = getEconomyText(locale).intlLocale;
  return `${new Intl.NumberFormat(intlLocale).format(value)} spark`;
}

export function formatCurrency(value: number, locale: Locale, currencyCode: string) {
  const amount = Number.isFinite(value) ? value : 0;
  const safeCurrencyCode = safeText(currencyCode.toUpperCase(), 12);
  const intlLocale = getEconomyText(locale).intlLocale;
  if (/^[A-Z]{3}$/.test(safeCurrencyCode)) {
    try {
      return new Intl.NumberFormat(intlLocale, {
        style: "currency",
        currency: safeCurrencyCode,
        maximumFractionDigits: 2,
      }).format(amount);
    } catch {
      // Fall through to a non-throwing display for unexpected currency codes.
    }
  }

  return `${new Intl.NumberFormat(intlLocale, {
    maximumFractionDigits: 2,
  }).format(amount)} ${safeCurrencyCode}`;
}

export function humanizeSource(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    weekly_grant: { ru: "Недельная награда", en: "Weekly reward" },
    ad_reward: { ru: "Награда за рекламу", en: "Ad reward" },
    redeem_code: { ru: "Промокод", en: "Redeem code" },
    premium_subscription_grant: { ru: "Выдача Premium PawSpark", en: "Premium PawSpark grant" },
    generation_spend: { ru: "Списание за генерацию", en: "Generation spend" },
    generation_refund: { ru: "Возврат за генерацию", en: "Generation refund" },
    pack_purchase: { ru: "Покупка пакета", en: "Pack purchase" },
    admin_grant: { ru: "Ручное начисление", en: "Manual grant" },
    admin_debit: { ru: "Ручное списание", en: "Manual debit" },
  };

  return labels[value]?.[locale] ?? safeText(value, 80);
}

export function humanizeProvider(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    app_store: { ru: "Apple App Store", en: "Apple App Store" },
    google_play: { ru: "Google Play", en: "Google Play" },
    stripe: { ru: "Stripe", en: "Stripe" },
  };

  return labels[value]?.[locale] ?? safeText(value, 80);
}

export function humanizeBillingPeriod(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    monthly: { ru: "Месяц", en: "Monthly" },
    yearly: { ru: "Год", en: "Yearly" },
  };

  return labels[value]?.[locale] ?? safeText(value, 48);
}

export function humanizeStatus(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    pending: { ru: "Ожидает", en: "Pending" },
    succeeded: { ru: "Успешно", en: "Succeeded" },
    failed: { ru: "Ошибка", en: "Failed" },
    refunded: { ru: "Возврат", en: "Refunded" },
    active: { ru: "Активна", en: "Active" },
    trialing: { ru: "Пробный период", en: "Trialing" },
    past_due: { ru: "Просрочка", en: "Past due" },
    canceled: { ru: "Отменена", en: "Canceled" },
    expired: { ru: "Истекла", en: "Expired" },
    processed: { ru: "Обработано", en: "Processed" },
  };

  return labels[value]?.[locale] ?? value;
}

export function statusColor(value: string) {
  switch (value) {
    case "active":
    case "succeeded":
    case "processed":
      return "var(--success)";
    case "trialing":
      return "var(--info)";
    case "past_due":
    case "failed":
      return "var(--danger)";
    case "canceled":
    case "expired":
    case "refunded":
      return "var(--neutral)";
    default:
      return "var(--warning)";
  }
}

export function useTimedFeedbackReset(
  feedback: { tone: "success" | "danger"; message: string } | null,
  clearFeedback: () => void
) {
  useEffect(() => {
    if (!feedback) {
      return;
    }

    const timer = window.setTimeout(clearFeedback, 3200);
    return () => window.clearTimeout(timer);
  }, [clearFeedback, feedback]);
}
