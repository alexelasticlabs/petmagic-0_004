import {
  type AdminRedeemCode,
  type AdminRedeemRewardKind,
  type AdminUserDetail,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

type PromoDictionary = ReturnType<typeof getDictionary>;

export type PromoStatusKey =
  | "draft"
  | "scheduled"
  | "active"
  | "paused"
  | "exhausted"
  | "expired"
  | "archived";
export type PromoStatusFilter = "all" | PromoStatusKey;
export type PromoSortMode = "updated" | "usage" | "reward" | "code" | "expiry";
export type PromoFormMode = "create" | "edit" | "duplicate";
export type PromoFeedback = {
  tone: "success" | "danger" | "info";
  message: string;
};
export type PromoForm = {
  code: string;
  description: string;
  campaignName: string;
  campaignChannel: string;
  minimumSuccessfulPurchases: string;
  rewardKind: AdminRedeemRewardKind;
  rewardValue: string;
  maxRedemptions: string;
  maxRedemptionsPerUser: string;
  isActive: boolean;
  startsAtUtc: string;
  expiresAtUtc: string;
};

type PromoStatusModel = {
  key: PromoStatusKey;
  label: string;
  color: string;
};

export const PROMO_NUMERIC_FIELD_MAX_LENGTH = 8;
export const PROMO_CODE_MAX_LENGTH = 48;
export const PROMO_DESCRIPTION_MAX_LENGTH = 160;
export const PROMO_CAMPAIGN_FIELD_MAX_LENGTH = 80;

export function createDefaultPromoForm(): PromoForm {
  return {
    code: createGeneratedPromoCode(),
    description: "",
    campaignName: "",
    campaignChannel: "",
    minimumSuccessfulPurchases: "0",
    rewardKind: "spark",
    rewardValue: "100",
    maxRedemptions: "100",
    maxRedemptionsPerUser: "1",
    isActive: true,
    startsAtUtc: "",
    expiresAtUtc: "",
  };
}

export function toPromoForm(code: AdminRedeemCode): PromoForm {
  return {
    code: normalizePromoText(code.code || `${code.codePrefix}...`, PROMO_CODE_MAX_LENGTH),
    description: normalizePromoText(code.description, PROMO_DESCRIPTION_MAX_LENGTH),
    campaignName: normalizePromoText(code.campaignName ?? "", PROMO_CAMPAIGN_FIELD_MAX_LENGTH),
    campaignChannel: normalizePromoText(
      code.campaignChannel ?? "",
      PROMO_CAMPAIGN_FIELD_MAX_LENGTH
    ),
    minimumSuccessfulPurchases: code.minimumSuccessfulPurchases.toString(),
    rewardKind: code.rewardKind,
    rewardValue: code.rewardValue.toString(),
    maxRedemptions: code.maxRedemptions.toString(),
    maxRedemptionsPerUser: code.maxRedemptionsPerUser.toString(),
    isActive: code.isActive,
    startsAtUtc: toDateTimeLocalValue(code.startsAtUtc),
    expiresAtUtc: toDateTimeLocalValue(code.expiresAtUtc),
  };
}

export function toCreatePayload(form: PromoForm, text: PromoDictionary) {
  validatePromoForm(form, 0, 0, text);

  return {
    code: normalizePromoText(form.code, PROMO_CODE_MAX_LENGTH),
    description: normalizePromoText(form.description, PROMO_DESCRIPTION_MAX_LENGTH),
    campaignName: normalizePromoText(form.campaignName, PROMO_CAMPAIGN_FIELD_MAX_LENGTH) || null,
    campaignChannel: normalizePromoText(form.campaignChannel, PROMO_CAMPAIGN_FIELD_MAX_LENGTH) || null,
    minimumSuccessfulPurchases: Number(form.minimumSuccessfulPurchases.trim()),
    rewardKind: form.rewardKind,
    rewardValue: Number(form.rewardValue.trim()),
    maxRedemptions: Number(form.maxRedemptions.trim()),
    maxRedemptionsPerUser: Number(form.maxRedemptionsPerUser.trim()),
    isActive: form.isActive,
    startsAtUtc: toIsoOrNull(form.startsAtUtc),
    expiresAtUtc: toIsoOrNull(form.expiresAtUtc),
  };
}

export function toUpdatePayload(form: PromoForm, code: AdminRedeemCode, text: PromoDictionary) {
  validatePromoForm(form, code.redeemedCount, getMaxUserRedemptions(code), text);

  return {
    description: normalizePromoText(form.description, PROMO_DESCRIPTION_MAX_LENGTH),
    campaignName: normalizePromoText(form.campaignName, PROMO_CAMPAIGN_FIELD_MAX_LENGTH) || null,
    campaignChannel: normalizePromoText(form.campaignChannel, PROMO_CAMPAIGN_FIELD_MAX_LENGTH) || null,
    minimumSuccessfulPurchases: Number(form.minimumSuccessfulPurchases.trim()),
    createdBy: code.createdBy?.trim() || null,
    rewardKind: form.rewardKind,
    rewardValue: Number(form.rewardValue.trim()),
    maxRedemptions: Number(form.maxRedemptions.trim()),
    maxRedemptionsPerUser: Number(form.maxRedemptionsPerUser.trim()),
    isActive: form.isActive,
    startsAtUtc: toIsoOrNull(form.startsAtUtc),
    expiresAtUtc: toIsoOrNull(form.expiresAtUtc),
  };
}

function validatePromoForm(
  form: PromoForm,
  redeemedCount: number,
  maxRedeemedBySingleUser: number,
  text: PromoDictionary
) {
  const normalizedCode = form.code.trim();
  const rewardValue = parsePromoIntegerInput(form.rewardValue, false);
  const maxRedemptions = parsePromoIntegerInput(form.maxRedemptions, false);
  const maxRedemptionsPerUser = parsePromoIntegerInput(form.maxRedemptionsPerUser, false);
  const minimumSuccessfulPurchases = parsePromoIntegerInput(
    form.minimumSuccessfulPurchases,
    true
  );

  if (
    !normalizedCode ||
    normalizedCode.length < 4 ||
    normalizedCode.length > PROMO_CODE_MAX_LENGTH
  ) {
    throw new Error(text.promoCodesInvalidCode);
  }

  if (form.rewardKind !== "spark") {
    throw new Error(text.promoCodesRewardUnsupported);
  }

  if (
    rewardValue === null ||
    maxRedemptions === null ||
    maxRedemptionsPerUser === null ||
    minimumSuccessfulPurchases === null
  ) {
    throw new Error(text.promoCodesInvalidNumbers);
  }

  if (maxRedemptions < redeemedCount) {
    throw new Error(text.promoCodesLimitTooLow);
  }

  if (maxRedemptionsPerUser < maxRedeemedBySingleUser) {
    throw new Error(text.promoCodesPerUserLimitTooLow);
  }

  if (
    form.startsAtUtc &&
    form.expiresAtUtc &&
    new Date(form.startsAtUtc).getTime() > new Date(form.expiresAtUtc).getTime()
  ) {
    throw new Error(text.promoCodesInvalidWindow);
  }
}

function normalizePromoText(value: string, maxLength: number): string {
  return value.trim().slice(0, maxLength);
}

export function normalizePromoIntegerInput(value: string): string {
  return value.replace(/\D+/g, "").slice(0, PROMO_NUMERIC_FIELD_MAX_LENGTH);
}

export function isPromoIntegerInput(value: string, allowZero: boolean): boolean {
  return parsePromoIntegerInput(value, allowZero) !== null;
}

function parsePromoIntegerInput(value: string, allowZero: boolean): number | null {
  const trimmed = value.trim();
  if (!new RegExp(`^\\d{1,${PROMO_NUMERIC_FIELD_MAX_LENGTH}}$`).test(trimmed)) {
    return null;
  }

  const parsed = Number(trimmed);
  if (!Number.isSafeInteger(parsed) || parsed < 0 || (!allowZero && parsed === 0)) {
    return null;
  }

  return parsed;
}

export function getPromoStatus(
  code: AdminRedeemCode,
  text: PromoDictionary,
  now: number
): PromoStatusModel {
  if (!code.isActive && hasArchiveWindowMarker(code)) {
    return { key: "archived", label: text.promoCodesStatusArchived, color: "var(--text-muted)" };
  }

  const startsAt = code.startsAtUtc ? new Date(code.startsAtUtc).getTime() : null;
  const expiresAt = code.expiresAtUtc ? new Date(code.expiresAtUtc).getTime() : null;

  if (code.redeemedCount >= code.maxRedemptions) {
    return { key: "exhausted", label: text.promoCodesStatusLimitReached, color: "var(--warning)" };
  }

  if (expiresAt !== null && expiresAt <= now) {
    return { key: "expired", label: text.promoCodesStatusExpired, color: "var(--danger)" };
  }

  if (!code.isActive) {
    const isDraft =
      code.redeemedCount === 0 &&
      !code.startsAtUtc &&
      !code.expiresAtUtc &&
      !code.description.trim();

    if (isDraft) {
      return { key: "draft", label: text.promoCodesStatusDraft, color: "var(--text-muted)" };
    }

    return { key: "paused", label: text.promoCodesStatusPaused, color: "var(--warning)" };
  }

  if (startsAt !== null && startsAt > now) {
    return { key: "scheduled", label: text.promoCodesStatusScheduled, color: "var(--info)" };
  }

  return { key: "active", label: text.promoCodesStatusActiveOption, color: "var(--success)" };
}

function hasArchiveWindowMarker(code: AdminRedeemCode) {
  if (!code.startsAtUtc || !code.expiresAtUtc) {
    return false;
  }

  const startsAt = new Date(code.startsAtUtc).getTime();
  const expiresAt = new Date(code.expiresAtUtc).getTime();

  if (Number.isNaN(startsAt) || Number.isNaN(expiresAt)) {
    return false;
  }

  return Math.abs(startsAt - expiresAt) <= 60_000;
}

export function comparePromoCodes(
  firstItem: AdminRedeemCode,
  secondItem: AdminRedeemCode,
  sortMode: PromoSortMode
) {
  switch (sortMode) {
    case "usage":
      return (
        secondItem.redeemedCount - firstItem.redeemedCount ||
        secondItem.rewardValue - firstItem.rewardValue
      );
    case "reward":
      return (
        secondItem.rewardValue - firstItem.rewardValue ||
        secondItem.redeemedCount - firstItem.redeemedCount
      );
    case "code": {
      const firstCode = firstItem.code || firstItem.codePrefix;
      const secondCode = secondItem.code || secondItem.codePrefix;
      return firstCode.localeCompare(secondCode);
    }
    case "expiry": {
      const firstExpiry = firstItem.expiresAtUtc
        ? new Date(firstItem.expiresAtUtc).getTime()
        : Number.MAX_SAFE_INTEGER;
      const secondExpiry = secondItem.expiresAtUtc
        ? new Date(secondItem.expiresAtUtc).getTime()
        : Number.MAX_SAFE_INTEGER;
      return firstExpiry - secondExpiry;
    }
    default:
      return (
        new Date(secondItem.updatedAtUtc).getTime() - new Date(firstItem.updatedAtUtc).getTime()
      );
  }
}

export function getRewardKindLabel(kind: AdminRedeemRewardKind, text: PromoDictionary) {
  if (kind === "premium_days") {
    return text.promoCodesRewardTypePremiumOption;
  }

  return text.promoCodesRewardTypeSparkOption;
}

export function formatCampaignMeta(code: AdminRedeemCode) {
  const parts = [code.campaignName, code.campaignChannel]
    .map((value) => formatPromoDisplayText(value, 80))
    .filter((value) => value !== "-");

  return parts.join(" · ");
}

export function formatPromoDisplayText(value: string | null | undefined, maxLength = 120) {
  const trimmed = value?.trim();
  return trimmed ? sanitizeSensitiveText(trimmed, maxLength) : "-";
}

export function formatRewardValue(
  value: number,
  kind: AdminRedeemRewardKind,
  text: PromoDictionary
) {
  if (kind === "premium_days") {
    return `${value} ${text.promoCodesRewardTypePremiumOption}`;
  }

  return `${value} PawSpark`;
}

export function formatWindow(code: AdminRedeemCode, locale: Locale, text: PromoDictionary) {
  if (!code.startsAtUtc && !code.expiresAtUtc) {
    return text.promoCodesWindowAlways;
  }

  if (code.startsAtUtc && code.expiresAtUtc) {
    return `${formatDateTime(code.startsAtUtc, locale)} - ${formatDateTime(code.expiresAtUtc, locale)}`;
  }

  if (code.startsAtUtc) {
    return `${text.promoCodesStartsLabel}: ${formatDateTime(code.startsAtUtc, locale)}`;
  }

  return `${text.promoCodesExpiresLabel}: ${formatDateTime(code.expiresAtUtc, locale)}`;
}

export function getLastUsedAt(code: AdminRedeemCode) {
  if (code.lastRedeemedAtUtc) {
    return code.lastRedeemedAtUtc;
  }

  if (!code.redemptions.length) {
    return null;
  }

  return code.redemptions.reduce((latest, item) => {
    if (!latest) {
      return item.redeemedAtUtc;
    }

    return new Date(item.redeemedAtUtc).getTime() > new Date(latest).getTime()
      ? item.redeemedAtUtc
      : latest;
  }, "" as string);
}

export function formatDateTime(value: string | null | undefined, locale: Locale) {
  if (!value) {
    return "-";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

export function formatNumber(value: number, locale: Locale) {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US").format(value);
}

export function formatSevenDayDelta(value: number, locale: Locale, text: PromoDictionary) {
  const sign = value > 0 ? "+" : "";
  return `${sign}${formatNumber(value, locale)} ${text.promoCodesLast7DaysLabel}`;
}

function toDateTimeLocalValue(value: string | null | undefined) {
  if (!value) {
    return "";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }

  const localDate = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return localDate.toISOString().slice(0, 16);
}

function toIsoOrNull(value: string) {
  return value ? new Date(value).toISOString() : null;
}

function getMaxUserRedemptions(code: AdminRedeemCode) {
  if (typeof code.maxRedeemedBySingleUser === "number") {
    return code.maxRedeemedBySingleUser;
  }

  const usageByUser = new Map<string, number>();

  for (const redemption of code.redemptions) {
    usageByUser.set(redemption.userId, (usageByUser.get(redemption.userId) ?? 0) + 1);
  }

  return Math.max(0, ...usageByUser.values());
}

export function createGeneratedPromoCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const segments = Array.from({ length: 3 }, () =>
    Array.from({ length: 4 }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join("")
  );
  return `PM-${segments.join("-")}`;
}

function shortGuid(value: string) {
  return value.slice(0, 8);
}

export function getUserLabels(userId: string, user?: AdminUserDetail) {
  if (!user) {
    return {
      primary: shortGuid(userId),
      secondary: shortGuid(userId),
    };
  }

  if (user.displayName?.trim()) {
    return {
      primary: sanitizeSensitiveText(user.displayName, 72),
      secondary: maskEmail(user.email),
    };
  }

  return {
    primary: maskEmail(user.email),
    secondary: shortGuid(userId),
  };
}

export async function copyTextToClipboard(value: string) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(value);
    return;
  }

  const input = document.createElement("textarea");
  input.value = value;
  input.setAttribute("readonly", "true");
  input.style.position = "absolute";
  input.style.left = "-9999px";
  document.body.append(input);
  input.select();
  document.execCommand("copy");
  input.remove();
}

export function buildPromoCodesCsv(
  codes: AdminRedeemCode[],
  locale: Locale,
  text: PromoDictionary,
  now = Date.now()
) {
  const rows = [
    [
      text.promoCodesCodeLabel,
      text.promoCodesRewardLabel,
      text.promoCodesUsageLabel,
      text.statusLabel,
      text.promoCodesWindowLabel,
      text.promoCodesUpdatedColumn,
    ],
    ...codes.map((code) => [
      code.code,
      formatRewardValue(code.rewardValue, code.rewardKind, text),
      `${code.redeemedCount}/${code.maxRedemptions}`,
      getPromoStatus(code, text, now).label,
      formatWindow(code, locale, text),
      formatDateTime(code.updatedAtUtc, locale),
    ]),
  ];

  return `\uFEFF${rows.map((row) => row.map(escapeCsvCell).join(",")).join("\n")}`;
}

function escapeCsvCell(value: string) {
  const sanitizedValue = sanitizeSensitiveText(value, 240);
  const safeValue = /^[=+\-@\t\r]/.test(sanitizedValue) ? `'${sanitizedValue}` : sanitizedValue;

  if (safeValue.includes(",") || safeValue.includes('"') || safeValue.includes("\n")) {
    return `"${safeValue.replaceAll('"', '""')}"`;
  }

  return safeValue;
}
