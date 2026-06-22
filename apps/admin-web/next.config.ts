import type { NextConfig } from "next";

type ImageRemotePatterns = NonNullable<NextConfig["images"]>["remotePatterns"];

function shouldAllowLocalApiBaseUrlInProduction(
  rawValue = process.env.ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION
): boolean {
  return rawValue?.trim().toLowerCase() === "true";
}

function normalizeConfiguredApiBaseUrl(
  configuredApiBaseUrl: string | undefined,
  nodeEnv = process.env.NODE_ENV,
  allowLocalApiBaseUrlInProduction = shouldAllowLocalApiBaseUrlInProduction()
): URL | null {
  const normalized = configuredApiBaseUrl?.trim();
  if (!normalized) {
    if (nodeEnv === "production") {
      throw new Error("NEXT_PUBLIC_API_BASE_URL is required for admin production builds.");
    }

    return null;
  }

  const parsed = new URL(normalized);
  assertApiBaseUrlShape(parsed);
  if (nodeEnv === "production") {
    const isLocalHost = isLocalDevelopmentHost(parsed.hostname);

    if (isLocalHost && !allowLocalApiBaseUrlInProduction) {
      throw new Error("Admin production API base URL cannot point to localhost.");
    }

    if (parsed.protocol !== "https:" && !(allowLocalApiBaseUrlInProduction && isLocalHost)) {
      throw new Error("Admin production API base URL must use HTTPS.");
    }

    if (isPlaceholderHost(parsed.hostname)) {
      throw new Error("Admin production API base URL cannot use example.com placeholder hosts.");
    }
  }

  return parsed;
}

function assertApiBaseUrlShape(parsed: URL): void {
  if (parsed.username || parsed.password) {
    throw new Error("Admin API base URL must not include credentials.");
  }

  if (parsed.search || parsed.hash) {
    throw new Error("Admin API base URL must not include query strings or fragments.");
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

function isPlaceholderHost(hostname: string): boolean {
  const normalized = hostname.toLowerCase().replace(/^\[|\]$/g, "");
  return normalized === "example.com" || normalized.endsWith(".example.com");
}

export function apiImageRemotePatterns(
  configuredApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL,
  nodeEnv = process.env.NODE_ENV,
  allowLocalApiBaseUrlInProduction = shouldAllowLocalApiBaseUrlInProduction()
): ImageRemotePatterns {
  const parsedApiBaseUrl = normalizeConfiguredApiBaseUrl(
    configuredApiBaseUrl,
    nodeEnv,
    allowLocalApiBaseUrlInProduction
  );
  const patterns: NonNullable<NextConfig["images"]>["remotePatterns"] = [];

  if (parsedApiBaseUrl) {
    patterns.push(
      {
        protocol: parsedApiBaseUrl.protocol.replace(":", "") as "http" | "https",
        hostname: parsedApiBaseUrl.hostname,
        port: parsedApiBaseUrl.port,
        pathname: "/user-avatars/**",
      },
      {
        protocol: parsedApiBaseUrl.protocol.replace(":", "") as "http" | "https",
        hostname: parsedApiBaseUrl.hostname,
        port: parsedApiBaseUrl.port,
        pathname: "/support-attachments/**",
      }
    );
  }

  if (nodeEnv !== "production") {
    patterns.push(
      {
        protocol: "http",
        hostname: "localhost",
        port: "5000",
        pathname: "/user-avatars/**",
      },
      {
        protocol: "http",
        hostname: "localhost",
        port: "5000",
        pathname: "/support-attachments/**",
      },
      {
        protocol: "http",
        hostname: "127.0.0.1",
        port: "5000",
        pathname: "/user-avatars/**",
      },
      {
        protocol: "http",
        hostname: "127.0.0.1",
        port: "5000",
        pathname: "/support-attachments/**",
      }
    );
  }

  return patterns;
}

const securityHeaders = [
  {
    key: "X-Frame-Options",
    value: "DENY",
  },
  {
    key: "X-Content-Type-Options",
    value: "nosniff",
  },
  {
    key: "Referrer-Policy",
    value: "strict-origin-when-cross-origin",
  },
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=()",
  },
];

const nextConfig: NextConfig = {
  async headers() {
    return [
      {
        source: "/:path*",
        headers: securityHeaders,
      },
    ];
  },
  images: {
    remotePatterns: apiImageRemotePatterns(),
  },
};

export default nextConfig;
