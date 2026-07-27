import { apiRequest, encodePathSegment } from "./api-client.core";

import type {
  AdminAuditCategory,
  AdminAuditEventDetail,
  AdminAuditEventsPage,
} from "./api-client.types";

export type FetchAdminAuditEventsQuery = {
  skip?: number;
  take?: number;
  search?: string;
  category?: AdminAuditCategory;
  actorUserId?: string;
  subjectUserId?: string;
  fromUtc?: string;
  toUtc?: string;
};

export const ADMIN_AUDIT_PAGE_MAX_TAKE = 100;
export const ADMIN_AUDIT_SEARCH_MAX_LENGTH = 120;

const allowedCategories: readonly AdminAuditCategory[] = [
  "identity",
  "economy",
  "content",
  "support",
  "gamification",
  "system",
];

function normalizeOptionalText(value: string | undefined, maxLength: number): string | undefined {
  const normalized = value?.trim().slice(0, maxLength);
  return normalized || undefined;
}

function normalizeIsoDate(value: string | undefined): string | undefined {
  const normalized = value?.trim();
  if (!normalized) {
    return undefined;
  }

  const timestamp = Date.parse(normalized);
  return Number.isNaN(timestamp) ? undefined : new Date(timestamp).toISOString();
}

export function normalizeAdminAuditEventsQuery(
  query: FetchAdminAuditEventsQuery = {}
): FetchAdminAuditEventsQuery {
  const normalizedCategory = query.category?.trim().toLowerCase();
  const category = allowedCategories.find((item) => item === normalizedCategory);

  return {
    skip:
      typeof query.skip === "number" && Number.isFinite(query.skip)
        ? Math.max(0, Math.floor(query.skip))
        : 0,
    take:
      typeof query.take === "number" && Number.isFinite(query.take) && query.take > 0
        ? Math.min(Math.floor(query.take), ADMIN_AUDIT_PAGE_MAX_TAKE)
        : 25,
    search: normalizeOptionalText(query.search, ADMIN_AUDIT_SEARCH_MAX_LENGTH),
    category,
    actorUserId: normalizeOptionalText(query.actorUserId, 36),
    subjectUserId: normalizeOptionalText(query.subjectUserId, 36),
    fromUtc: normalizeIsoDate(query.fromUtc),
    toUtc: normalizeIsoDate(query.toUtc),
  };
}

export function buildAdminAuditEventsPath(query: FetchAdminAuditEventsQuery = {}): string {
  const normalized = normalizeAdminAuditEventsQuery(query);
  const params = new URLSearchParams();
  params.set("skip", String(normalized.skip ?? 0));
  params.set("take", String(normalized.take ?? 25));

  for (const [key, value] of [
    ["search", normalized.search],
    ["category", normalized.category],
    ["actorUserId", normalized.actorUserId],
    ["subjectUserId", normalized.subjectUserId],
    ["fromUtc", normalized.fromUtc],
    ["toUtc", normalized.toUtc],
  ] as const) {
    if (value) {
      params.set(key, value);
    }
  }

  return `/api/admin/audit-events?${params.toString()}`;
}

export async function fetchAdminAuditEvents(
  query: FetchAdminAuditEventsQuery = {},
  signal?: AbortSignal
): Promise<AdminAuditEventsPage> {
  return apiRequest<AdminAuditEventsPage>(buildAdminAuditEventsPath(query), {
    method: "GET",
    signal,
  });
}

export async function fetchAdminAuditEvent(
  auditEventId: string,
  signal?: AbortSignal
): Promise<AdminAuditEventDetail> {
  return apiRequest<AdminAuditEventDetail>(
    `/api/admin/audit-events/${encodePathSegment(auditEventId.trim())}`,
    {
      method: "GET",
      signal,
    }
  );
}
