import {
  apiRequest,
  cachedAdminTemplateDetails,
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
  AdminTemplateGenerationsPage,
  AdminTemplateGenerationsQuery,
  AdminWatermarkSettings,
  RemoveGenerationWatermarkResponse,
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
  TemplateOfTheDaySettingsPayload,
  TemplateStatus,
  TemplateType,
  VideoTemplatePayload,
} from "./api-client.types";

export const MODERATION_SEARCH_MAX_LENGTH = 120;
export const MODERATION_DECISION_REASON_MAX_LENGTH = 500;
export const GENERATION_PROVIDER_FILTER_MAX_LENGTH = 40;
export const GENERATION_USER_FILTER_MAX_LENGTH = 80;
export const GENERATION_SEARCH_FILTER_MAX_LENGTH = 80;
export const TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH = 120;
export const TEMPLATE_CATALOG_SEARCH_MAX_LENGTH = 120;

export type AdminTemplateCatalogQuery = {
  type?: TemplateType;
  status?: TemplateStatus | "not_archived";
  search?: string;
  category?: string;
  access?: "premium" | "free";
  sort?: "newest" | "title" | "tokens";
  skip?: number;
  take?: number;
};

function normalizeTemplateCatalogFilter(value: string | undefined): string | undefined {
  return value?.trim().slice(0, TEMPLATE_CATALOG_SEARCH_MAX_LENGTH) || undefined;
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

export function normalizeAdminTemplateCatalogQuery(
  query: AdminTemplateCatalogQuery = {}
): AdminTemplateCatalogQuery {
  return {
    type: query.type,
    status: query.status,
    search: normalizeTemplateCatalogFilter(query.search),
    category: normalizeTemplateCatalogFilter(query.category),
    access: query.access,
    sort: query.sort,
    skip: normalizeTemplateCatalogPagedValue(query.skip),
    take: normalizeTemplateCatalogTakeValue(query.take),
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
  signal?: AbortSignal
): Promise<AdminTemplateOfTheDaySchedule> {
  return apiRequest<AdminTemplateOfTheDaySchedule>("/api/admin/template-of-the-day/schedule", {
    method: "GET",
    signal,
  });
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
  return cachedGet(
    `admin-template:${templateId}`,
    cachedAdminTemplateDetails,
    () =>
      apiRequest<AdminTemplate>(`/api/admin/templates/${encodedTemplateId}`, {
        method: "GET",
        signal,
      }),
    signal
  );
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
  if (query.take) params.set("take", String(query.take));
  if (query.type) params.set("type", query.type);
  const search = query.search?.trim().slice(0, TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH);
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
  payload: { action: "approve" | "reject"; reason: string }
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

export async function fetchAdminTemplatesAnalyticsOverview(
  query: AdminTemplatesAnalyticsQuery = {},
  signal?: AbortSignal
): Promise<AdminTemplatesAnalyticsOverview> {
  const params = new URLSearchParams();
  if (query.periodDays) params.set("periodDays", String(query.periodDays));
  if (query.templateType && query.templateType !== "All")
    params.set("templateType", query.templateType);
  if (query.category) params.set("category", query.category);
  if (query.status && query.status !== "All") params.set("status", query.status);
  if (query.access && query.access !== "all") params.set("access", query.access);
  if (query.sort) params.set("sort", query.sort);
  if (query.take) params.set("take", String(query.take));

  const suffix = params.size > 0 ? `?${params.toString()}` : "";

  return cachedGet(
    `templates-analytics:${getAnalyticsOverviewCacheKey(query)}`,
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

export function normalizeAdminTemplateGenerationsQuery(
  query: AdminTemplateGenerationsQuery = {}
): AdminTemplateGenerationsQuery {
  return {
    status: query.status && query.status !== "All" ? query.status : undefined,
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
  return normalizeAdminTemplateTestRun(run);
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
  return normalizeAdminTemplateTestRun(run);
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
  return runs.map(normalizeAdminTemplateTestRun);
}

function normalizeAdminTemplateTestRun(run: AdminTemplateTestRun): AdminTemplateTestRun {
  return run.status === "Succeeded" ? { ...run, status: "Completed" } : run;
}

export async function createImageTemplate(payload: ImageTemplatePayload): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>("/api/admin/templates/image", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  cachedTemplateLists.clear();
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
  cachedTemplateLists.clear();
  return template;
}

export async function createVideoTemplate(payload: VideoTemplatePayload): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>("/api/admin/templates/video", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  cachedTemplateLists.clear();
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
  cachedTemplateLists.clear();
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
  cachedTemplateLists.clear();
  return template;
}

export async function deleteTemplate(templateId: string): Promise<void> {
  const encodedTemplateId = encodePathSegment(templateId);
  await apiRequest<void>(`/api/admin/templates/${encodedTemplateId}`, {
    method: "DELETE",
  });
  cachedTemplateLists.clear();
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

  return apiRequest<TemplateAsset>("/api/admin/templates/media/upload", {
    method: "POST",
    body: formData,
  });
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
