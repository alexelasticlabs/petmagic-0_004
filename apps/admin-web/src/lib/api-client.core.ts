"use client";

import { useSyncExternalStore } from "react";

import type {
  AdminSupportConversation,
  AdminSupportConversationSummary,
  AdminSupportReplyTemplate,
  AdminTemplate,
  AdminTemplateCategory,
  AdminTemplateEventAnalytics,
  AdminTemplateFailureBreakdownItem,
  AdminTemplateListItem,
  AdminTemplateRecentGeneration,
  AdminTemplateStatistics,
  AdminTemplateTrendPoint,
  AdminTemplatesAnalyticsOverview,
  AdminTemplatesAnalyticsQuery,
  AdminUserAnalytics,
  AdminUserDetail,
  AuthSession,
  TemplateType,
  UserListItem,
} from "./api-client.types";
const AUTH_KEY = "petmagic_admin_auth";
const AUTH_SESSION_EVENT = "petmagic_admin_auth_changed";
const ADMIN_LIST_CACHE_TTL_MS = 120_000;
const API_REQUEST_TIMEOUT_MS = 15_000;

function getApiBaseUrl(): string {
  if (typeof window === "undefined") {
    return (
      process.env.INTERNAL_API_BASE_URL ??
      process.env.NEXT_PUBLIC_API_BASE_URL ??
      "http://localhost:5000"
    );
  }

  return process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:5000";
}

type ApiError = Error & {
  status?: number;
  detail?: string;
  code?: string;
  validationErrors?: string[];
};
type AuthSessionSnapshot = AuthSession | null | undefined;

let cachedAuthRaw: string | null | undefined;
let cachedAuthSession: AuthSession | null = null;
let volatileRefreshToken: string | null = null;
export const cachedUsersLists = new Map<string, { value: UserListItem[]; expiresAt: number }>();
export const cachedAdminUserDetails = new Map<string, { value: AdminUserDetail; expiresAt: number }>();
export const cachedAdminUserAnalytics = new Map<
  string,
  { value: AdminUserAnalytics; expiresAt: number }
>();
export const cachedSupportInbox = new Map<
  string,
  { value: AdminSupportConversationSummary[]; expiresAt: number }
>();
export const cachedSupportConversations = new Map<
  string,
  { value: AdminSupportConversation; expiresAt: number }
>();
export const cachedSupportTemplates = new Map<
  string,
  { value: AdminSupportReplyTemplate[]; expiresAt: number }
>();
export const cachedTemplateLists = new Map<
  string,
  { value: AdminTemplateListItem[]; expiresAt: number }
>();
export const cachedTemplateCategories = new Map<
  string,
  { value: AdminTemplateCategory[]; expiresAt: number }
>();
export const cachedTemplatesAnalyticsOverview = new Map<
  string,
  { value: AdminTemplatesAnalyticsOverview; expiresAt: number }
>();
export const cachedAdminTemplateDetails = new Map<string, { value: AdminTemplate; expiresAt: number }>();
export const cachedAdminTemplateStatistics = new Map<
  string,
  { value: AdminTemplateStatistics; expiresAt: number }
>();
export const cachedAdminTemplateTrends = new Map<
  string,
  { value: AdminTemplateTrendPoint[]; expiresAt: number }
>();
export const cachedAdminTemplateRecentGenerations = new Map<
  string,
  { value: AdminTemplateRecentGeneration[]; expiresAt: number }
>();
export const cachedAdminTemplateFailureBreakdowns = new Map<
  string,
  { value: AdminTemplateFailureBreakdownItem[]; expiresAt: number }
>();
export const cachedAdminTemplateEventAnalytics = new Map<
  string,
  { value: AdminTemplateEventAnalytics; expiresAt: number }
>();
export const inflightGetRequests = new Map<string, Promise<unknown>>();

