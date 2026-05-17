"use client";

import { useSyncExternalStore } from "react";

export type UserProfile = {
  userId: string;
  email: string;
  displayName?: string;
  isPremium: boolean;
  roles: string[];
};

export type AuthSession = {
  accessToken: string;
  refreshToken: string;
  expiresAtUtc: string;
  user: UserProfile;
};

export type UserListItem = {
  userId: string;
  email: string;
  displayName?: string;
  isPremium: boolean;
  isActive: boolean;
  roles: string[];
  createdAtUtc: string;
};

export type TemplateType = "Image" | "Video";

export type TemplateStatus = "Draft" | "Active" | "Archived";

export type TemplateGenerationJobStatus = "Queued" | "Processing" | "Completed" | "Failed";

export type TemplatePromoBadgeMode = "Auto" | "New" | "Trending" | "Popular" | "Funny";

export type TemplateAssetInput = {
  url: string;
  fileName: string;
  contentType: string;
  fileSizeBytes?: number;
  durationSeconds?: number;
};

export type TemplateAsset = {
  url: string;
  fileName: string;
  contentType: string;
  fileSizeBytes?: number;
  durationSeconds?: number;
};

export type TemplateAssetKind = "Preview" | "ReferenceMotion";

export type AdminTemplateListItem = {
  templateId: string;
  templateType: TemplateType;
  title: string;
  shortDescription: string;
  category: string;
  status: TemplateStatus;
  promoBadgeMode: TemplatePromoBadgeMode;
  effectivePromoBadge?: Exclude<TemplatePromoBadgeMode, "Auto">;
  isPremium: boolean;
  tokenCost: number;
  tags: string[];
  previewAsset?: TemplateAsset;
  referenceVideoDurationSeconds?: number;
  characterOrientation?: string;
  createdAtUtc: string;
  updatedAtUtc: string;
};

export type AdminTemplate = {
  templateId: string;
  templateType: TemplateType;
  title: string;
  shortDescription: string;
  category: string;
  status: TemplateStatus;
  promoBadgeMode: TemplatePromoBadgeMode;
  effectivePromoBadge?: Exclude<TemplatePromoBadgeMode, "Auto">;
  isPremium: boolean;
  tokenCost: number;
  tags: string[];
  previewAsset?: TemplateAsset;
  musicDescription?: string;
  referenceMotionAsset?: TemplateAsset;
  referenceVideoDurationSeconds?: number;
  characterOrientation?: string;
  preprocessingModel?: string;
  preprocessingPrompt?: string;
  klingModel?: string;
  klingPrompt?: string;
  keepOriginalSound?: boolean;
  createdAtUtc: string;
  updatedAtUtc: string;
};

export type AdminTemplateStatistics = {
  templateId: string;
  totalRuns: number;
  queuedRuns: number;
  processingRuns: number;
  completedRuns: number;
  failedRuns: number;
  successRatePercent: number;
  totalTokenCost: number;
  averageTokenCost: number;
  totalProviderCostUsd: number;
  averageProviderCostUsd: number;
  lastRunAtUtc?: string | null;
  lastCompletedAtUtc?: string | null;
  averageGenerationSeconds?: number | null;
};

export type AdminTemplateTrendPoint = {
  dateUtc: string;
  totalRuns: number;
  queuedRuns: number;
  processingRuns: number;
  completedRuns: number;
  failedRuns: number;
  successRatePercent: number;
  totalTokenCost: number;
  totalProviderCostUsd: number;
  averageGenerationSeconds?: number | null;
};

export type AdminTemplateRecentGeneration = {
  generationId: string;
  userId: string;
  status: TemplateGenerationJobStatus;
  tokenCost: number;
  attemptCount: number;
  usedPreprocessingModel?: string | null;
  usedKlingModel?: string | null;
  motionProviderCostUsd?: number | null;
  failureCode?: string | null;
  failureMessage?: string | null;
  outputUrl?: string | null;
  createdAtUtc: string;
  startedAtUtc?: string | null;
  completedAtUtc?: string | null;
};

export type AdminTemplateFailureBreakdownItem = {
  failureCode: string;
  count: number;
  lastOccurredAtUtc?: string | null;
};

export type AdminTemplateAnalyticsDimension = {
  key: string;
  label: string;
  count: number;
  sharePercent: number;
};

export type AdminTemplateEventAnalytics = {
  totalViews: number;
  totalVideoViews: number;
  totalComplaints: number;
  sources: AdminTemplateAnalyticsDimension[];
  devices: AdminTemplateAnalyticsDimension[];
  geography: AdminTemplateAnalyticsDimension[];
};

