import {
    type AdminRedeemCode,
    type AdminRedeemRewardKind,
    type AdminUserDetail,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

type PromoDictionary = ReturnType<typeof getDictionary>;

export type PromoStatusKey = "draft" | "scheduled" | "active" | "paused" | "exhausted" | "expired" | "archived";
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
    createdBy: string;
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

export function createDefaultPromoForm(): PromoForm {
    return {
        code: createGeneratedPromoCode(),
        description: "",
        campaignName: "",
        campaignChannel: "",
        minimumSuccessfulPurchases: "0",
        createdBy: "",
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
        code: code.code || `${code.codePrefix}...`,
        description: code.description,
        campaignName: code.campaignName ?? "",
        campaignChannel: code.campaignChannel ?? "",
        minimumSuccessfulPurchases: code.minimumSuccessfulPurchases.toString(),
        createdBy: code.createdBy ?? "",
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
        code: form.code.trim(),
        description: form.description.trim(),
        campaignName: form.campaignName.trim() || null,
        campaignChannel: form.campaignChannel.trim() || null,
        minimumSuccessfulPurchases: Number(form.minimumSuccessfulPurchases),
        createdBy: form.createdBy.trim() || null,
        rewardKind: form.rewardKind,
        rewardValue: Number(form.rewardValue),
        maxRedemptions: Number(form.maxRedemptions),
        maxRedemptionsPerUser: Number(form.maxRedemptionsPerUser),
        isActive: form.isActive,
        startsAtUtc: toIsoOrNull(form.startsAtUtc),
        expiresAtUtc: toIsoOrNull(form.expiresAtUtc),
    };
}

export function toUpdatePayload(form: PromoForm, code: AdminRedeemCode, text: PromoDictionary) {
    validatePromoForm(form, code.redeemedCount, getMaxUserRedemptions(code), text);

    return {
        description: form.description.trim(),
        campaignName: form.campaignName.trim() || null,
        campaignChannel: form.campaignChannel.trim() || null,
        minimumSuccessfulPurchases: Number(form.minimumSuccessfulPurchases),
        createdBy: form.createdBy.trim() || null,
        rewardKind: form.rewardKind,
        rewardValue: Number(form.rewardValue),
        maxRedemptions: Number(form.maxRedemptions),
        maxRedemptionsPerUser: Number(form.maxRedemptionsPerUser),
        isActive: form.isActive,
        startsAtUtc: toIsoOrNull(form.startsAtUtc),
        expiresAtUtc: toIsoOrNull(form.expiresAtUtc),
    };
}

function validatePromoForm(form: PromoForm, redeemedCount: number, maxRedeemedBySingleUser: number, text: PromoDictionary) {
    const normalizedCode = form.code.trim();
    const rewardValue = Number(form.rewardValue);
    const maxRedemptions = Number(form.maxRedemptions);
    const maxRedemptionsPerUser = Number(form.maxRedemptionsPerUser);
    const minimumSuccessfulPurchases = Number(form.minimumSuccessfulPurchases);

    if (!normalizedCode || normalizedCode.length < 4 || normalizedCode.length > 48) {
        throw new Error(text.promoCodesInvalidCode);
    }

    if (form.rewardKind !== "spark") {
        throw new Error(text.promoCodesRewardUnsupported);
    }

    if (
        !Number.isFinite(rewardValue)
        || rewardValue <= 0
        || !Number.isFinite(maxRedemptions)
        || maxRedemptions <= 0
        || !Number.isFinite(maxRedemptionsPerUser)
        || maxRedemptionsPerUser <= 0
        || !Number.isFinite(minimumSuccessfulPurchases)
        || minimumSuccessfulPurchases < 0
        || !Number.isInteger(minimumSuccessfulPurchases)
    ) {
        throw new Error(text.promoCodesInvalidNumbers);
    }

    if (maxRedemptions < redeemedCount) {
        throw new Error(text.promoCodesLimitTooLow);
    }

    if (maxRedemptionsPerUser < maxRedeemedBySingleUser) {
        throw new Error(text.promoCodesPerUserLimitTooLow);
    }

    if (form.startsAtUtc && form.expiresAtUtc && new Date(form.startsAtUtc).getTime() > new Date(form.expiresAtUtc).getTime()) {
        throw new Error(text.promoCodesInvalidWindow);
    }
}

export function getPromoStatus(code: AdminRedeemCode, text: PromoDictionary, now: number): PromoStatusModel {
    const startsAt = code.startsAtUtc ? new Date(code.startsAtUtc).getTime() : null;
    const expiresAt = code.expiresAtUtc ? new Date(code.expiresAtUtc).getTime() : null;

    if (code.redeemedCount >= code.maxRedemptions) {
        return { key: "exhausted", label: text.promoCodesStatusLimitReached, color: "#f59e0b" };
    }

    if (expiresAt !== null && expiresAt <= now) {
        return { key: "expired", label: text.promoCodesStatusExpired, color: "#f87171" };
    }

    if (!code.isActive) {
        const isDraft = code.redeemedCount === 0 && !code.startsAtUtc && !code.expiresAtUtc && !code.description.trim();

        if (isDraft) {
            return { key: "draft", label: text.promoCodesStatusDraft, color: "#94a3b8" };
        }

        if (code.redeemedCount > 0) {
            return { key: "archived", label: text.promoCodesStatusArchived, color: "#64748b" };
        }

        return { key: "paused", label: text.promoCodesStatusPaused, color: "#f59e0b" };
    }

    if (startsAt !== null && startsAt > now) {
        return { key: "scheduled", label: text.promoCodesStatusScheduled, color: "#38bdf8" };
    }

    return { key: "active", label: text.activeLabel, color: "#22c55e" };
}

export function comparePromoCodes(firstItem: AdminRedeemCode, secondItem: AdminRedeemCode, sortMode: PromoSortMode) {
    switch (sortMode) {
        case "usage":
            return secondItem.redeemedCount - firstItem.redeemedCount || secondItem.rewardValue - firstItem.rewardValue;
        case "reward":
            return secondItem.rewardValue - firstItem.rewardValue || secondItem.redeemedCount - firstItem.redeemedCount;
        case "code": {
            const firstCode = firstItem.code || firstItem.codePrefix;
            const secondCode = secondItem.code || secondItem.codePrefix;
            return firstCode.localeCompare(secondCode);
        }
        case "expiry": {
            const firstExpiry = firstItem.expiresAtUtc ? new Date(firstItem.expiresAtUtc).getTime() : Number.MAX_SAFE_INTEGER;
            const secondExpiry = secondItem.expiresAtUtc ? new Date(secondItem.expiresAtUtc).getTime() : Number.MAX_SAFE_INTEGER;
            return firstExpiry - secondExpiry;
        }
        default:
            return new Date(secondItem.updatedAtUtc).getTime() - new Date(firstItem.updatedAtUtc).getTime();
    }
}

export function getRewardKindLabel(kind: AdminRedeemRewardKind, text: PromoDictionary) {
    if (kind === "premium_days") {
        return text.promoCodesRewardTypePremiumOption;
    }

    return text.promoCodesRewardTypeSparkOption;
}

export function formatCampaignMeta(code: AdminRedeemCode) {
    const parts = [code.campaignName?.trim(), code.campaignChannel?.trim()]
        .filter((value): value is string => Boolean(value));

    return parts.join(" · ");
}

export function formatRewardValue(value: number, kind: AdminRedeemRewardKind, text: PromoDictionary) {
    if (kind === "premium_days") {
        return `${value} ${text.promoCodesRewardTypePremiumOption}`;
    }

    return `${value} spark`;
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
    if (!code.redemptions.length) {
        return null;
    }

    return code.redemptions.reduce((latest, item) => {
        if (!latest) {
            return item.redeemedAtUtc;
        }

        return new Date(item.redeemedAtUtc).getTime() > new Date(latest).getTime() ? item.redeemedAtUtc : latest;
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
    const usageByUser = new Map<string, number>();

    for (const redemption of code.redemptions) {
        usageByUser.set(redemption.userId, (usageByUser.get(redemption.userId) ?? 0) + 1);
    }

    return Math.max(0, ...usageByUser.values());
}

export function createGeneratedPromoCode() {
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const segments = Array.from({ length: 3 }, () => Array.from({ length: 4 }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join(""));
    return `PM-${segments.join("-")}`;
}

function shortGuid(value: string) {
    return value.slice(0, 8);
}

export function getUserLabels(userId: string, user?: AdminUserDetail) {
    if (!user) {
        return {
            primary: shortGuid(userId),
            secondary: userId,
        };
    }

    if (user.displayName?.trim()) {
        return {
            primary: user.displayName.trim(),
            secondary: user.email,
        };
    }

    return {
        primary: user.email,
        secondary: userId,
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

export function buildPromoCodesCsv(codes: AdminRedeemCode[], locale: Locale, text: PromoDictionary) {
    const rows = [
        [text.promoCodesCodeLabel, text.promoCodesRewardLabel, text.promoCodesUsageLabel, text.statusLabel, text.promoCodesWindowLabel, text.promoCodesUpdatedColumn],
        ...codes.map((code) => [
            code.code,
            formatRewardValue(code.rewardValue, code.rewardKind, text),
            `${code.redeemedCount}/${code.maxRedemptions}`,
            getPromoStatus(code, text, Number.MAX_SAFE_INTEGER).label,
            formatWindow(code, locale, text),
            formatDateTime(code.updatedAtUtc, locale),
        ]),
    ];

    return rows.map((row) => row.map(escapeCsvCell).join(",")).join("\n");
}

function escapeCsvCell(value: string) {
    if (value.includes(",") || value.includes("\"") || value.includes("\n")) {
        return `"${value.replaceAll("\"", "\"\"")}"`;
    }

    return value;
}
