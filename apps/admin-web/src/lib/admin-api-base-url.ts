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
    throw new Error("Admin production API base URL cannot point to local or private hosts.");
  }

  if (parsed.protocol !== "https:" && !(allowLocalApiBaseUrlInProduction && isLocalHost)) {
    throw new Error("Admin production API base URL must use HTTPS.");
  }

  if (isPlaceholderHost(parsed.hostname)) {
    throw new Error("Admin production API base URL cannot use example.com placeholder hosts.");
  }
}

function isLocalDevelopmentHost(hostname: string): boolean {
  const normalized = hostname.toLowerCase().replace(/^\[|\]$/g, "");
  const ipv4 = parseIpv4(normalized);
  return (
    normalized === "localhost" ||
    normalized.endsWith(".localhost") ||
    normalized === "host.docker.internal" ||
    normalized === "backend" ||
    normalized === "127.0.0.1" ||
    normalized === "::1" ||
    normalized === "::" ||
    normalized === "0.0.0.0" ||
    isPrivateIpv4(ipv4) ||
    isPrivateIpv6Host(normalized)
  );
}

function parseIpv4(hostname: string): number[] | null {
  const parts = hostname.split(".");
  if (parts.length !== 4) {
    return null;
  }

  const parsed = parts.map((part) => {
    if (!/^\d{1,3}$/.test(part)) {
      return Number.NaN;
    }

    return Number(part);
  });

  return parsed.every((part) => Number.isInteger(part) && part >= 0 && part <= 255) ? parsed : null;
}

function isPrivateIpv4(parts: number[] | null): boolean {
  if (!parts) {
    return false;
  }

  const [first, second] = parts;
  return (
    first === 0 ||
    first === 10 ||
    first === 127 ||
    (first === 100 && second >= 64 && second <= 127) ||
    (first === 169 && second === 254) ||
    (first === 172 && second >= 16 && second <= 31) ||
    (first === 192 && second === 168) ||
    first >= 224
  );
}

function isPrivateIpv6Host(hostname: string): boolean {
  return hostname.startsWith("fc") || hostname.startsWith("fd") || hostname.startsWith("fe80:");
}

function isPlaceholderHost(hostname: string): boolean {
  const normalized = hostname.toLowerCase().replace(/^\[|\]$/g, "");
  return normalized === "example.com" || normalized.endsWith(".example.com");
}
