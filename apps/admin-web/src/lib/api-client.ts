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

export type ImageTemplatePayload = {
  title: string;
  shortDescription: string;
  category: string;
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

type ApiError = Error & { status?: number };
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
