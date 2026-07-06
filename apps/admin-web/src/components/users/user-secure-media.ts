import { getAdminPublicApiBaseUrl } from "@/lib/admin-api-base-url";
import {
  isAdminLocalDevelopmentHost,
  isUnsafeAdminMediaHost,
} from "@/lib/admin-unsafe-remote-host";
import { clientLogger } from "@/lib/client-logger";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export function getUserMediaFetchErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function getUserMediaUrlResolutionErrorDetails(rawUrl: string, error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    rawLength: rawUrl.length,
    startsWithSlash: rawUrl.startsWith("/"),
    isBlobOrData: rawUrl.startsWith("blob:") || rawUrl.startsWith("data:"),
    digest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function getBlockedLocalUserMediaUrlDetails(rawUrl: string) {
  return {
    rawLength: rawUrl.length,
    startsWithSlash: rawUrl.startsWith("/"),
    isBlobOrData: rawUrl.startsWith("blob:") || rawUrl.startsWith("data:"),
  };
}

function getBlockedUnsafeUserMediaUrlDetails(rawUrl: string) {
  return {
    rawLength: rawUrl.length,
    startsWithSlash: rawUrl.startsWith("/"),
    isBlobOrData: rawUrl.startsWith("blob:") || rawUrl.startsWith("data:"),
  };
}

export function resolveUserMediaUrl(rawUrl?: string | null): string | null {
  const normalizedRaw = rawUrl?.trim();
  if (!normalizedRaw) {
    return null;
  }

  const apiBase = getAdminPublicApiBaseUrl();
  const apiOrigin = new URL(apiBase).origin;

  if (normalizedRaw.startsWith("/")) {
    return `${apiOrigin}${normalizedRaw}`;
  }

  try {
    const parsed = new URL(normalizedRaw);
    if (isLocalDevelopmentHost(parsed.hostname)) {
      if (!isLocalDevelopmentHost(new URL(apiOrigin).hostname)) {
        clientLogger.warn(
          "users.media_url_localhost_blocked",
          getBlockedLocalUserMediaUrlDetails(normalizedRaw)
        );
        return null;
      }

      return `${apiOrigin}${parsed.pathname}${parsed.search}${parsed.hash}`;
    }

    if (isUnsafeUserMediaHost(parsed.hostname)) {
      clientLogger.warn(
        "users.media_url_unsafe_host_blocked",
        getBlockedUnsafeUserMediaUrlDetails(normalizedRaw)
      );
      return null;
    }

    return parsed.toString();
  } catch (error) {
    clientLogger.warn(
      "users.media_url_resolve_failed",
      getUserMediaUrlResolutionErrorDetails(normalizedRaw, error)
    );
    return null;
  }
}

export function isLocalObjectUrl(url: string) {
  return url.startsWith("blob:") || url.startsWith("data:");
}

function isLocalDevelopmentHost(hostname: string): boolean {
  return isAdminLocalDevelopmentHost(hostname);
}

function isUnsafeUserMediaHost(hostname: string): boolean {
  return isUnsafeAdminMediaHost(hostname);
}
