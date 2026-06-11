const LOCAL_API_BASE_URL = "http://localhost:5000";

type ResolveAdminApiBaseUrlOptions = {
  internalApiBaseUrl?: string | null;
  publicApiBaseUrl?: string | null;
  isServer: boolean;
  nodeEnv?: string;
  allowLocalApiBaseUrlInProduction?: boolean;
};

function shouldAllowLocalApiBaseUrlInProduction(
  rawValue = process.env.NEXT_PUBLIC_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION
): boolean {
  return rawValue?.trim().toLowerCase() === "true";
}

export function resolveAdminApiBaseUrl({
  internalApiBaseUrl,
  publicApiBaseUrl,
  isServer,
  nodeEnv = process.env.NODE_ENV,
  allowLocalApiBaseUrlInProduction = shouldAllowLocalApiBaseUrlInProduction(),
}: ResolveAdminApiBaseUrlOptions): string {
  const configured = normalizeBaseUrl(
    (isServer ? internalApiBaseUrl || publicApiBaseUrl : publicApiBaseUrl)?.trim()
  );

  if (configured) {
    assertProductionSafeApiBaseUrl(configured, nodeEnv, allowLocalApiBaseUrlInProduction);
    return configured;
  }

  if (nodeEnv === "production") {
    throw new Error(
      isServer
        ? "INTERNAL_API_BASE_URL or NEXT_PUBLIC_API_BASE_URL is required for admin production builds."
        : "NEXT_PUBLIC_API_BASE_URL is required for admin production builds."
    );
  }

  return LOCAL_API_BASE_URL;
}

export function getAdminApiBaseUrl(): string {
  return resolveAdminApiBaseUrl({
    internalApiBaseUrl: process.env.INTERNAL_API_BASE_URL,
    publicApiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL,
    isServer: typeof window === "undefined",
  });
}

export function getAdminPublicApiBaseUrl(): string {
  return resolveAdminApiBaseUrl({
    publicApiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL,
    isServer: false,
  });
}

function normalizeBaseUrl(value: string | null | undefined): string | null {
  if (!value) {
    return null;
  }

  const parsed = new URL(value);
  assertApiBaseUrlShape(parsed);
  return parsed.toString().replace(/\/$/, "");
}

function assertApiBaseUrlShape(parsed: URL): void {
  if (parsed.username || parsed.password) {
    throw new Error("Admin API base URL must not include credentials.");
  }

  if (parsed.search || parsed.hash) {
    throw new Error("Admin API base URL must not include query strings or fragments.");
  }
}

function assertProductionSafeApiBaseUrl(
  value: string,
  nodeEnv: string | undefined,
  allowLocalApiBaseUrlInProduction: boolean
): void {
  if (nodeEnv !== "production") {
    return;
  }

  const parsed = new URL(value);
  const isLocalHost = isLocalDevelopmentHost(parsed.hostname);

  if (isLocalHost && !allowLocalApiBaseUrlInProduction) {
    throw new Error("Admin production API base URL cannot point to localhost.");
  }

  if (parsed.protocol !== "https:" && !(allowLocalApiBaseUrlInProduction && isLocalHost)) {
    throw new Error("Admin production API base URL must use HTTPS.");
  }
}

function isLocalDevelopmentHost(hostname: string): boolean {
  const normalized = hostname.toLowerCase().replace(/^\[|\]$/g, "");
  return (
    normalized === "localhost" ||
    normalized === "127.0.0.1" ||
    normalized === "::1" ||
    normalized === "0.0.0.0"
  );
}