export type AdminTemplatesAnalyticsQuery = {
  periodDays?: number;
  templateType?: TemplateType | "All";
  category?: string;
  status?: TemplateStatus | "All";
  access?: "all" | "free" | "premium";
  sort?: "views" | "starts" | "conversion" | "revenue" | "cost" | "tokens" | "updated";
  take?: number;
};

export type AdminTemplatesAnalyticsSummary = {
  totalTemplates: number;
  videoTemplates: number;
  imageTemplates: number;
  activeTemplates: number;
  premiumTemplates: number;
  totalViews: number;
  totalGenerationStarts: number;
  completedGenerations: number;
  failedGenerations: number;
  conversionPercent: number;
  totalTokenCost: number;
  averageTokenCost: number;
  totalProviderCostUsd: number;
  estimatedRevenueUsd: number;
  estimatedGrossMarginUsd: number;
  totalComplaints: number;
};

export type AdminTemplatesAnalyticsTrendPoint = {
  dateUtc: string;
  totalViews: number;
  totalGenerationStarts: number;
  completedGenerations: number;
  failedGenerations: number;
  totalTokenCost: number;
  totalProviderCostUsd: number;
  estimatedRevenueUsd: number;
};

export type AdminTemplatesAnalyticsTemplateRow = {
  templateId: string;
  templateType: TemplateType;
  title: string;
  category: string;
  status: TemplateStatus;
  isPremium: boolean;
  tokenCost: number;
  previewAsset?: TemplateAsset | null;
  views: number;
  generationStarts: number;
  completedGenerations: number;
  failedGenerations: number;
  conversionPercent: number;
  totalTokenCost: number;
  totalProviderCostUsd: number;
  estimatedRevenueUsd: number;
  updatedAtUtc: string;
};

export type AdminTemplatesAnalyticsBreakdown = {
  key: string;
  label: string;
  templateCount: number;
  views: number;
  generationStarts: number;
  completedGenerations: number;
  conversionPercent: number;
  totalTokenCost: number;
  totalProviderCostUsd: number;
  estimatedRevenueUsd: number;
};

export type AdminTemplatesAnalyticsFunnel = {
  views: number;
  generationStarts: number;
  completedGenerations: number;
  failedGenerations: number;
  complaints: number;
};

export type AdminTemplatesAnalyticsOverview = {
  summary: AdminTemplatesAnalyticsSummary;
  trendPoints: AdminTemplatesAnalyticsTrendPoint[];
  topTemplates: AdminTemplatesAnalyticsTemplateRow[];
  categories: AdminTemplatesAnalyticsBreakdown[];
  templateTypes: AdminTemplatesAnalyticsBreakdown[];
  sources: AdminTemplateAnalyticsDimension[];
  devices: AdminTemplateAnalyticsDimension[];
  geography: AdminTemplateAnalyticsDimension[];
  conversionFunnel: AdminTemplatesAnalyticsFunnel;
  templates: AdminTemplatesAnalyticsTemplateRow[];
  availableCategories: string[];
  generatedAtUtc: string;
};

export type AdminTemplateTestRun = {
  generationId: string;
  userId: string;
  templateId: string;
  status: TemplateGenerationJobStatus;
  tokenCost: number;
  sourceImageAsset?: TemplateAsset;
  normalizedImageUrl?: string | null;
  referenceMotionUrl?: string | null;
  outputUrl?: string | null;
  attemptCount: number;
  usedPreprocessingModel?: string | null;
  usedKlingModel?: string | null;
  preprocessingProviderRequestId?: string | null;
  preprocessingInferenceTimeSeconds?: number | null;
  motionProviderRequestId?: string | null;
  motionInferenceTimeSeconds?: number | null;
  outputVideoDurationSeconds?: number | null;
  motionProviderCostUsd?: number | null;
  failureCode?: string | null;
  failureMessage?: string | null;
  createdAtUtc: string;
  updatedAtUtc: string;
  startedAtUtc?: string | null;
  preprocessingCompletedAtUtc?: string | null;
  motionGenerationCompletedAtUtc?: string | null;
  mediaImportCompletedAtUtc?: string | null;
  completedAtUtc?: string | null;
  userMediaExpired: boolean;
};

