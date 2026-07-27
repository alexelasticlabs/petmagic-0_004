import {
  apiRequest,
  cachedAdminTemplateEventAnalytics,
  cachedAdminTemplateFailureBreakdowns,
  cachedAdminTemplateRecentGenerations,
  cachedAdminTemplateStatistics,
  cachedAdminTemplateTrends,
  cachedGet,
  cachedTemplateCategories,
  cachedTemplateLists,
  cachedTemplatesAnalyticsOverview,
  clearAdminListCaches,
  encodePathSegment,
  getAnalyticsOverviewCacheKey,
  getTemplateListCacheKey,
  getTemplateRecentGenerationsCacheKey,
  invalidateCachedGetNamespaces,
} from "./api-client.core";

import type {
  AdminTemplate,
  AdminTemplateCatalogPage,
  AdminTemplateCategory,
  AdminTemplateEventAnalytics,
  AdminTemplateFailureBreakdownItem,
  AdminTemplateFeedbackItem,
  AdminTemplateFeedbackQuery,
  AdminTemplateOfTheDay,
  AdminTemplateOfTheDaySchedule,
  AdminTemplateOfTheDaySettings,
  AdminModerationQueueItem,
  AdminModerationQueuePage,
  AdminModerationQueueQuery,
  AdminTemplateGenerationDashboardMetrics,
  AdminGenerationDetail,
  AdminGamificationLegacyDeliveryResolutionAction,
  AdminGamificationLegacyDeliveryResolutionResponse,
  AdminTemplateGenerationsPage,
  AdminTemplateGenerationsQuery,
  AdminWatermarkSettings,
  RemoveGenerationWatermarkResponse,
  TemplateGenerationResponse,
  AdminTemplateRecentGeneration,
  AdminTemplateStatistics,
  AdminTemplateTestRun,
  AdminTemplateTrendPoint,
  AdminTemplatesAnalyticsOverview,
  AdminTemplatesAnalyticsQuery,
  ImageTemplatePayload,
  TemplateAsset,
  TemplateAssetKind,
  TemplateCategoryPayload,
  TemplateOfTheDayAutoPickPayload,
  TemplateOfTheDayPayload,
  TemplateOfTheDayScheduleQuery,
  TemplateOfTheDaySettingsPayload,
  TemplateStatus,
  TemplateType,
  VideoTemplatePayload,
} from "./api-client.types";

export const MODERATION_SEARCH_MAX_LENGTH = 120;
export const MODERATION_DECISION_REASON_MAX_LENGTH = 500;
export const GAMIFICATION_LEGACY_DELIVERY_REASON_MAX_LENGTH = 1000;
export const GENERATION_PROVIDER_FILTER_MAX_LENGTH = 40;
export const GENERATION_USER_FILTER_MAX_LENGTH = 80;
export const GENERATION_SEARCH_FILTER_MAX_LENGTH = 80;
export const TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH = 120;
export const TEMPLATE_CATALOG_SEARCH_MAX_LENGTH = 120;
export const TEMPLATE_ANALYTICS_TEMPLATE_ID_MAX_LENGTH = 80;
export const TEMPLATE_ANALYTICS_TEMPLATE_IDS_MAX_COUNT = 100;

export type AdminTemplateCatalogQuery = {
  type?: TemplateType;
  status?: TemplateStatus | "not_archived";
  search?: string;
  category?: string;
  access?: "premium" | "free";
  visibility?: "public" | "qa_only";
  readiness?: "ready" | "missing_preview";
  sort?: "newest" | "title" | "tokens";
  skip?: number;
  take?: number;
};

const TEMPLATE_TYPES = ["Image", "Video"] as const;
const TEMPLATE_STATUSES = ["Draft", "Active", "Archived"] as const;
const TEMPLATE_CATALOG_STATUSES = ["Draft", "Active", "Archived", "not_archived"] as const;
const TEMPLATE_CATALOG_ACCESS = ["premium", "free"] as const;
const TEMPLATE_CATALOG_VISIBILITY = ["public", "qa_only"] as const;
const TEMPLATE_CATALOG_READINESS = ["ready", "missing_preview"] as const;
const TEMPLATE_CATALOG_SORTS = ["newest", "title", "tokens"] as const;
const TEMPLATE_FEEDBACK_TYPES = ["complaint", "feedback"] as const;
const TEMPLATE_ANALYTICS_ACCESS = ["free", "premium"] as const;
const TEMPLATE_ANALYTICS_SORTS = [
  "views",
  "starts",
  "conversion",
  "cost",
  "tokens",
  "updated",
] as const;

