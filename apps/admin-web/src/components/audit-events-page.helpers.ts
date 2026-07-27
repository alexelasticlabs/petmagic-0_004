import { getAuditActionTitle, type AuditPeriod } from "@/components/audit-events-page.content";
import type { AdminAuditEventListItem } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText, shortIdentifier } from "@/lib/sensitive-display";

const PERIOD_DAYS: Record<AuditPeriod, number> = { "24h": 1, "7d": 7, "30d": 30 };

export type AuditEventDeepLink = {
  href: string;
  kind: "support" | "user" | "economy" | "promo";
};

export function getAuditPeriodRange(period: AuditPeriod, now = new Date()) {
  const toUtc = new Date(now);
  const fromUtc = new Date(now);
  fromUtc.setUTCDate(fromUtc.getUTCDate() - PERIOD_DAYS[period]);
  return { fromUtc: fromUtc.toISOString(), toUtc: toUtc.toISOString() };
}

export function formatAuditIdentity(
  identity: { userId?: string | null; displayName?: string | null; email?: string | null },
  fallback: string
) {
  const displayName = identity.displayName?.trim();
  if (displayName) {
    return sanitizeSensitiveText(displayName, 72);
  }

  const email = identity.email?.trim();
  if (email) {
    return maskEmail(email);
  }

  const userId = identity.userId?.trim();
  return userId ? `#${shortIdentifier(userId)}` : fallback;
}

export function formatAuditTarget(event: AdminAuditEventListItem, fallback: string) {
  const targetType = sanitizeSensitiveText(event.targetType, 48);
  const targetId = event.targetId?.trim();
  if (targetType === "—" && !targetId) {
    return fallback;
  }

  return targetId ? `${targetType} · #${shortIdentifier(targetId)}` : targetType;
}

export function getAuditEventPresentation(event: AdminAuditEventListItem, locale: Locale) {
  return {
    title: getAuditActionTitle(locale, event.action),
    actionCode: sanitizeSensitiveText(event.action, 120),
    target: formatAuditTarget(event, locale === "ru" ? "Объект не указан" : "No target"),
  };
}

export function getAuditEventDeepLink(
  event: AdminAuditEventListItem,
  locale: Locale
): AuditEventDeepLink | null {
  const targetType = event.targetType?.trim().toLowerCase();
  if (
    targetType === "supportconversation" &&
    event.targetId?.trim() &&
    /^[0-9a-f-]{36}$/i.test(event.targetId.trim())
  ) {
    return {
      href: `/${locale}/support/${encodeURIComponent(event.targetId.trim())}`,
      kind: "support" as const,
    };
  }

  if (targetType === "currency_pack" || targetType === "subscription_plan") {
    return {
      href: `/${locale}/economy`,
      kind: "economy",
    };
  }

  if (targetType === "redeem_code") {
    return {
      href: `/${locale}/promo-codes`,
      kind: "promo",
    };
  }

  if (event.subjectUserId?.trim()) {
    return {
      href: `/${locale}/users/${encodeURIComponent(event.subjectUserId.trim())}`,
      kind: "user" as const,
    };
  }

  return null;
}
