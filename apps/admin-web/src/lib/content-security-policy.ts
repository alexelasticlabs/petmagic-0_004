function resolveApiOrigins(
  configuredApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL,
  nodeEnv = process.env.NODE_ENV
): string[] {
  const origins = new Set<string>();
  const normalized = configuredApiBaseUrl?.trim();

  if (normalized) {
    origins.add(new URL(normalized).origin);
  }

  if (nodeEnv !== "production") {
    origins.add("http://localhost:5000");
    origins.add("http://127.0.0.1:5000");
  }

  return Array.from(origins);
}

export function buildNonceContentSecurityPolicy(
  nonce: string,
  configuredApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL,
  nodeEnv = process.env.NODE_ENV
): string {
  if (!/^[A-Za-z0-9+/=_-]+$/.test(nonce)) {
    throw new Error("CSP nonce contains unsupported characters.");
  }

  const apiOrigins = resolveApiOrigins(configuredApiBaseUrl, nodeEnv);
  const connectSrc = ["'self'", ...apiOrigins].join(" ");
  const imgSrc = ["'self'", "data:", "blob:", ...apiOrigins].join(" ");
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
    `img-src ${imgSrc}`,
    "font-src 'self' data:",
    `connect-src ${connectSrc}`,
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join("; ");
}
