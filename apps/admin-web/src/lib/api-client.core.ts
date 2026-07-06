"use client";

import { useSyncExternalStore } from "react";

import { getAdminApiBaseUrl } from "./admin-api-base-url";
import { createAdminCorrelationId } from "./admin-correlation-id";
import { clientLogger } from "./client-logger";
import { sanitizeSensitiveText } from "./sensitive-display";

import type {
  AcceptLegalDocumentsCommand,
  AdminSupportReplyTemplate,
  AdminTemplateCategory,
  AdminTemplateEventAnalytics,
  AdminTemplateFailureBreakdownItem,
  AdminTemplateCatalogPage,
  AdminTemplateRecentGeneration,
  AdminTemplateStatistics,
  AdminTemplateTrendPoint,
  AdminTemplatesAnalyticsOverview,
  AdminTemplatesAnalyticsQuery,
  AdminUserAnalytics,
  AdminUserDetail,
  AuthSession,
  LegalDocumentsResponse,
  UserProfile,
  UserListPage,
} from "./api-client.types";

const AUTH_KEY = "petmagic_admin_auth";
const AUTH_SESSION_EVENT = "petmagic_admin_auth_changed";
const ADMIN_LIST_CACHE_TTL_MS = 120_000;
const API_REQUEST_TIMEOUT_MS = 15_000;
const LOGOUT_REQUEST_TIMEOUT_MS = 5_000;

type ApiError = Error & {
  status?: number;
  detail?: string;
  code?: string;
  validationErrors?: string[];
};
type AuthSessionSnapshot = AuthSession | null | undefined;
type JsonRecord = Record<string, unknown>;

let cachedAuthRaw: string | null | undefined;
let cachedAuthSession: AuthSession | null = null;
let volatileAccessToken: string | null = null;
let volatileRefreshToken: string | null = null;
let volatileTokenUserId: string | null = null;
let refreshSessionInFlight: Promise<boolean> | null = null;
let authSessionMutationVersion = 0;
export const cachedUsersLists = new Map<string, { value: UserListPage; expiresAt: number }>();
export const cachedAdminUserDetails = new Map<
  string,
  { value: AdminUserDetail; expiresAt: number }
>();
export const cachedAdminUserAnalytics = new Map<
  string,
  { value: AdminUserAnalytics; expiresAt: number }
>();
export const cachedSupportTemplates = new Map<
  string,
  { value: AdminSupportReplyTemplate[]; expiresAt: number }
>();
export const cachedTemplateLists = new Map<
  string,
  { value: AdminTemplateCatalogPage; expiresAt: number }
>();
export const cachedTemplateCategories = new Map<
  string,
  { value: AdminTemplateCategory[]; expiresAt: number }
>();
export const cachedTemplatesAnalyticsOverview = new Map<
  string,
  { value: AdminTemplatesAnalyticsOverview; expiresAt: number }
>();
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

