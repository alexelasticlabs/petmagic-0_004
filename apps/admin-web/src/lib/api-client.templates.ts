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

export async function fetchAdminTemplates(type?: TemplateType): Promise<AdminTemplateListItem[]> {
  const cacheKey = getTemplateListCacheKey(type);
  const query = type ? `?type=${encodeURIComponent(type)}` : "";

  return cachedGet(`templates:${cacheKey}`, cachedTemplateLists, () =>
    apiRequest<AdminTemplateListItem[]>(`/api/admin/templates/${query}`, { method: "GET" })
  );
}

export async function fetchAdminTemplateCategories(
  includeArchived = true
): Promise<AdminTemplateCategory[]> {
  const cacheKey = includeArchived ? "archived" : "active";
  const query = includeArchived ? "?includeArchived=true" : "?includeArchived=false";

  return cachedGet(`template-categories:${cacheKey}`, cachedTemplateCategories, () =>
    apiRequest<AdminTemplateCategory[]>(`/api/admin/templates/categories/${query}`, {
      method: "GET",
    })
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

export async function fetchAdminTemplate(templateId: string): Promise<AdminTemplate> {
  return cachedGet(`admin-template:${templateId}`, cachedAdminTemplateDetails, () =>
    apiRequest<AdminTemplate>(`/api/admin/templates/${templateId}`, { method: "GET" })
  );
}

export async function fetchAdminTemplateStatistics(
  templateId: string
): Promise<AdminTemplateStatistics> {
  return cachedGet(`admin-template-statistics:${templateId}`, cachedAdminTemplateStatistics, () =>
    apiRequest<AdminTemplateStatistics>(`/api/admin/templates/${templateId}/statistics`, {
      method: "GET",
    })
  );
}

export async function fetchAdminTemplateTrends(
  templateId: string
): Promise<AdminTemplateTrendPoint[]> {
  return cachedGet(`admin-template-trends:${templateId}`, cachedAdminTemplateTrends, () =>
    apiRequest<AdminTemplateTrendPoint[]>(`/api/admin/templates/${templateId}/statistics/trends`, {
      method: "GET",
    })
  );
}

export async function fetchAdminTemplateRecentGenerations(
  templateId: string,
  take?: number
): Promise<AdminTemplateRecentGeneration[]> {
  const query = typeof take === "number" ? `?take=${encodeURIComponent(String(take))}` : "";
  return cachedGet(
    `admin-template-recent:${getTemplateRecentGenerationsCacheKey(templateId, take)}`,
    cachedAdminTemplateRecentGenerations,
    () =>
      apiRequest<AdminTemplateRecentGeneration[]>(
        `/api/admin/templates/${templateId}/statistics/recent${query}`,
        { method: "GET" }
      )
  );
}

export async function fetchAdminTemplateFailureBreakdown(
  templateId: string
): Promise<AdminTemplateFailureBreakdownItem[]> {
  return cachedGet(
    `admin-template-failures:${templateId}`,
    cachedAdminTemplateFailureBreakdowns,
    () =>
      apiRequest<AdminTemplateFailureBreakdownItem[]>(
        `/api/admin/templates/${templateId}/statistics/failures`,
        { method: "GET" }
      )
  );
}

export async function fetchAdminTemplateEventAnalytics(
  templateId: string
): Promise<AdminTemplateEventAnalytics> {
  return cachedGet(`admin-template-events:${templateId}`, cachedAdminTemplateEventAnalytics, () =>
    apiRequest<AdminTemplateEventAnalytics>(
      `/api/admin/templates/${templateId}/statistics/events`,
      { method: "GET" }
    )
  );
}

export async function fetchAdminTemplateFeedback(
  templateId: string,
  query: AdminTemplateFeedbackQuery = {}
): Promise<AdminTemplateFeedbackItem[]> {
  const params = new URLSearchParams();
  if (query.take) params.set("take", String(query.take));
  if (query.type) params.set("type", query.type);
  if (query.search?.trim()) params.set("search", query.search.trim());
  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<AdminTemplateFeedbackItem[]>(
    `/api/admin/templates/${templateId}/statistics/feedback${suffix}`,
    { method: "GET" }
  );
}

export async function fetchAdminTemplatesAnalyticsOverview(
  query: AdminTemplatesAnalyticsQuery = {}
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
      })
  );
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

export async function fetchAdminTemplateTest(generationId: string): Promise<AdminTemplateTestRun> {
  return apiRequest<AdminTemplateTestRun>(`/api/admin/templates/tests/${generationId}`, {
    method: "GET",
  });
}

export async function fetchAdminTemplateTestHistory(
  templateId: string,
  take?: number
): Promise<AdminTemplateTestRun[]> {
  const query = typeof take === "number" ? `?take=${encodeURIComponent(String(take))}` : "";
  return apiRequest<AdminTemplateTestRun[]>(`/api/admin/templates/${templateId}/tests${query}`, {
    method: "GET",
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
  assetKind: TemplateAssetKind
): Promise<TemplateAsset> {
  const formData = new FormData();
  formData.append("file", file);
  formData.append("assetKind", assetKind);

  return apiRequest<TemplateAsset>("/api/admin/templates/media/upload", {
    method: "POST",
    body: formData,
  });
}
