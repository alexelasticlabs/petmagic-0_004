import {
  isAdminLocalDevelopmentHost,
  isUnsafeAdminMediaHost,
} from "@/lib/admin-unsafe-remote-host";

function shouldAllowLocalApiBaseUrlInProduction(
  rawValue = process.env.NEXT_PUBLIC_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION
): boolean {
  return rawValue?.trim().toLowerCase() === "true";
}

function resolveApiOrigins(
  configuredApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL,
  nodeEnv = process.env.NODE_ENV,
  allowLocalApiBaseUrlInProduction = shouldAllowLocalApiBaseUrlInProduction()
): string[] {
  const origins = new Set<string>();
  const normalized = configuredApiBaseUrl?.trim();

  if (normalized) {
    const parsed = new URL(normalized);
    if (parsed.username || parsed.password) {
      throw new Error("NEXT_PUBLIC_API_BASE_URL must be credential-free.");
    }
    if (nodeEnv === "production") {
      const isLocalHost = isAdminLocalDevelopmentHost(parsed.hostname);
      const isAllowedLocalOrigin = allowLocalApiBaseUrlInProduction && isLocalHost;

      if (parsed.protocol !== "https:" && !isAllowedLocalOrigin) {
        throw new Error("NEXT_PUBLIC_API_BASE_URL must use HTTPS in production.");
      }
      if (isUnsafeAdminMediaHost(parsed.hostname) && !isAllowedLocalOrigin) {
        throw new Error(
          "NEXT_PUBLIC_API_BASE_URL cannot target local, private, or placeholder hosts."
        );
      }
    } else if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      throw new Error("NEXT_PUBLIC_API_BASE_URL must use HTTP or HTTPS.");
    }

    origins.add(parsed.origin);
  }

  if (nodeEnv !== "production") {
    origins.add("http://localhost:5000");
    origins.add("http://127.0.0.1:5000");
  }

  return Array.from(origins);
}

function resolveMediaOrigins(
  configuredMediaOrigins = process.env.ADMIN_MEDIA_ORIGINS,
  nodeEnv = process.env.NODE_ENV
): string[] {
  const origins = new Set<string>();

  for (const rawOrigin of configuredMediaOrigins?.split(",") ?? []) {
    const normalized = rawOrigin.trim();
    if (!normalized) {
      continue;
    }

    const parsed = new URL(normalized);
    if (parsed.username || parsed.password || parsed.search || parsed.hash) {
      throw new Error("ADMIN_MEDIA_ORIGINS entries must be credential-free origins.");
    }
    if (parsed.pathname !== "/") {
      throw new Error("ADMIN_MEDIA_ORIGINS entries must not include paths.");
    }
    if (nodeEnv === "production") {
      if (parsed.protocol !== "https:") {
        throw new Error("ADMIN_MEDIA_ORIGINS entries must use HTTPS in production.");
      }
      if (isUnsafeAdminMediaHost(parsed.hostname)) {
        throw new Error(
          "ADMIN_MEDIA_ORIGINS entries cannot target local, private, or placeholder hosts."
        );
      }
    } else if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      throw new Error("ADMIN_MEDIA_ORIGINS entries must use HTTP or HTTPS.");
    }

    origins.add(parsed.origin);
  }

  return Array.from(origins);
}

export function buildNonceContentSecurityPolicy(
  nonce: string,
  configuredApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL,
  nodeEnv = process.env.NODE_ENV,
  configuredMediaOrigins = process.env.ADMIN_MEDIA_ORIGINS,
  allowLocalApiBaseUrlInProduction = shouldAllowLocalApiBaseUrlInProduction()
): string {
  if (!/^[A-Za-z0-9+/=_-]+$/.test(nonce)) {
    throw new Error("CSP nonce contains unsupported characters.");
  }

  const apiOrigins = resolveApiOrigins(
    configuredApiBaseUrl,
    nodeEnv,
    allowLocalApiBaseUrlInProduction
  );
  const mediaOrigins = resolveMediaOrigins(configuredMediaOrigins, nodeEnv);
  const remoteOrigins = Array.from(new Set([...apiOrigins, ...mediaOrigins]));
  const connectSrc = ["'self'", ...remoteOrigins].join(" ");
  const imgSrc = ["'self'", "data:", "blob:", ...remoteOrigins].join(" ");
  const mediaSrc = ["'self'", "blob:", ...remoteOrigins].join(" ");
  const scriptSrc = [
    "'self'",
    `'nonce-${nonce}'`,
    "'strict-dynamic'",
    ...(nodeEnv === "production" ? [] : ["'unsafe-eval'"]),
  ].join(" ");
  const styleSrc = [
    "'self'",
    `'nonce-${nonce}'`,
    ...(nodeEnv === "production" ? [] : ["'unsafe-inline'"]),
  ].join(" ");

  return [
    "default-src 'self'",
    `script-src ${scriptSrc}`,
    `style-src ${styleSrc}`,
    "style-src-attr 'unsafe-inline'",
    `img-src ${imgSrc}`,
    `media-src ${mediaSrc}`,
    "font-src 'self' data:",
    `connect-src ${connectSrc}`,
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join("; ");
}