export type ImageTemplatePayload = {
  title: string;
  shortDescription: string;
  category: string;
  status: TemplateStatus;
  promoBadgeMode: TemplatePromoBadgeMode;
  tags: string[];
  isPremium: boolean;
  tokenCost: number;
  previewAsset?: TemplateAssetInput;
};

export type VideoTemplatePayload = {
  title: string;
  shortDescription: string;
  category: string;
  status: TemplateStatus;
  promoBadgeMode: TemplatePromoBadgeMode;
  tags: string[];
  isPremium: boolean;
  tokenCost: number;
  musicDescription: string;
  previewAsset?: TemplateAssetInput;
  referenceMotionAsset?: TemplateAssetInput;
  preprocessingModel: string;
  preprocessingPrompt: string;
  klingModel: string;
  klingPrompt: string;
  keepOriginalSound: boolean;
};

const AUTH_KEY = "petmagic_admin_auth";
const AUTH_SESSION_EVENT = "petmagic_admin_auth_changed";
const ADMIN_LIST_CACHE_TTL_MS = 30_000;
const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:5000";

type ApiError = Error & { status?: number; detail?: string; code?: string; validationErrors?: string[] };
type AuthSessionSnapshot = AuthSession | null | undefined;

let cachedAuthRaw: string | null | undefined;
let cachedAuthSession: AuthSession | null = null;
let cachedUsersList: { value: UserListItem[]; expiresAt: number } | null = null;
const cachedTemplateLists = new Map<string, { value: AdminTemplateListItem[]; expiresAt: number }>();

function clearAdminListCaches(): void {
  cachedUsersList = null;
  cachedTemplateLists.clear();
}

function getTemplateListCacheKey(type?: TemplateType): string {
  return type ?? "all";
}

export function getSession(): AuthSession | null {
  if (typeof window === "undefined") {
    return null;
  }

  const raw = window.localStorage.getItem(AUTH_KEY);
  if (raw === cachedAuthRaw) {
    return cachedAuthSession;
  }

  cachedAuthRaw = raw;
  if (!raw) {
    cachedAuthSession = null;
    return null;
  }

  try {
    cachedAuthSession = JSON.parse(raw) as AuthSession;
    return cachedAuthSession;
  } catch {
    cachedAuthSession = null;
    return null;
  }
}

function notifyAuthSessionChanged(): void {
  cachedAuthRaw = undefined;

  if (typeof window !== "undefined") {
    window.dispatchEvent(new Event(AUTH_SESSION_EVENT));
  }
}

function subscribeAuthSession(onStoreChange: () => void): () => void {
  if (typeof window === "undefined") {
    return () => {};
  }

  function handleStorage(event: StorageEvent) {
    if (event.key === AUTH_KEY) {
      cachedAuthRaw = undefined;
      onStoreChange();
    }
  }

  window.addEventListener("storage", handleStorage);
  window.addEventListener(AUTH_SESSION_EVENT, onStoreChange);
  return () => {
    window.removeEventListener("storage", handleStorage);
    window.removeEventListener(AUTH_SESSION_EVENT, onStoreChange);
  };
}

function getAuthSessionSnapshot(): AuthSessionSnapshot {
  return getSession();
}

function getServerAuthSessionSnapshot(): AuthSessionSnapshot {
  return undefined;
}

export function useAuthSession(): AuthSessionSnapshot {
  return useSyncExternalStore(subscribeAuthSession, getAuthSessionSnapshot, getServerAuthSessionSnapshot);
}

export function clearSession(): void {
  clearAdminListCaches();

  if (typeof window !== "undefined") {
    window.localStorage.removeItem(AUTH_KEY);
    notifyAuthSessionChanged();
  }
}

function saveSession(session: AuthSession): void {
  clearAdminListCaches();

  if (typeof window !== "undefined") {
    window.localStorage.setItem(AUTH_KEY, JSON.stringify(session));
    notifyAuthSessionChanged();
  }
}

