import { useEffect, useState } from "react";

import {
  type AdminTemplateListItem,
  type AdminTemplateOfTheDay,
  type TemplateOfTheDayPayload,
  type TemplateType,
} from "@/lib/api-client";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

import type {
  AssignmentFormState,
  TemplateOption,
} from "@/components/templates/templates-daily-featured-page.types";

export const SEARCH_LIMIT = 80;
export const SEARCH_DEBOUNCE_MS = 300;
export const TEMPLATE_OPTIONS_TAKE = 30;

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

export function emptyForm(date = todayIso()): AssignmentFormState {
  return {
    id: null,
    templateId: "",
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

export function toPayload(form: AssignmentFormState): TemplateOfTheDayPayload {
  return {
    templateId: form.templateId,
    startDate: form.startDate,
    endDate: form.endDate.trim() || null,
    isActive: form.isActive,
    isManual: true,
    priority: Number.parseInt(form.priority || "0", 10) || 0,
    titleOverride: form.titleOverride.trim() || null,
    subtitleOverride: form.subtitleOverride.trim() || null,
    badgeTextOverride: form.badgeTextOverride.trim() || null,
  };
}

export function formFromAssignment(assignment: AdminTemplateOfTheDay): AssignmentFormState {
  return {
    id: assignment.id,
    templateId: assignment.templateId,
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

export function formatDateRange(assignment: AdminTemplateOfTheDay) {
  return assignment.endDate
    ? `${assignment.startDate} - ${assignment.endDate}`
    : assignment.startDate;
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