function normalizeTemplateCatalogFilter(value: string | undefined): string | undefined {
  return value?.trim().slice(0, TEMPLATE_CATALOG_SEARCH_MAX_LENGTH) || undefined;
}

function normalizeAnalyticsTemplateIds(values: string[] | undefined): string[] | undefined {
  if (!Array.isArray(values)) {
    return undefined;
  }

  const normalizedIds = new Set<string>();
  for (const value of values) {
    if (typeof value !== "string") {
      continue;
    }

    const normalized = value.trim().slice(0, TEMPLATE_ANALYTICS_TEMPLATE_ID_MAX_LENGTH);
    if (normalized) {
      normalizedIds.add(normalized);
    }
  }

  const result = [...normalizedIds].sort().slice(0, TEMPLATE_ANALYTICS_TEMPLATE_IDS_MAX_COUNT);
  return result.length > 0 ? result : undefined;
}

function normalizeTemplateFeedbackFilter(value: string | undefined): string | undefined {
  return value?.trim().slice(0, TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH) || undefined;
}

function normalizeAllowed<const T extends string>(
  value: string | undefined,
  allowed: readonly T[]
): T | undefined {
  const normalized = value?.trim();
  return normalized && allowed.includes(normalized as T) ? (normalized as T) : undefined;
}

function normalizeTemplateCatalogPagedValue(value: number | undefined): number | undefined {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.max(0, Math.floor(value))
    : undefined;
}

function normalizeTemplateCatalogTakeValue(value: number | undefined): number | undefined {
  return typeof value === "number" && Number.isFinite(value) && value > 0
    ? Math.min(Math.floor(value), 100)
    : undefined;
}

function deleteTemplateRecentGenerationCaches(templateId: string): void {
  const prefix = `admin-template-recent:${templateId}:`;
  for (const key of cachedAdminTemplateRecentGenerations.keys()) {
    if (key.startsWith(prefix)) {
      cachedAdminTemplateRecentGenerations.delete(key);
    }
  }
}

function clearAdminTemplateMutationCaches(templateId?: string): void {
  invalidateCachedGetNamespaces([
    "templates",
    "template-categories",
    "templates-analytics",
    "admin-template-statistics",
    "admin-template-trends",
    "admin-template-recent",
    "admin-template-failures",
    "admin-template-events",
  ]);
  cachedTemplateLists.clear();
  cachedTemplateCategories.clear();
  cachedTemplatesAnalyticsOverview.clear();

  if (!templateId) {
    return;
  }

  const statisticsKey = `admin-template-statistics:${templateId}`;
  const trendsKey = `admin-template-trends:${templateId}`;
  const failuresKey = `admin-template-failures:${templateId}`;
  const eventsKey = `admin-template-events:${templateId}`;

  cachedAdminTemplateStatistics.delete(statisticsKey);
  cachedAdminTemplateTrends.delete(trendsKey);
  cachedAdminTemplateFailureBreakdowns.delete(failuresKey);
  cachedAdminTemplateEventAnalytics.delete(eventsKey);
  deleteTemplateRecentGenerationCaches(templateId);
}

export function normalizeAdminTemplateCatalogQuery(
  query: AdminTemplateCatalogQuery = {}
): AdminTemplateCatalogQuery {
  return {
    type: normalizeAllowed(query.type, TEMPLATE_TYPES),
    status: normalizeAllowed(query.status, TEMPLATE_CATALOG_STATUSES),
    search: normalizeTemplateCatalogFilter(query.search),
    category: normalizeTemplateCatalogFilter(query.category),
    access: normalizeAllowed(query.access, TEMPLATE_CATALOG_ACCESS),
    visibility: normalizeAllowed(query.visibility, TEMPLATE_CATALOG_VISIBILITY),
    readiness: normalizeAllowed(query.readiness, TEMPLATE_CATALOG_READINESS),
    sort: normalizeAllowed(query.sort, TEMPLATE_CATALOG_SORTS),
    skip: normalizeTemplateCatalogPagedValue(query.skip),
    take: normalizeTemplateCatalogTakeValue(query.take),
  };
}

export function normalizeTemplateOfTheDayScheduleQuery(
  query: TemplateOfTheDayScheduleQuery = {}
): TemplateOfTheDayScheduleQuery {
  return {
    skip: normalizeTemplateCatalogPagedValue(query.skip),
    take: normalizeTemplateCatalogTakeValue(query.take),
  };
}