async function apiRequest<TResponse>(
  path: string,
  init: RequestInit,
  options: { requireAuth?: boolean; allowRefresh?: boolean } = {}
): Promise<TResponse> {
  const requireAuth = options.requireAuth ?? true;
  const allowRefresh = options.allowRefresh ?? true;
  const session = getSession();

  const headers = new Headers(init.headers);
  if (!(init.body instanceof FormData)) {
    headers.set("Content-Type", "application/json");
  }

  if (requireAuth && session?.accessToken) {
    headers.set("Authorization", `Bearer ${session.accessToken}`);
  }

  const response = await fetch(`${apiBaseUrl}${path}`, {
    ...init,
    headers
  });

  if (response.status === 401 && allowRefresh && session?.refreshToken) {
    await refreshSession(session.refreshToken);
    return apiRequest<TResponse>(path, init, { requireAuth, allowRefresh: false });
  }

  if (!response.ok) {
    const error = new Error(`API request failed with status ${response.status}`) as ApiError;
    error.status = response.status;

    try {
      const problem = (await response.json()) as { title?: string; detail?: string; errors?: Record<string, string[]> };
      error.code = problem.title;
      error.detail = problem.detail;
      const validationErrors = Object.values(problem.errors ?? {})
        .flat()
        .map((value) => value.trim())
        .filter(Boolean);

      if (validationErrors.length > 0) {
        error.validationErrors = validationErrors;
      }

      if (problem.detail) {
        error.message = problem.detail;
      } else if (validationErrors.length > 0) {
        error.message = validationErrors.join(" ");
      } else if (problem.title) {
        error.message = problem.title;
      }
    } catch {
      // Ignore invalid or empty error payloads and fall back to the generic message.
    }

    throw error;
  }

  if (response.status === 204) {
    return undefined as TResponse;
  }

  return (await response.json()) as TResponse;
}

async function refreshSession(refreshToken: string): Promise<void> {
  const refreshed = await apiRequest<AuthSession>(
    "/api/auth/refresh",
    {
      method: "POST",
      body: JSON.stringify({ refreshToken })
    },
    {
      requireAuth: false,
      allowRefresh: false
    }
  );

  saveSession(refreshed);
}

export async function login(email: string, password: string): Promise<AuthSession> {
  const session = await apiRequest<AuthSession>(
    "/api/auth/login",
    {
      method: "POST",
      body: JSON.stringify({ email, password })
    },
    {
      requireAuth: false,
      allowRefresh: false
    }
  );

  saveSession(session);
  return session;
}

export async function logout(): Promise<void> {
  const session = getSession();

  clearSession();

  if (session?.refreshToken) {
    const headers = new Headers({ "Content-Type": "application/json" });
    if (session.accessToken) {
      headers.set("Authorization", `Bearer ${session.accessToken}`);
    }

    void fetch(`${apiBaseUrl}/api/auth/logout`, {
        method: "POST",
        headers,
        body: JSON.stringify({ refreshToken: session.refreshToken })
      })
      .catch(() => {
        // Logout must stay locally instant even when the API is slow or unavailable.
      });
  }
}

export async function fetchUsers(): Promise<UserListItem[]> {
  const now = Date.now();
  if (cachedUsersList && cachedUsersList.expiresAt > now) {
    return cachedUsersList.value;
  }

  const users = await apiRequest<UserListItem[]>("/api/admin/users/", { method: "GET" });
  cachedUsersList = { value: users, expiresAt: now + ADMIN_LIST_CACHE_TTL_MS };
  return users;
}

export async function assignRole(userId: string, role: string): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/role`, {
    method: "PUT",
    body: JSON.stringify({ role })
  });
  cachedUsersList = null;
}

export async function revokeRole(userId: string, role: string): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/role`, {
    method: "DELETE",
    body: JSON.stringify({ role })
  });
  cachedUsersList = null;
}

export async function setPremium(userId: string, isPremium: boolean): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/premium`, {
    method: "PUT",
    body: JSON.stringify({ isPremium })
  });
  cachedUsersList = null;
}

export async function setActive(userId: string, isActive: boolean): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/active`, {
    method: "PUT",
    body: JSON.stringify({ isActive })
  });
  cachedUsersList = null;
}

export async function fetchAdminTemplates(type?: TemplateType): Promise<AdminTemplateListItem[]> {
  const now = Date.now();
  const cacheKey = getTemplateListCacheKey(type);
  const cached = cachedTemplateLists.get(cacheKey);
  if (cached && cached.expiresAt > now) {
    return cached.value;
  }

  const query = type ? `?type=${encodeURIComponent(type)}` : "";
  const templates = await apiRequest<AdminTemplateListItem[]>(`/api/admin/templates/${query}`, { method: "GET" });
  cachedTemplateLists.set(cacheKey, { value: templates, expiresAt: now + ADMIN_LIST_CACHE_TTL_MS });
  return templates;
}

export async function fetchAdminTemplate(templateId: string): Promise<AdminTemplate> {
  return apiRequest<AdminTemplate>(`/api/admin/templates/${templateId}`, { method: "GET" });
}