export function clearAdminListCaches(): void {
  cachedUsersLists.clear();
  cachedAdminUserDetails.clear();
  cachedAdminUserAnalytics.clear();
  cachedSupportInbox.clear();
  cachedSupportConversations.clear();
  cachedSupportTemplates.clear();
  cachedTemplateLists.clear();
  cachedTemplateCategories.clear();
  cachedTemplatesAnalyticsOverview.clear();
  cachedAdminTemplateDetails.clear();
  cachedAdminTemplateStatistics.clear();
  cachedAdminTemplateTrends.clear();
  cachedAdminTemplateRecentGenerations.clear();
  cachedAdminTemplateFailureBreakdowns.clear();
  cachedAdminTemplateEventAnalytics.clear();
  inflightGetRequests.clear();
}

export function getTemplateListCacheKey(type?: TemplateType): string {
  return type ?? "all";
}

export function getAnalyticsOverviewCacheKey(query: AdminTemplatesAnalyticsQuery): string {
  return JSON.stringify({
    periodDays: query.periodDays ?? null,
    templateType: query.templateType ?? null,
    category: query.category ?? null,
    status: query.status ?? null,
    access: query.access ?? null,
    sort: query.sort ?? null,
    take: query.take ?? null,
  });
}

export function getTemplateRecentGenerationsCacheKey(templateId: string, take?: number): string {
  return `${templateId}:${take ?? "default"}`;
}

export async function cachedGet<TResponse>(
  cacheKey: string,
  cache: Map<string, { value: TResponse; expiresAt: number }>,
  request: () => Promise<TResponse>
): Promise<TResponse> {
  const now = Date.now();
  const cached = cache.get(cacheKey);
  if (cached && cached.expiresAt > now) {
    return cached.value;
  }

  const inflight = inflightGetRequests.get(cacheKey) as Promise<TResponse> | undefined;
  if (inflight) {
    return inflight;
  }

  const promise = request()
    .then((value) => {
      cache.set(cacheKey, { value, expiresAt: Date.now() + ADMIN_LIST_CACHE_TTL_MS });
      return value;
    })
    .finally(() => {
      inflightGetRequests.delete(cacheKey);
    });

  inflightGetRequests.set(cacheKey, promise);
  return promise;
}

export function getSession(): AuthSession | null {
  if (typeof window === "undefined") {
    return null;
  }

  const raw = window.sessionStorage.getItem(AUTH_KEY);
  if (raw === cachedAuthRaw) {
    return cachedAuthSession;
  }

  cachedAuthRaw = raw;
  if (!raw) {
    cachedAuthSession = null;
    return null;
  }

  try {
    const parsed = JSON.parse(raw) as AuthSession;
    if (typeof parsed.refreshToken === "string" && parsed.refreshToken.trim().length > 0) {
      volatileRefreshToken = parsed.refreshToken;
    }

    cachedAuthSession = parsed;
    return cachedAuthSession;
  } catch {
    cachedAuthSession = null;
    return null;
  }
}

export function isAuthSessionExpired(session: AuthSession | null | undefined): boolean {
  if (!session?.expiresAtUtc) {
    return true;
  }

  const expiresAtMs = Date.parse(session.expiresAtUtc);
  return Number.isNaN(expiresAtMs) || expiresAtMs <= Date.now();
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
  return useSyncExternalStore(
    subscribeAuthSession,
    getAuthSessionSnapshot,
    getServerAuthSessionSnapshot
  );
}

export function clearSession(): void {
  clearAdminListCaches();
  volatileRefreshToken = null;

  if (typeof window !== "undefined") {
    window.sessionStorage.removeItem(AUTH_KEY);
    notifyAuthSessionChanged();
  }
}

function sanitizeSessionForStorage(session: AuthSession): AuthSession {
  return { ...session, refreshToken: undefined };
}

function saveSession(session: AuthSession): void {
  clearAdminListCaches();
  volatileRefreshToken = session.refreshToken?.trim() ? session.refreshToken : null;

  if (typeof window !== "undefined") {
    window.sessionStorage.setItem(AUTH_KEY, JSON.stringify(sanitizeSessionForStorage(session)));
    notifyAuthSessionChanged();
  }
}

