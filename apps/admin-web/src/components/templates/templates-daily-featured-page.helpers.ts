import { useEffect, useState } from "react";

import { getTemplatesDailyFeaturedPageIntlLocale } from "@/components/templates/templates-daily-featured-page.content";
import type {
  AssignmentFormState,
  TemplateOption,
} from "@/components/templates/templates-daily-featured-page.types";
import {
  type AdminTemplateListItem,
  type AdminTemplateOfTheDay,
  type TemplateOfTheDayPayload,
  type TemplateType,
} from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export const SEARCH_LIMIT = 80;
export const SEARCH_DEBOUNCE_MS = 300;
export const TEMPLATE_OPTIONS_TAKE = 30;
export const SCHEDULE_PAGE_SIZE = 30;

export function useDebouncedValue(value: string, delayMs: number) {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timeout = window.setTimeout(() => setDebouncedValue(value), delayMs);
    return () => window.clearTimeout(timeout);
  }, [delayMs, value]);

  return debouncedValue;
}

export function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

export function getBusinessDateOrClientToday(value: string | null | undefined) {
  const trimmed = value?.trim() ?? "";
  return /^\d{4}-\d{2}-\d{2}$/.test(trimmed) ? trimmed : todayIso();
}

export function emptyForm(date = todayIso()): AssignmentFormState {
  return {
    id: null,
    templateId: "",
    isManual: true,
    startDate: date,
    endDate: "",
    priority: "0",
    isActive: true,
    titleOverride: "",
    subtitleOverride: "",
    badgeTextOverride: "",
  };
}

export function parseExcludeRecentDays(value: string) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    return 7;
  }

  return Math.min(Math.max(parsed, 0), 365);
}

export function isExcludeRecentDaysValid(value: string) {
  return isIntegerInRange(value, 0, 365);
}

export function isPriorityValid(value: string) {
  return isIntegerInRange(value, -2147483648, 2147483647);
}

export function toPayload(form: AssignmentFormState): TemplateOfTheDayPayload {
  return {
    templateId: form.templateId,
    startDate: form.startDate,
    endDate: form.endDate.trim() || null,
    isActive: form.isActive,
    isManual: form.isManual,
    priority: Number.parseInt(form.priority, 10),
    titleOverride: form.titleOverride.trim() || null,
    subtitleOverride: form.subtitleOverride.trim() || null,
    badgeTextOverride: form.badgeTextOverride.trim() || null,
  };
}

export function formFromAssignment(assignment: AdminTemplateOfTheDay): AssignmentFormState {
  return {
    id: assignment.id,
    templateId: assignment.templateId,
    isManual: assignment.isManual,
    startDate: assignment.startDate,
    endDate: assignment.endDate ?? "",
    priority: String(assignment.priority),
    isActive: assignment.isActive,
    titleOverride: assignment.titleOverride ?? "",
    subtitleOverride: assignment.subtitleOverride ?? "",
    badgeTextOverride: assignment.badgeTextOverride ?? "",
  };
}

export function isVideoTemplate(type: TemplateType | string) {
  return type === "Video";
}

export function getPreviewUrl(
  template?: TemplateOption | AdminTemplateListItem | AdminTemplateOfTheDay | null
) {
  return template?.previewAsset?.url?.trim() || null;
}

export function optionFromTemplate(template: AdminTemplateListItem): TemplateOption {
  return {
    templateId: template.templateId,
    templateType: template.templateType,
    title: template.title,
    shortDescription: template.shortDescription,
    category: template.category,
    isPremium: template.isPremium,
    previewAsset: template.previewAsset,
  };
}

export function optionFromAssignment(assignment: AdminTemplateOfTheDay): TemplateOption {
  return {
    templateId: assignment.templateId,
    templateType: assignment.templateType,
    title: assignment.templateTitle,
    shortDescription: assignment.subtitleOverride ?? "",
    category: assignment.category,
    isPremium: assignment.isPremium,
    previewAsset: assignment.previewAsset ?? undefined,
  };
}

export function statusTone(assignment: AdminTemplateOfTheDay) {
  if (!assignment.isActive) return "neutral" as const;
  if (assignment.isManual) return "success" as const;
  return "info" as const;
}

export function formatDateRange(assignment: AdminTemplateOfTheDay, locale: Locale) {
  return assignment.endDate
    ? `${formatDateOnly(assignment.startDate, locale)} - ${formatDateOnly(assignment.endDate, locale)}`
    : formatDateOnly(assignment.startDate, locale);
}

function formatDateOnly(value: string, locale: Locale) {
  const trimmed = value.trim();
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(trimmed);

  if (!match) {
    return safeDisplayText(trimmed, 32);
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));

  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return safeDisplayText(trimmed, 32);
  }

  return new Intl.DateTimeFormat(getTemplatesDailyFeaturedPageIntlLocale(locale), {
    dateStyle: "medium",
    timeZone: "UTC",
  }).format(date);
}

export function safeDisplayText(value: string | null | undefined, maxLength = 120) {
  return sanitizeSensitiveText(value, maxLength);
}

export function safeErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export function safeActionContext(input: {
  assignmentId?: string | null;
  templateId?: string | null;
  templateTitle?: string | null;
}) {
  return {
    assignmentId: input.assignmentId ? sanitizeSensitiveText(input.assignmentId, 80) : undefined,
    templateId: input.templateId ? sanitizeSensitiveText(input.templateId, 80) : undefined,
    templateTitle: input.templateTitle ? sanitizeSensitiveText(input.templateTitle, 96) : undefined,
  };
}

export function dateRangesOverlap(
  startDate: string,
  endDate: string,
  assignment: AdminTemplateOfTheDay
) {
  const requestedStart = startDate || todayIso();
  const requestedEnd = endDate.trim() || "9999-12-31";
  const assignmentEnd = assignment.endDate ?? "9999-12-31";
  return assignment.startDate <= requestedEnd && assignmentEnd >= requestedStart;
}

export function hasInvalidDateRange(startDate: string, endDate: string) {
  return endDate.trim().length > 0 && endDate.trim() < (startDate || todayIso());
}

function isIntegerInRange(value: string, min: number, max: number) {
  const trimmed = value.trim();
  if (!/^-?\d+$/.test(trimmed)) {
    return false;
  }

  const parsed = Number(trimmed);
  return Number.isSafeInteger(parsed) && parsed >= min && parsed <= max;
}