export function normalizeAdminTemplatesAnalyticsQuery(
  query: AdminTemplatesAnalyticsQuery = {}
): AdminTemplatesAnalyticsQuery {
  return {
    periodDays:
      typeof query.periodDays === "number" &&
      Number.isFinite(query.periodDays) &&
      query.periodDays > 0
        ? Math.min(3650, Math.floor(query.periodDays))
        : undefined,
    templateType:
      query.templateType === "All"
        ? undefined
        : normalizeAllowed(query.templateType, TEMPLATE_TYPES),
    templateIds: normalizeAnalyticsTemplateIds(query.templateIds),
    category: normalizeTemplateCatalogFilter(query.category),
    status: query.status === "All" ? undefined : normalizeAllowed(query.status, TEMPLATE_STATUSES),
    access:
      query.access === "all"
        ? undefined
        : normalizeAllowed(query.access, TEMPLATE_ANALYTICS_ACCESS),
    sort: normalizeAllowed(query.sort, TEMPLATE_ANALYTICS_SORTS),
    skip: normalizeTemplateCatalogPagedValue(query.skip),
    take:
      typeof query.take === "number" && Number.isFinite(query.take) && query.take > 0
        ? Math.min(200, Math.floor(query.take))
        : undefined,
  };
}

export async function fetchAdminTemplates(
  query: AdminTemplateCatalogQuery = {},
  signal?: AbortSignal
): Promise<AdminTemplateCatalogPage> {
  const normalizedQuery = normalizeAdminTemplateCatalogQuery(query);
  const cacheKey = getTemplateListCacheKey(JSON.stringify(normalizedQuery));
  const search = new URLSearchParams();
  if (normalizedQuery.type) search.set("type", normalizedQuery.type);
  if (normalizedQuery.status) search.set("status", normalizedQuery.status);
  if (normalizedQuery.search) search.set("search", normalizedQuery.search);
  if (normalizedQuery.category) search.set("category", normalizedQuery.category);
  if (normalizedQuery.access) search.set("access", normalizedQuery.access);
  if (normalizedQuery.visibility) search.set("visibility", normalizedQuery.visibility);
  if (normalizedQuery.readiness) search.set("readiness", normalizedQuery.readiness);
  if (normalizedQuery.sort) search.set("sort", normalizedQuery.sort);
  if (normalizedQuery.skip !== undefined) search.set("skip", String(normalizedQuery.skip));
  if (normalizedQuery.take !== undefined) search.set("take", String(normalizedQuery.take));
  const queryString = search.size ? `?${search.toString()}` : "";

  return cachedGet(
    `templates:${cacheKey}`,
    cachedTemplateLists,
    () =>
      apiRequest<AdminTemplateCatalogPage>(`/api/admin/templates/${queryString}`, {
        method: "GET",
        signal,
      }),
    signal
  );
}

export async function fetchAdminTemplateCategories(
  includeArchived = true,
  signal?: AbortSignal
): Promise<AdminTemplateCategory[]> {
  const cacheKey = includeArchived ? "archived" : "active";
  const query = includeArchived ? "?includeArchived=true" : "?includeArchived=false";

  return cachedGet(
    `template-categories:${cacheKey}`,
    cachedTemplateCategories,
    () =>
      apiRequest<AdminTemplateCategory[]>(`/api/admin/templates/categories/${query}`, {
        method: "GET",
        signal,
      }),
    signal
  );
}

export async function fetchTemplateOfTheDaySchedule(
  query: TemplateOfTheDayScheduleQuery = {},
  signal?: AbortSignal
): Promise<AdminTemplateOfTheDaySchedule> {
  const normalizedQuery = normalizeTemplateOfTheDayScheduleQuery(query);
  const params = new URLSearchParams();
  if (typeof normalizedQuery.skip === "number") params.set("skip", String(normalizedQuery.skip));
  if (typeof normalizedQuery.take === "number") params.set("take", String(normalizedQuery.take));
  const suffix = params.size > 0 ? `?${params.toString()}` : "";

  return apiRequest<AdminTemplateOfTheDaySchedule>(
    `/api/admin/template-of-the-day/schedule${suffix}`,
    {
      method: "GET",
      signal,
    }
  );
}

export async function fetchCurrentTemplateOfTheDay(
  date?: string,
  signal?: AbortSignal
): Promise<AdminTemplateOfTheDay | null> {
  const query = date ? `?date=${encodeURIComponent(date)}` : "";
  return apiRequest<AdminTemplateOfTheDay | null>(
    `/api/admin/template-of-the-day/current${query}`,
    {
      method: "GET",
      signal,
    }
  );
}

export async function fetchTemplateOfTheDaySettings(
  signal?: AbortSignal
): Promise<AdminTemplateOfTheDaySettings> {
  return apiRequest<AdminTemplateOfTheDaySettings>("/api/admin/template-of-the-day/settings", {
    method: "GET",
    signal,
  });
}