export async function apiRequest<TResponse>(
  path: string,
  init: RequestInit,
  options: { requireAuth?: boolean; allowRefresh?: boolean } = {}
): Promise<TResponse> {
  const requireAuth = options.requireAuth ?? true;
  const allowRefresh = options.allowRefresh ?? true;
  const session = getSession();

  const headers = new Headers(init.headers);
  if (typeof init.body !== "undefined" && !(init.body instanceof FormData)) {
    headers.set("Content-Type", "application/json");
  }

  if (requireAuth && session?.accessToken) {
    headers.set("Authorization", `Bearer ${session.accessToken}`);
  }

  const abortController = new AbortController();
  let isTimedOut = false;
  const abortHandler = () => {
    abortController.abort();
  };

  if (init.signal) {
    if (init.signal.aborted) {
      abortController.abort();
    } else {
      init.signal.addEventListener("abort", abortHandler, { once: true });
    }
  }

  const timeoutId = globalThis.setTimeout(() => {
    isTimedOut = true;
    abortController.abort();
  }, API_REQUEST_TIMEOUT_MS);

  let response: Response;

  try {
    response = await fetch(`${getApiBaseUrl()}${path}`, {
      ...init,
      headers,
      credentials: "include",
      signal: abortController.signal,
    });
  } catch (error) {
    if (isTimedOut) {
      const timeoutError = new Error("API request timed out") as ApiError;
      timeoutError.code = "request.timeout";
      timeoutError.detail = `Request exceeded ${API_REQUEST_TIMEOUT_MS / 1000} seconds.`;
      throw timeoutError;
    }

    throw error;
  } finally {
    globalThis.clearTimeout(timeoutId);

    if (init.signal) {
      init.signal.removeEventListener("abort", abortHandler);
    }
  }

  if (response.status === 401 && allowRefresh && requireAuth) {
    const refreshed = await refreshSession();
    if (refreshed) {
      return apiRequest<TResponse>(path, init, { requireAuth, allowRefresh: false });
    }
  }

  if (!response.ok) {
    const error = new Error(`API request failed with status ${response.status}`) as ApiError;
    error.status = response.status;

    try {
      const problem = (await response.json()) as {
        title?: string;
        detail?: string;
        errors?: Record<string, string[]>;
      };
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

async function refreshSession(): Promise<boolean> {
  const body = volatileRefreshToken?.trim()
    ? JSON.stringify({ refreshToken: volatileRefreshToken })
    : undefined;

  try {
    const refreshed = await apiRequest<AuthSession>(
      "/api/auth/refresh",
      {
        method: "POST",
        body,
      },
      {
        requireAuth: false,
        allowRefresh: false,
      }
    );

    saveSession(refreshed);
    return true;
  } catch {
    clearSession();
    return false;
  }
}

export async function login(email: string, password: string): Promise<AuthSession> {
  const session = await apiRequest<AuthSession>(
    "/api/auth/login",
    {
      method: "POST",
      body: JSON.stringify({ email, password }),
    },
    {
      requireAuth: false,
      allowRefresh: false,
    }
  );

  saveSession(session);
  return session;
}

export async function logout(): Promise<void> {
  const session = getSession();
  const refreshToken = volatileRefreshToken?.trim() ? volatileRefreshToken : null;

  clearSession();

  if (session?.accessToken || refreshToken) {
    const headers = new Headers();
    const requestBody = refreshToken ? JSON.stringify({ refreshToken }) : undefined;

    if (requestBody) {
      headers.set("Content-Type", "application/json");
    }

    if (session?.accessToken) {
      headers.set("Authorization", `Bearer ${session.accessToken}`);
    }

    void fetch(`${getApiBaseUrl()}/api/auth/logout`, {
      method: "POST",
      headers,
      body: requestBody,
      credentials: "include",
    }).catch(() => {
      // Logout must stay locally instant even when the API is slow or unavailable.
    });
  }
}