export async function fetchAdminTemplateStatistics(templateId: string): Promise<AdminTemplateStatistics> {
  return apiRequest<AdminTemplateStatistics>(`/api/admin/templates/${templateId}/statistics`, { method: "GET" });
}

export async function fetchAdminTemplateTrends(templateId: string): Promise<AdminTemplateTrendPoint[]> {
  return apiRequest<AdminTemplateTrendPoint[]>(`/api/admin/templates/${templateId}/statistics/trends`, { method: "GET" });
}

export async function fetchAdminTemplateRecentGenerations(templateId: string, take = 8): Promise<AdminTemplateRecentGeneration[]> {
  return apiRequest<AdminTemplateRecentGeneration[]>(`/api/admin/templates/${templateId}/statistics/recent?take=${encodeURIComponent(String(take))}`, { method: "GET" });
}

export async function fetchAdminTemplateFailureBreakdown(templateId: string): Promise<AdminTemplateFailureBreakdownItem[]> {
  return apiRequest<AdminTemplateFailureBreakdownItem[]>(`/api/admin/templates/${templateId}/statistics/failures`, { method: "GET" });
}

export async function fetchAdminTemplateEventAnalytics(templateId: string): Promise<AdminTemplateEventAnalytics> {
  return apiRequest<AdminTemplateEventAnalytics>(`/api/admin/templates/${templateId}/statistics/events`, { method: "GET" });
}

export async function fetchAdminTemplatesAnalyticsOverview(query: AdminTemplatesAnalyticsQuery = {}): Promise<AdminTemplatesAnalyticsOverview> {
  const params = new URLSearchParams();
  if (query.periodDays) params.set("periodDays", String(query.periodDays));
  if (query.templateType && query.templateType !== "All") params.set("templateType", query.templateType);
  if (query.category) params.set("category", query.category);
  if (query.status && query.status !== "All") params.set("status", query.status);
  if (query.access && query.access !== "all") params.set("access", query.access);
  if (query.sort) params.set("sort", query.sort);
  if (query.take) params.set("take", String(query.take));

  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<AdminTemplatesAnalyticsOverview>(`/api/admin/templates/analytics${suffix}`, { method: "GET" });
}

export async function startAdminTemplateTest(templateId: string, file: File): Promise<AdminTemplateTestRun> {
  const formData = new FormData();
  formData.append("sourceImage", file);

  return apiRequest<AdminTemplateTestRun>(`/api/admin/templates/${templateId}/test`, {
    method: "POST",
    body: formData
  });
}

export async function fetchAdminTemplateTest(generationId: string): Promise<AdminTemplateTestRun> {
  return apiRequest<AdminTemplateTestRun>(`/api/admin/templates/tests/${generationId}`, { method: "GET" });
}

export async function createImageTemplate(payload: ImageTemplatePayload): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>("/api/admin/templates/image", {
    method: "POST",
    body: JSON.stringify(payload)
  });
  cachedTemplateLists.clear();
  return template;
}

export async function updateImageTemplate(templateId: string, payload: ImageTemplatePayload): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>(`/api/admin/templates/image/${templateId}`, {
    method: "PUT",
    body: JSON.stringify(payload)
  });
  cachedTemplateLists.clear();
  return template;
}

export async function createVideoTemplate(payload: VideoTemplatePayload): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>("/api/admin/templates/video", {
    method: "POST",
    body: JSON.stringify(payload)
  });
  cachedTemplateLists.clear();
  return template;
}

export async function updateVideoTemplate(templateId: string, payload: VideoTemplatePayload): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>(`/api/admin/templates/video/${templateId}`, {
    method: "PUT",
    body: JSON.stringify(payload)
  });
  cachedTemplateLists.clear();
  return template;
}

export async function changeTemplateStatus(templateId: string, status: TemplateStatus): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>(`/api/admin/templates/${templateId}/status`, {
    method: "PUT",
    body: JSON.stringify({ status })
  });
  cachedTemplateLists.clear();
  return template;
}

export async function deleteTemplate(templateId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/templates/${templateId}`, {
    method: "DELETE"
  });
  cachedTemplateLists.clear();
}

export async function uploadTemplateMedia(file: File, assetKind: TemplateAssetKind): Promise<TemplateAsset> {
  const formData = new FormData();
  formData.append("file", file);
  formData.append("assetKind", assetKind);

  return apiRequest<TemplateAsset>("/api/admin/templates/media/upload", {
    method: "POST",
    body: formData
  });
}