export async function updateTemplateOfTheDaySettings(
  payload: TemplateOfTheDaySettingsPayload
): Promise<AdminTemplateOfTheDaySettings> {
  return apiRequest<AdminTemplateOfTheDaySettings>("/api/admin/template-of-the-day/settings", {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export async function createTemplateOfTheDay(
  payload: TemplateOfTheDayPayload
): Promise<AdminTemplateOfTheDay> {
  const item = await apiRequest<AdminTemplateOfTheDay>("/api/admin/template-of-the-day", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  clearAdminListCaches();
  return item;
}

export async function updateTemplateOfTheDay(
  id: string,
  payload: TemplateOfTheDayPayload
): Promise<AdminTemplateOfTheDay> {
  const encodedId = encodePathSegment(id);
  const item = await apiRequest<AdminTemplateOfTheDay>(
    `/api/admin/template-of-the-day/${encodedId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );
  clearAdminListCaches();
  return item;
}

export async function deleteTemplateOfTheDay(id: string): Promise<void> {
  const encodedId = encodePathSegment(id);
  await apiRequest<void>(`/api/admin/template-of-the-day/${encodedId}`, {
    method: "DELETE",
  });
  clearAdminListCaches();
}

export async function autoPickTemplateOfTheDay(
  payload: TemplateOfTheDayAutoPickPayload
): Promise<AdminTemplateOfTheDay> {
  const item = await apiRequest<AdminTemplateOfTheDay>("/api/admin/template-of-the-day/auto-pick", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  clearAdminListCaches();
  return item;
}

export async function createTemplateCategory(
  payload: TemplateCategoryPayload
): Promise<AdminTemplateCategory> {
  const category = await apiRequest<AdminTemplateCategory>("/api/admin/templates/categories/", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  clearAdminListCaches();
  return category;
}

export async function updateTemplateCategory(
  categoryId: string,
  payload: TemplateCategoryPayload
): Promise<AdminTemplateCategory> {
  const encodedCategoryId = encodePathSegment(categoryId);
  const category = await apiRequest<AdminTemplateCategory>(
    `/api/admin/templates/categories/${encodedCategoryId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );
  clearAdminListCaches();
  return category;
}

export async function changeTemplateCategoryArchiveState(
  categoryId: string,
  isArchived: boolean
): Promise<AdminTemplateCategory> {
  const encodedCategoryId = encodePathSegment(categoryId);
  const category = await apiRequest<AdminTemplateCategory>(
    `/api/admin/templates/categories/${encodedCategoryId}/archive`,
    {
      method: "PUT",
      body: JSON.stringify({ isArchived }),
    }
  );
  clearAdminListCaches();
  return category;
}

export async function deleteTemplateCategory(categoryId: string): Promise<void> {
  const encodedCategoryId = encodePathSegment(categoryId);
  await apiRequest<void>(`/api/admin/templates/categories/${encodedCategoryId}`, {
    method: "DELETE",
  });
  clearAdminListCaches();
}

export async function fetchAdminTemplate(
  templateId: string,
  signal?: AbortSignal
): Promise<AdminTemplate> {
  const encodedTemplateId = encodePathSegment(templateId);
  return apiRequest<AdminTemplate>(`/api/admin/templates/${encodedTemplateId}`, {
    method: "GET",
    signal,
  });
}

export async function fetchAdminTemplateStatistics(
  templateId: string,
  signal?: AbortSignal
): Promise<AdminTemplateStatistics> {
  const encodedTemplateId = encodePathSegment(templateId);
  return cachedGet(
    `admin-template-statistics:${templateId}`,
    cachedAdminTemplateStatistics,
    () =>
      apiRequest<AdminTemplateStatistics>(`/api/admin/templates/${encodedTemplateId}/statistics`, {
        method: "GET",
        signal,
      }),
    signal
  );
}

export async function fetchAdminTemplateTrends(
  templateId: string,
  signal?: AbortSignal
): Promise<AdminTemplateTrendPoint[]> {
  const encodedTemplateId = encodePathSegment(templateId);
  return cachedGet(
    `admin-template-trends:${templateId}`,
    cachedAdminTemplateTrends,
    () =>
      apiRequest<AdminTemplateTrendPoint[]>(
        `/api/admin/templates/${encodedTemplateId}/statistics/trends`,
        {
          method: "GET",
          signal,
        }
      ),
    signal
  );
}

export async function fetchAdminTemplateRecentGenerations(
  templateId: string,
  take?: number,
  signal?: AbortSignal
): Promise<AdminTemplateRecentGeneration[]> {
  const encodedTemplateId = encodePathSegment(templateId);
  const normalizedTake =
    typeof take === "number" && Number.isFinite(take) && take > 0
      ? Math.min(Math.floor(take), 100)
      : undefined;
  const query =
    typeof normalizedTake === "number" ? `?take=${encodeURIComponent(String(normalizedTake))}` : "";
  return cachedGet(
    `admin-template-recent:${getTemplateRecentGenerationsCacheKey(templateId, normalizedTake)}`,
    cachedAdminTemplateRecentGenerations,
    () =>
      apiRequest<AdminTemplateRecentGeneration[]>(
        `/api/admin/templates/${encodedTemplateId}/statistics/recent${query}`,
        { method: "GET", signal }
      ),
    signal
  );
}

export async function fetchAdminTemplateFailureBreakdown(
  templateId: string,
  signal?: AbortSignal
): Promise<AdminTemplateFailureBreakdownItem[]> {
  const encodedTemplateId = encodePathSegment(templateId);
  return cachedGet(
    `admin-template-failures:${templateId}`,
    cachedAdminTemplateFailureBreakdowns,
    () =>
      apiRequest<AdminTemplateFailureBreakdownItem[]>(
        `/api/admin/templates/${encodedTemplateId}/statistics/failures`,
        { method: "GET", signal }
      ),
    signal
  );
}

export async function fetchAdminTemplateEventAnalytics(
  templateId: string,
  signal?: AbortSignal
): Promise<AdminTemplateEventAnalytics> {
  const encodedTemplateId = encodePathSegment(templateId);
  return cachedGet(
    `admin-template-events:${templateId}`,
    cachedAdminTemplateEventAnalytics,
    () =>
      apiRequest<AdminTemplateEventAnalytics>(
        `/api/admin/templates/${encodedTemplateId}/statistics/events`,
        { method: "GET", signal }
      ),
    signal
  );
}

export async function fetchAdminTemplateFeedback(
  templateId: string,
  query: AdminTemplateFeedbackQuery = {},
  signal?: AbortSignal
): Promise<AdminTemplateFeedbackItem[]> {
  const encodedTemplateId = encodePathSegment(templateId);
  const params = new URLSearchParams();
  const take = normalizeTemplateCatalogTakeValue(query.take);
  const type = normalizeAllowed(query.type, TEMPLATE_FEEDBACK_TYPES);
  const search = normalizeTemplateFeedbackFilter(query.search);
  if (take !== undefined) params.set("take", String(take));
  if (type) params.set("type", type);
  if (search) params.set("search", search);
  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<AdminTemplateFeedbackItem[]>(
    `/api/admin/templates/${encodedTemplateId}/statistics/feedback${suffix}`,
    { method: "GET", signal }
  );
}

export async function fetchAdminModerationQueue(
  query: AdminModerationQueueQuery = {},
  signal?: AbortSignal
): Promise<AdminModerationQueuePage> {
  const normalizedQuery = normalizeAdminModerationQueueQuery(query);
  const params = new URLSearchParams();
  if (normalizedQuery.status) params.set("status", normalizedQuery.status);
  if (normalizedQuery.search) params.set("search", normalizedQuery.search);
  if (typeof normalizedQuery.skip === "number") params.set("skip", String(normalizedQuery.skip));
  if (typeof normalizedQuery.take === "number") params.set("take", String(normalizedQuery.take));
  const suffix = params.size > 0 ? `?${params.toString()}` : "";

  return apiRequest<AdminModerationQueuePage>(`/api/admin/templates/moderation${suffix}`, {
    method: "GET",
    signal,
  });
}

export function normalizeAdminModerationQueueQuery(
  query: AdminModerationQueueQuery = {}
): AdminModerationQueueQuery {
  return {
    status: query.status && query.status !== "all" ? query.status : undefined,
    search: query.search?.trim().slice(0, MODERATION_SEARCH_MAX_LENGTH) || undefined,
    skip:
      typeof query.skip === "number" && Number.isFinite(query.skip)
        ? Math.max(0, Math.floor(query.skip))
        : undefined,
    take:
      typeof query.take === "number" && Number.isFinite(query.take) && query.take > 0
        ? Math.min(Math.floor(query.take), 100)
        : undefined,
  };
}

export async function decideAdminModerationItem(
  eventId: string,
  payload: { action: "approve" | "reject"; reason: string; expectedVersion?: number }
): Promise<AdminModerationQueueItem> {
  const encodedEventId = encodePathSegment(eventId);
  const normalizedReason = payload.reason.trim().slice(0, MODERATION_DECISION_REASON_MAX_LENGTH);
  return apiRequest<AdminModerationQueueItem>(
    `/api/admin/templates/moderation/${encodedEventId}/decision`,
    {
      method: "POST",
      body: JSON.stringify({ ...payload, reason: normalizedReason }),
    }
  );
}

export async function claimAdminModerationItem(
  eventId: string,
  payload: { expectedVersion: number; leaseMinutes?: number }
): Promise<AdminModerationQueueItem> {
  const encodedEventId = encodePathSegment(eventId);
  return apiRequest<AdminModerationQueueItem>(
    `/api/admin/templates/moderation/${encodedEventId}/claim`,
    {
      method: "POST",
      body: JSON.stringify(payload),
    }
  );
}

export async function releaseAdminModerationItem(
  eventId: string,
  payload: { expectedVersion: number; reason: string }
): Promise<AdminModerationQueueItem> {
  const encodedEventId = encodePathSegment(eventId);
  return apiRequest<AdminModerationQueueItem>(
    `/api/admin/templates/moderation/${encodedEventId}/release`,
    {
      method: "POST",
      body: JSON.stringify({
        expectedVersion: payload.expectedVersion,
        reason: payload.reason.trim().slice(0, MODERATION_DECISION_REASON_MAX_LENGTH),
      }),
    }
  );
}

export async function handoffAdminModerationItem(
  eventId: string,
  payload: {
    assigneeUserId: string;
    expectedVersion: number;
    reason: string;
    leaseMinutes?: number;
  }
): Promise<AdminModerationQueueItem> {
  const encodedEventId = encodePathSegment(eventId);
  return apiRequest<AdminModerationQueueItem>(
    `/api/admin/templates/moderation/${encodedEventId}/handoff`,
    {
      method: "POST",
      body: JSON.stringify({
        ...payload,
        assigneeUserId: payload.assigneeUserId.trim(),
        reason: payload.reason.trim().slice(0, MODERATION_DECISION_REASON_MAX_LENGTH),
      }),
    }
  );
}

export async function fetchAdminTemplatesAnalyticsOverview(
  query: AdminTemplatesAnalyticsQuery = {},
  signal?: AbortSignal
): Promise<AdminTemplatesAnalyticsOverview> {
  const normalizedQuery = normalizeAdminTemplatesAnalyticsQuery(query);
  const params = new URLSearchParams();
  if (normalizedQuery.periodDays) params.set("periodDays", String(normalizedQuery.periodDays));
  if (normalizedQuery.templateType) params.set("templateType", normalizedQuery.templateType);
  for (const templateId of normalizedQuery.templateIds ?? []) {
    params.append("templateIds", templateId);
  }
  if (normalizedQuery.category) params.set("category", normalizedQuery.category);
  if (normalizedQuery.status) params.set("status", normalizedQuery.status);
  if (normalizedQuery.access) params.set("access", normalizedQuery.access);
  if (normalizedQuery.sort) params.set("sort", normalizedQuery.sort);
  if (normalizedQuery.skip !== undefined) params.set("skip", String(normalizedQuery.skip));
  if (normalizedQuery.take) params.set("take", String(normalizedQuery.take));

  const suffix = params.size > 0 ? `?${params.toString()}` : "";

  return cachedGet(
    `templates-analytics:${getAnalyticsOverviewCacheKey(normalizedQuery)}`,
    cachedTemplatesAnalyticsOverview,
    () =>
      apiRequest<AdminTemplatesAnalyticsOverview>(`/api/admin/templates/analytics${suffix}`, {
        method: "GET",
        signal,
      }),
    signal
  );
}

export async function fetchAdminTemplateGenerationMetrics(
  signal?: AbortSignal
): Promise<AdminTemplateGenerationDashboardMetrics> {
  return apiRequest<AdminTemplateGenerationDashboardMetrics>(
    "/api/admin/templates/generations/metrics",
    { method: "GET", signal }
  );
}

export const GENERATION_REFUND_RETRY_REASON_MAX_LENGTH = 500;

export function normalizeAdminTemplateGenerationsQuery(
  query: AdminTemplateGenerationsQuery = {}
): AdminTemplateGenerationsQuery {
  return {
    status: query.status && query.status !== "All" ? query.status : undefined,
    refundState: query.refundState && query.refundState !== "all" ? query.refundState : undefined,
    provider: query.provider?.trim().slice(0, GENERATION_PROVIDER_FILTER_MAX_LENGTH) || undefined,
    user: query.user?.trim().slice(0, GENERATION_USER_FILTER_MAX_LENGTH) || undefined,
    search: query.search?.trim().slice(0, GENERATION_SEARCH_FILTER_MAX_LENGTH) || undefined,
    skip:
      typeof query.skip === "number" && Number.isFinite(query.skip)
        ? Math.max(0, Math.floor(query.skip))
        : undefined,
    take:
      typeof query.take === "number" && Number.isFinite(query.take) && query.take > 0
        ? Math.min(Math.floor(query.take), 100)
        : undefined,
  };
}

export async function fetchAdminTemplateGenerations(
  query: AdminTemplateGenerationsQuery = {},
  signal?: AbortSignal
): Promise<AdminTemplateGenerationsPage> {
  const normalizedQuery = normalizeAdminTemplateGenerationsQuery(query);
  const params = new URLSearchParams();
  if (normalizedQuery.status) params.set("status", normalizedQuery.status);
  if (normalizedQuery.refundState) params.set("refundState", normalizedQuery.refundState);
  if (normalizedQuery.provider) params.set("provider", normalizedQuery.provider);
  if (normalizedQuery.user) params.set("user", normalizedQuery.user);
  if (normalizedQuery.search) params.set("search", normalizedQuery.search);
  if (typeof normalizedQuery.skip === "number") params.set("skip", String(normalizedQuery.skip));
  if (typeof normalizedQuery.take === "number") params.set("take", String(normalizedQuery.take));

  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<AdminTemplateGenerationsPage>(`/api/admin/templates/generations${suffix}`, {
    method: "GET",
    signal,
  });
}

export async function fetchAdminTemplateGenerationDetail(
  generationId: string,
  signal?: AbortSignal
): Promise<AdminGenerationDetail> {
  const encodedGenerationId = encodePathSegment(generationId);
  return apiRequest<AdminGenerationDetail>(
    `/api/admin/templates/generations/${encodedGenerationId}`,
    { method: "GET", signal }
  );
}

export async function startAdminTemplateTest(
  templateId: string,
  file: File
): Promise<AdminTemplateTestRun> {
  const encodedTemplateId = encodePathSegment(templateId);
  const formData = new FormData();
  formData.append("sourceImage", file);

  const run = await apiRequest<AdminTemplateTestRun>(
    `/api/admin/templates/${encodedTemplateId}/test`,
    {
      method: "POST",
      body: formData,
    }
  );
  return run;
}

export async function fetchAdminTemplateTest(
  generationId: string,
  signal?: AbortSignal
): Promise<AdminTemplateTestRun> {
  const encodedGenerationId = encodePathSegment(generationId);
  const run = await apiRequest<AdminTemplateTestRun>(
    `/api/admin/templates/tests/${encodedGenerationId}`,
    {
      method: "GET",
      signal,
    }
  );
  return run;
}

export async function fetchAdminTemplateTestHistory(
  templateId: string,
  take?: number,
  signal?: AbortSignal
): Promise<AdminTemplateTestRun[]> {
  const encodedTemplateId = encodePathSegment(templateId);
  const normalizedTake =
    typeof take === "number" && Number.isFinite(take) && take > 0
      ? Math.min(Math.floor(take), 100)
      : undefined;
  const query =
    typeof normalizedTake === "number" ? `?take=${encodeURIComponent(String(normalizedTake))}` : "";
  const runs = await apiRequest<AdminTemplateTestRun[]>(
    `/api/admin/templates/${encodedTemplateId}/tests${query}`,
    {
      method: "GET",
      signal,
    }
  );
  return runs;
}

export async function createImageTemplate(payload: ImageTemplatePayload): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>(
    "/api/admin/templates/image",
    {
      method: "POST",
      body: JSON.stringify(payload),
    },
    {
      timeoutMs: 60_000,
    }
  );
  clearAdminTemplateMutationCaches(template.templateId);
  return template;
}

export async function updateImageTemplate(
  templateId: string,
  payload: ImageTemplatePayload
): Promise<AdminTemplate> {
  const encodedTemplateId = encodePathSegment(templateId);
  const template = await apiRequest<AdminTemplate>(
    `/api/admin/templates/image/${encodedTemplateId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );
  clearAdminTemplateMutationCaches(templateId);
  return template;
}

export async function createVideoTemplate(payload: VideoTemplatePayload): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>(
    "/api/admin/templates/video",
    {
      method: "POST",
      body: JSON.stringify(payload),
    },
    {
      timeoutMs: 60_000,
    }
  );
  clearAdminTemplateMutationCaches(template.templateId);
  return template;
}

export async function updateVideoTemplate(
  templateId: string,
  payload: VideoTemplatePayload
): Promise<AdminTemplate> {
  const encodedTemplateId = encodePathSegment(templateId);
  const template = await apiRequest<AdminTemplate>(
    `/api/admin/templates/video/${encodedTemplateId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );
  clearAdminTemplateMutationCaches(templateId);
  return template;
}

export async function changeTemplateStatus(
  templateId: string,
  status: TemplateStatus
): Promise<AdminTemplate> {
  const encodedTemplateId = encodePathSegment(templateId);
  const template = await apiRequest<AdminTemplate>(
    `/api/admin/templates/${encodedTemplateId}/status`,
    {
      method: "PUT",
      body: JSON.stringify({ status }),
    }
  );
  clearAdminTemplateMutationCaches(templateId);
  return template;
}

export async function deleteTemplate(templateId: string): Promise<void> {
  const encodedTemplateId = encodePathSegment(templateId);
  await apiRequest<void>(`/api/admin/templates/${encodedTemplateId}`, {
    method: "DELETE",
  });
  clearAdminTemplateMutationCaches(templateId);
}

export async function uploadTemplateMedia(
  file: File,
  assetKind: TemplateAssetKind,
  options?: {
    durationSeconds?: number;
  }
): Promise<TemplateAsset> {
  const formData = new FormData();
  formData.append("file", file);
  formData.append("assetKind", assetKind);
  if (
    typeof options?.durationSeconds === "number" &&
    Number.isFinite(options.durationSeconds) &&
    options.durationSeconds > 0
  ) {
    formData.append("durationSeconds", options.durationSeconds.toString());
  }

  return apiRequest<TemplateAsset>(
    "/api/admin/templates/media/upload",
    {
      method: "POST",
      body: formData,
    },
    {
      timeoutMs: 120_000,
    }
  );
}

export async function fetchAdminWatermarkSettings(
  signal?: AbortSignal
): Promise<AdminWatermarkSettings> {
  return apiRequest<AdminWatermarkSettings>("/api/admin/templates/monetization/watermark", {
    method: "GET",
    signal,
  });
}

export async function updateAdminWatermarkSettings(
  payload: AdminWatermarkSettings
): Promise<AdminWatermarkSettings> {
  return apiRequest<AdminWatermarkSettings>("/api/admin/templates/monetization/watermark", {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export async function grantAdminGenerationCleanDownload(
  generationId: string
): Promise<RemoveGenerationWatermarkResponse> {
  const encodedGenerationId = encodePathSegment(generationId);
  return apiRequest<RemoveGenerationWatermarkResponse>(
    `/api/admin/templates/generations/${encodedGenerationId}/grant-clean-download`,
    { method: "POST" }
  );
}

export async function cancelAdminTemplateGeneration(
  generationId: string
): Promise<TemplateGenerationResponse> {
  const encodedGenerationId = encodePathSegment(generationId);
  return apiRequest<TemplateGenerationResponse>(
    `/api/admin/templates/generations/${encodedGenerationId}/cancel`,
    { method: "POST" }
  );
}

export async function retryAdminTemplateGeneration(
  generationId: string
): Promise<TemplateGenerationResponse> {
  const encodedGenerationId = encodePathSegment(generationId);
  return apiRequest<TemplateGenerationResponse>(
    `/api/admin/templates/generations/${encodedGenerationId}/retry`,
    { method: "POST" }
  );
}

export async function retryAdminTemplateGenerationRefund(payload: {
  generationId: string;
  reason: string;
  idempotencyKey: string;
}): Promise<TemplateGenerationResponse> {
  const encodedGenerationId = encodePathSegment(payload.generationId);
  const reason = payload.reason.trim().slice(0, GENERATION_REFUND_RETRY_REASON_MAX_LENGTH);
  const idempotencyKey = payload.idempotencyKey.trim().slice(0, 256);
  return apiRequest<TemplateGenerationResponse>(
    `/api/admin/templates/generations/${encodedGenerationId}/retry-refund`,
    {
      method: "POST",
      headers: idempotencyKey ? { "Idempotency-Key": idempotencyKey } : undefined,
      body: JSON.stringify({ reason }),
    }
  );
}

export async function resolveAdminLegacyGamificationDelivery(
  generationId: string,
  payload: { action: AdminGamificationLegacyDeliveryResolutionAction; reason: string }
): Promise<AdminGamificationLegacyDeliveryResolutionResponse> {
  const encodedGenerationId = encodePathSegment(generationId);
  const reason = payload.reason.trim().slice(0, GAMIFICATION_LEGACY_DELIVERY_REASON_MAX_LENGTH);
  return apiRequest<AdminGamificationLegacyDeliveryResolutionResponse>(
    `/api/admin/templates/generations/${encodedGenerationId}/resolve-legacy-gamification`,
    {
      method: "POST",
      body: JSON.stringify({ ...payload, reason }),
    }
  );
}