function getAuthStorageErrorDetails(error: unknown): {
  errorName: string;
  errorDigest?: string;
} {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function resetInMemoryAuthSessionState(): void {
  cachedAuthRaw = null;
  cachedAuthSession = null;
  volatileAccessToken = null;
  volatileRefreshToken = null;
  volatileTokenUserId = null;
  refreshSessionInFlight = null;
}

function suppressPersistedAuthSession(raw: string | null): void {
  cachedAuthRaw = raw;
  cachedAuthSession = null;
}

function clearStoredAuthSession(storageFailureEvent: string, storedRaw?: string | null): boolean {
  resetInMemoryAuthSessionState();
  if (typeof window === "undefined") {
    return true;
  }

  try {
    window.sessionStorage.removeItem(AUTH_KEY);
    suppressPersistedAuthSession(null);
    return true;
  } catch (storageError) {
    suppressPersistedAuthSession(storedRaw ?? null);
    clientLogger.warn(storageFailureEvent, getAuthStorageErrorDetails(storageError));
    return false;
  }
}

function readStoredAuthSessionRaw(storageFailureEvent: string): string | null {
  try {
    return window.sessionStorage.getItem(AUTH_KEY);
  } catch (storageError) {
    resetInMemoryAuthSessionState();
    clientLogger.warn(storageFailureEvent, getAuthStorageErrorDetails(storageError));
    return null;
  }
}

export function clearAdminListCaches(): void {
  cachedUsersLists.clear();
  cachedAdminUserDetails.clear();
  cachedAdminUserAnalytics.clear();
  cachedSupportTemplates.clear();
  cachedTemplateLists.clear();
  cachedTemplateCategories.clear();
  cachedTemplatesAnalyticsOverview.clear();
  cachedAdminTemplateStatistics.clear();
  cachedAdminTemplateTrends.clear();
  cachedAdminTemplateRecentGenerations.clear();
  cachedAdminTemplateFailureBreakdowns.clear();
  cachedAdminTemplateEventAnalytics.clear();
  inflightGetRequests.clear();
}

export function getTemplateListCacheKey(value?: string): string {
  return value ?? "all";
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

export function encodePathSegment(value: string): string {
  return encodeURIComponent(value);
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string");
}

function isValidUserProfile(value: unknown): value is UserProfile {
  if (!isRecord(value)) {
    return false;
  }

  return (
    typeof value.userId === "string" &&
    value.userId.trim().length > 0 &&
    typeof value.email === "string" &&
    value.email.trim().length > 0 &&
    typeof value.isPremium === "boolean" &&
    typeof value.emailConfirmed === "boolean" &&
    isStringArray(value.roles)
  );
}

function validateAuthSession(
  value: unknown,
  source: string,
  options: { requireAccessToken?: boolean } = {}
): AuthSession {
  if (!isRecord(value)) {
    throw new Error(`${source} auth session is not an object.`);
  }

  if (!isValidUserProfile(value.user)) {
    throw new Error(`${source} auth session is missing required user fields.`);
  }

  if (typeof value.expiresAtUtc !== "string" || value.expiresAtUtc.trim().length === 0) {
    throw new Error(`${source} auth session is missing expiresAtUtc.`);
  }

  if (typeof value.accessToken !== "undefined" && typeof value.accessToken !== "string") {
    throw new Error(`${source} auth session has an invalid accessToken.`);
  }

  if (options.requireAccessToken && !value.accessToken?.trim()) {
    throw new Error(`${source} auth session is missing accessToken.`);
  }

  if (typeof value.refreshToken !== "undefined" && typeof value.refreshToken !== "string") {
    throw new Error(`${source} auth session has an invalid refreshToken.`);
  }

  return value as AuthSession;
}

export async function cachedGet<TResponse>(
  cacheKey: string,
  cache: Map<string, { value: TResponse; expiresAt: number }>,
  request: () => Promise<TResponse>,
  signal?: AbortSignal
): Promise<TResponse> {
  const now = Date.now();
  const cached = cache.get(cacheKey);
  if (cached && cached.expiresAt > now) {
    return cached.value;
  }

  if (signal?.aborted) {
    throw new DOMException("Aborted", "AbortError");
  }

  if (signal) {
    const value = await request();
    cache.set(cacheKey, { value, expiresAt: Date.now() + ADMIN_LIST_CACHE_TTL_MS });
    return value;
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

  const raw = readStoredAuthSessionRaw("auth.session_read_failed");
  if (raw === cachedAuthRaw) {
    return cachedAuthSession;
  }

  cachedAuthRaw = raw;
  if (!raw) {
    cachedAuthSession = null;
    return null;
  }

  try {
    const parsed = validateAuthSession(JSON.parse(raw), "Stored");
    const hasStoredToken =
      (typeof parsed.refreshToken === "string" && parsed.refreshToken.trim().length > 0) ||
      (typeof parsed.accessToken === "string" && parsed.accessToken.trim().length > 0);

    if (hasStoredToken) {
      clientLogger.warn("auth.persisted_token_session_cleared", {
        hasAccessToken: Boolean(parsed.accessToken?.trim()),
        hasRefreshToken: Boolean(parsed.refreshToken?.trim()),
      });
      clearStoredAuthSession("auth.persisted_token_session_cleanup_failed", raw);
      return null;
    }

    const parsedUserId = parsed.user?.userId ?? null;
    if (volatileTokenUserId && volatileTokenUserId !== parsedUserId) {
      volatileAccessToken = null;
      volatileRefreshToken = null;
      volatileTokenUserId = null;
    }
    if (volatileAccessToken) {
      parsed.accessToken = volatileAccessToken;
    } else {
      parsed.accessToken = undefined;
    }
    parsed.refreshToken = undefined;

    cachedAuthSession = parsed;
    return cachedAuthSession;
  } catch (error) {
    clientLogger.warn("auth.session_parse_failed", getAuthStorageErrorDetails(error));
    clearStoredAuthSession("auth.session_parse_cleanup_failed", raw);
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

function notifyAuthSessionChanged(options: { invalidateStoredSnapshot?: boolean } = {}): void {
  if (options.invalidateStoredSnapshot ?? true) {
    cachedAuthRaw = undefined;
  }
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
  authSessionMutationVersion += 1;

  if (typeof window !== "undefined") {
    const storedRaw = readStoredAuthSessionRaw("auth.session_clear_read_failed");
    const storageCleared = clearStoredAuthSession("auth.session_clear_failed", storedRaw);
    notifyAuthSessionChanged({ invalidateStoredSnapshot: storageCleared });
    return;
  }

  resetInMemoryAuthSessionState();
}

function getFallbackApiErrorMessage(status: number): string {
  if (status === 400) {
    return "Request data is invalid.";
  }

  if (status === 401) {
    return "Session expired. Sign in again.";
  }

  if (status === 403) {
    return "You do not have permission to perform this action.";
  }

  if (status === 404) {
    return "Requested resource was not found.";
  }

  if (status === 409) {
    return "This action conflicts with the current server state.";
  }

  if (status === 422) {
    return "Request validation failed.";
  }

  if (status >= 500) {
    return "Server error. Try again later.";
  }

  return "Request failed. Try again.";
}

function isTechnicalProblemMessage(value: string): boolean {
  const trimmed = value.trim();
  return (
    /^[a-z0-9_.-]+$/i.test(trimmed) ||
    /^API request failed with status \d+$/i.test(trimmed) ||
    /^(?:TypeError|Error|SyntaxError|ReferenceError):/i.test(trimmed) ||
    trimmed.startsWith("{") ||
    trimmed.startsWith("[")
  );
}

function sanitizeApiErrorText(value: string): string {
  return sanitizeSensitiveText(value, 240);
}

function sanitizeApiLogPath(path: string): string {
  try {
    const parsed = new URL(path, "https://admin.petmagic.local");
    const safePathname = sanitizeSensitiveText(parsed.pathname, 160);
    return parsed.search ? `${safePathname}?query=[redacted]` : safePathname;
  } catch {
    return sanitizeSensitiveText(path.split("?")[0] || path, 160);
  }
}

function getApiClientErrorDetails(error: unknown): {
  errorName: string;
  errorDigest?: string;
} {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function getApiPayloadParseErrorDetails(error: unknown): {
  errorName: string;
  errorDigest?: string;
} {
  return getApiClientErrorDetails(error);
}

function isJsonResponse(response: Response): boolean {
  const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
  return contentType.includes("application/json") || contentType.includes("+json");
}

function createApiError(message: string, code: string, detail?: string): ApiError {
  const error = new Error(message) as ApiError;
  error.code = code;
  error.detail = detail;
  return error;
}

function isIdempotentRequestMethod(method: string | undefined): boolean {
  const normalizedMethod = (method ?? "GET").trim().toUpperCase();
  return (
    normalizedMethod === "GET" || normalizedMethod === "HEAD" || normalizedMethod === "OPTIONS"
  );
}

function sanitizeSessionForStorage(session: AuthSession): AuthSession {
  return { ...session, accessToken: undefined, refreshToken: undefined };
}

function saveSession(session: AuthSession): void {
  const validSession = validateAuthSession(session, "Backend", {
    requireAccessToken: true,
  });

  clearAdminListCaches();
  authSessionMutationVersion += 1;
  volatileAccessToken = validSession.accessToken?.trim() ? validSession.accessToken : null;
  volatileRefreshToken = validSession.refreshToken?.trim() ? validSession.refreshToken : null;
  volatileTokenUserId = validSession.user.userId;

  if (typeof window !== "undefined") {
    try {
      window.sessionStorage.setItem(
        AUTH_KEY,
        JSON.stringify(sanitizeSessionForStorage(validSession))
      );
      notifyAuthSessionChanged();
    } catch (storageError) {
      resetInMemoryAuthSessionState();
      clientLogger.warn("auth.session_save_failed", getAuthStorageErrorDetails(storageError));
      notifyAuthSessionChanged();
      throw new Error("Unable to persist admin session.");
    }
  }
}

export async function apiRequest<TResponse>(
  path: string,
  init: RequestInit,
  options: { requireAuth?: boolean; allowRefresh?: boolean; timeoutMs?: number } = {}
): Promise<TResponse> {
  const requireAuth = options.requireAuth ?? true;
  const allowRefresh = options.allowRefresh ?? true;
  const timeoutMs = options.timeoutMs ?? API_REQUEST_TIMEOUT_MS;
  const session = getSession();
  const logPath = sanitizeApiLogPath(path);

  const headers = new Headers(init.headers);
  if (typeof init.body !== "undefined" && !(init.body instanceof FormData)) {
    headers.set("Content-Type", "application/json");
  }
  if (!headers.has("X-Correlation-ID")) {
    headers.set("X-Correlation-ID", createAdminCorrelationId());
  }

  if (requireAuth && session?.accessToken) {
    headers.set("Authorization", `Bearer ${session.accessToken}`);
  }

  if (requireAuth && allowRefresh && !session?.accessToken && typeof window !== "undefined") {
    const restored = await refreshSession();
    if (restored) {
      return apiRequest<TResponse>(path, init, { requireAuth, allowRefresh: false });
    }
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
  }, timeoutMs);

  let response: Response;

  try {
    response = await fetch(`${getAdminApiBaseUrl()}${path}`, {
      ...init,
      headers,
      credentials: "include",
      signal: abortController.signal,
    });
  } catch (error) {
    if (isTimedOut) {
      clientLogger.warn("api.request_timeout", {
        path: logPath,
        method: init.method ?? "GET",
        correlationId: headers.get("X-Correlation-ID"),
      });
      const timeoutError = new Error("Request timed out. Try again.") as ApiError;
      timeoutError.code = "request.timeout";
      timeoutError.detail = "Request timed out.";
      throw timeoutError;
    }

    const wasManuallyAborted = abortController.signal.aborted;
    if (wasManuallyAborted) {
      throw error;
    }

    clientLogger.warn("api.request_failed", {
      path: logPath,
      method: init.method ?? "GET",
      correlationId: headers.get("X-Correlation-ID"),
      ...getApiClientErrorDetails(error),
    });

    const networkError = new Error("Network error. Check connection and try again.") as ApiError;
    networkError.code = "request.network_error";
    networkError.detail = "Network request failed.";
    throw networkError;
  } finally {
    globalThis.clearTimeout(timeoutId);

    if (init.signal) {
      init.signal.removeEventListener("abort", abortHandler);
    }
  }

  if (response.status === 401 && allowRefresh && requireAuth) {
    const refreshed = await refreshSession();
    if (refreshed) {
      if (isIdempotentRequestMethod(init.method)) {
        return apiRequest<TResponse>(path, init, { requireAuth, allowRefresh: false });
      }

      clientLogger.warn("api.auth_retry_required_after_refresh", {
        path: logPath,
        method: init.method ?? "GET",
        correlationId: headers.get("X-Correlation-ID"),
      });

      const retryError = new Error(
        "Session was refreshed. Review and retry this action."
      ) as ApiError;
      retryError.status = 409;
      retryError.code = "auth.retry_required_after_refresh";
      retryError.detail = "Non-idempotent request was not replayed after token refresh.";
      throw retryError;
    }
  }

  if (!response.ok) {
    if (response.status === 401 && requireAuth) {
      clearSession();
    }

    clientLogger.warn("api.request_non_success", {
      path: logPath,
      method: init.method ?? "GET",
      status: response.status,
      correlationId: headers.get("X-Correlation-ID"),
    });

    const fallbackMessage = getFallbackApiErrorMessage(response.status);
    const error = new Error(fallbackMessage) as ApiError;
    error.status = response.status;

    if (isJsonResponse(response)) {
      try {
        const problem = (await response.json()) as {
          title?: string;
          detail?: string;
          errors?: Record<string, string[]>;
        };
        error.code = problem.title ? sanitizeApiErrorText(problem.title) : undefined;
        error.detail = problem.detail ? sanitizeApiErrorText(problem.detail) : undefined;
        const validationErrors = Object.values(problem.errors ?? {})
          .flat()
          .map((value) => value.trim())
          .filter((value) => value && !isTechnicalProblemMessage(value))
          .map((value) => sanitizeApiErrorText(value))
          .filter(Boolean);

        if (validationErrors.length > 0) {
          error.validationErrors = validationErrors;
        }

        if (problem.detail && !isTechnicalProblemMessage(problem.detail)) {
          error.message = sanitizeApiErrorText(problem.detail);
        } else if (validationErrors.length > 0) {
          error.message = validationErrors.join(" ");
        } else if (problem.title && !isTechnicalProblemMessage(problem.title)) {
          error.message = sanitizeApiErrorText(problem.title);
        } else {
          error.message = fallbackMessage;
        }
      } catch (parseError) {
        clientLogger.warn("api.error_payload_parse_failed", {
          path: logPath,
          method: init.method ?? "GET",
          status: response.status,
          correlationId: headers.get("X-Correlation-ID"),
          ...getApiPayloadParseErrorDetails(parseError),
        });
      }
    }

    throw error;
  }

  if (response.status === 204) {
    return undefined as TResponse;
  }

  const responseText = await response.text();
  if (!responseText.trim()) {
    return undefined as TResponse;
  }

  try {
    return JSON.parse(responseText) as TResponse;
  } catch (error) {
    clientLogger.warn("api.response_payload_parse_failed", {
      path: logPath,
      method: init.method ?? "GET",
      status: response.status,
      correlationId: headers.get("X-Correlation-ID"),
      ...getApiPayloadParseErrorDetails(error),
    });
    throw createApiError(
      "Unexpected server response. Try again.",
      "response.invalid_json",
      "Response body was not valid JSON."
    );
  }
}

async function refreshSessionInternal(): Promise<boolean> {
  const refreshToken = volatileRefreshToken?.trim() ? volatileRefreshToken : null;
  const mutationVersionAtStart = authSessionMutationVersion;
  const body = refreshToken ? JSON.stringify({ refreshToken }) : undefined;

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

    if (mutationVersionAtStart !== authSessionMutationVersion) {
      return false;
    }

    saveSession(refreshed);
    return true;
  } catch (error) {
    clientLogger.warn("auth.refresh_failed", {
      hasRefreshToken: Boolean(refreshToken),
      ...getApiClientErrorDetails(error),
    });
    clearSession();
    return false;
  }
}

async function refreshSession(): Promise<boolean> {
  if (refreshSessionInFlight) {
    return refreshSessionInFlight;
  }

  refreshSessionInFlight = refreshSessionInternal().finally(() => {
    refreshSessionInFlight = null;
  });
  return refreshSessionInFlight;
}

export async function restoreSession(): Promise<boolean> {
  return refreshSession();
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

export async function fetchCurrentLegalDocuments(locale?: string): Promise<LegalDocumentsResponse> {
  const suffix = locale ? `?locale=${encodeURIComponent(locale)}` : "";
  return apiRequest<LegalDocumentsResponse>(
    `/api/legal/current${suffix}`,
    {
      method: "GET",
    },
    {
      requireAuth: false,
      allowRefresh: false,
    }
  );
}

export async function acceptCurrentLegalDocuments(
  command: AcceptLegalDocumentsCommand
): Promise<UserProfile> {
  return apiRequest<UserProfile>(
    "/api/legal/accept",
    {
      method: "POST",
      body: JSON.stringify(command),
    },
    {
      requireAuth: true,
      allowRefresh: true,
    }
  );
}

export async function logout(): Promise<void> {
  const session = getSession();
  const refreshToken = volatileRefreshToken?.trim() ? volatileRefreshToken : null;
  const accessToken = volatileAccessToken?.trim() ? volatileAccessToken : session?.accessToken;

  clearSession();

  if (accessToken || refreshToken) {
    const headers = new Headers();
    const requestBody = refreshToken ? JSON.stringify({ refreshToken }) : undefined;
    const logoutAbortController = new AbortController();
    const logoutTimeoutId = globalThis.setTimeout(() => {
      logoutAbortController.abort();
    }, LOGOUT_REQUEST_TIMEOUT_MS);

    if (requestBody) {
      headers.set("Content-Type", "application/json");
    }
    headers.set("X-Correlation-ID", createAdminCorrelationId());

    if (accessToken) {
      headers.set("Authorization", `Bearer ${accessToken}`);
    }

    void fetch(`${getAdminApiBaseUrl()}/api/auth/logout`, {
      method: "POST",
      headers,
      body: requestBody,
      credentials: "include",
      signal: logoutAbortController.signal,
    })
      .catch((error: unknown) => {
        if (!logoutAbortController.signal.aborted) {
          clientLogger.warn("auth.logout_failed", getAuthStorageErrorDetails(error));
        }
      })
      .finally(() => {
        globalThis.clearTimeout(logoutTimeoutId);
      });
  }
}
