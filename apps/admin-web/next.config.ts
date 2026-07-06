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
      throw new Error("Admin production API base URL cannot point to local or private hosts.");
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

function apiOriginsForCsp(
  configuredApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL,
  nodeEnv = process.env.NODE_ENV,
  allowLocalApiBaseUrlInProduction = shouldAllowLocalApiBaseUrlInProduction()
): string[] {
  const parsedApiBaseUrl = normalizeConfiguredApiBaseUrl(
    configuredApiBaseUrl,
    nodeEnv,
    allowLocalApiBaseUrlInProduction
  );
  const origins = new Set<string>();

  if (parsedApiBaseUrl) {
    origins.add(parsedApiBaseUrl.origin);
  }

  if (nodeEnv !== "production") {
    origins.add("http://localhost:5000");
    origins.add("http://127.0.0.1:5000");
  }

  return Array.from(origins);
}

export function buildContentSecurityPolicy(
  configuredApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL,
  nodeEnv = process.env.NODE_ENV,
  allowLocalApiBaseUrlInProduction = shouldAllowLocalApiBaseUrlInProduction()
): string {
  const apiOrigins = apiOriginsForCsp(
    configuredApiBaseUrl,
    nodeEnv,
    allowLocalApiBaseUrlInProduction
  );
  const connectSrc = ["'self'", ...apiOrigins].join(" ");
  const imgSrc = ["'self'", "data:", "blob:", ...apiOrigins].join(" ");

  return [
    "default-src 'self'",
    // Next.js hydration/runtime bootstrap relies on small inline scripts; there is no
    // per-request nonce wiring (no middleware) yet, so 'unsafe-inline' is required here.
    "script-src 'self' 'unsafe-inline'",
    "style-src 'self' 'unsafe-inline'",
    `img-src ${imgSrc}`,
    "font-src 'self' data:",
    `connect-src ${connectSrc}`,
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join("; ");
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
  {
    key: "Content-Security-Policy",
    value: buildContentSecurityPolicy(),
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
