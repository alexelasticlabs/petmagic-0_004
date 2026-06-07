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
  getAnalyticsOverviewCacheKey,
  getTemplateListCacheKey,
  getTemplateRecentGenerationsCacheKey,
} from "./api-client.core";

import type {
  AdminTemplate,
  AdminTemplateCategory,
  AdminTemplateEventAnalytics,
  AdminTemplateFailureBreakdownItem,
  AdminTemplateFeedbackItem,
  AdminTemplateFeedbackQuery,
  AdminModerationQueueItem,
  AdminModerationQueuePage,
  AdminModerationQueueQuery,
  AdminTemplateGenerationDashboardMetrics,
  AdminTemplateGenerationsPage,
  AdminTemplateGenerationsQuery,
  AdminTemplateListItem,
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
  TemplateStatus,
  TemplateType,
  VideoTemplatePayload,
} from "./api-client.types";

export async function fetchAdminTemplates(
  type?: TemplateType,
  signal?: AbortSignal
): Promise<AdminTemplateListItem[]> {
  const cacheKey = getTemplateListCacheKey(type);
  const query = type ? `?type=${encodeURIComponent(type)}` : "";

  return cachedGet(
    `templates:${cacheKey}`,
    cachedTemplateLists,
    () =>
      apiRequest<AdminTemplateListItem[]>(`/api/admin/templates/${query}`, {
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
  const category = await apiRequest<AdminTemplateCategory>(
    `/api/admin/templates/categories/${categoryId}`,
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
  const category = await apiRequest<AdminTemplateCategory>(
    `/api/admin/templates/categories/${categoryId}/archive`,
    {
      method: "PUT",
      body: JSON.stringify({ isArchived }),
    }
  );
  clearAdminListCaches();
  return category;
}

export async function deleteTemplateCategory(categoryId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/templates/categories/${categoryId}`, {
    method: "DELETE",
  });
  clearAdminListCaches();
}

export async function fetchAdminTemplate(
  templateId: string,
  signal?: AbortSignal
): Promise<AdminTemplate> {
  return cachedGet(
    `admin-template:${templateId}`,
    cachedAdminTemplateDetails,
    () => apiRequest<AdminTemplate>(`/api/admin/templates/${templateId}`, { method: "GET", signal }),
    signal
  );
}

export async function fetchAdminTemplateStatistics(
  templateId: string,
  signal?: AbortSignal
): Promise<AdminTemplateStatistics> {
  return cachedGet(
    `admin-template-statistics:${templateId}`,
    cachedAdminTemplateStatistics,
    () =>
      apiRequest<AdminTemplateStatistics>(`/api/admin/templates/${templateId}/statistics`, {
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
  return cachedGet(
    `admin-template-trends:${templateId}`,
    cachedAdminTemplateTrends,
    () =>
      apiRequest<AdminTemplateTrendPoint[]>(
        `/api/admin/templates/${templateId}/statistics/trends`,
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
        `/api/admin/templates/${templateId}/statistics/recent${query}`,
        { method: "GET", signal }
      ),
    signal
  );
}

export async function fetchAdminTemplateFailureBreakdown(
  templateId: string,
  signal?: AbortSignal
): Promise<AdminTemplateFailureBreakdownItem[]> {
  return cachedGet(
    `admin-template-failures:${templateId}`,
    cachedAdminTemplateFailureBreakdowns,
    () =>
      apiRequest<AdminTemplateFailureBreakdownItem[]>(
        `/api/admin/templates/${templateId}/statistics/failures`,
        { method: "GET", signal }
      ),
    signal
  );
}

export async function fetchAdminTemplateEventAnalytics(
  templateId: string,
  signal?: AbortSignal
): Promise<AdminTemplateEventAnalytics> {
  return cachedGet(
    `admin-template-events:${templateId}`,
    cachedAdminTemplateEventAnalytics,
    () =>
      apiRequest<AdminTemplateEventAnalytics>(
        `/api/admin/templates/${templateId}/statistics/events`,
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
  const params = new URLSearchParams();
  if (query.take) params.set("take", String(query.take));
  if (query.type) params.set("type", query.type);
  if (query.search?.trim()) params.set("search", query.search.trim());
  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<AdminTemplateFeedbackItem[]>(
    `/api/admin/templates/${templateId}/statistics/feedback${suffix}`,
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
    search: query.search?.trim() || undefined,
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
  return apiRequest<AdminModerationQueueItem>(
    `/api/admin/templates/moderation/${eventId}/decision`,
    {
      method: "POST",
      body: JSON.stringify(payload),
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
    provider: query.provider?.trim() || undefined,
    user: query.user?.trim() || undefined,
    search: query.search?.trim() || undefined,
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
  const formData = new FormData();
  formData.append("sourceImage", file);

  return apiRequest<AdminTemplateTestRun>(`/api/admin/templates/${templateId}/test`, {
    method: "POST",
    body: formData,
  });
}

export async function fetchAdminTemplateTest(
  generationId: string,
  signal?: AbortSignal
): Promise<AdminTemplateTestRun> {
  return apiRequest<AdminTemplateTestRun>(`/api/admin/templates/tests/${generationId}`, {
    method: "GET",
    signal,
  });
}

export async function fetchAdminTemplateTestHistory(
  templateId: string,
  take?: number,
  signal?: AbortSignal
): Promise<AdminTemplateTestRun[]> {
  const normalizedTake =
    typeof take === "number" && Number.isFinite(take) && take > 0
      ? Math.min(Math.floor(take), 100)
      : undefined;
  const query =
    typeof normalizedTake === "number" ? `?take=${encodeURIComponent(String(normalizedTake))}` : "";
  return apiRequest<AdminTemplateTestRun[]>(`/api/admin/templates/${templateId}/tests${query}`, {
    method: "GET",
    signal,
  });
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
  const template = await apiRequest<AdminTemplate>(`/api/admin/templates/image/${templateId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
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
  const template = await apiRequest<AdminTemplate>(`/api/admin/templates/video/${templateId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
  cachedTemplateLists.clear();
  return template;
}

export async function changeTemplateStatus(
  templateId: string,
  status: TemplateStatus
): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>(`/api/admin/templates/${templateId}/status`, {
    method: "PUT",
    body: JSON.stringify({ status }),
  });
  cachedTemplateLists.clear();
  return template;
}

export async function deleteTemplate(templateId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/templates/${templateId}`, {
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
