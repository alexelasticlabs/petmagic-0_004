export function isAdminLocalDevelopmentHost(hostname: string): boolean {
  const normalized = normalizeHostname(hostname);
  return (
    normalized === "localhost" ||
    normalized.endsWith(".localhost") ||
    normalized === "host.docker.internal" ||
    normalized === "backend" ||
    normalized === "::1" ||
    normalized === "127.0.0.1"
  );
}

export function isLocalOrPrivateAdminRemoteHost(hostname: string): boolean {
  const normalized = normalizeHostname(hostname);
  const isIpv6Literal = normalized.includes(":");

  return (
    isAdminLocalDevelopmentHost(normalized) ||
    normalized === "::" ||
    normalized === "0.0.0.0" ||
    isPrivateIpv4Host(normalized) ||
    (isIpv6Literal &&
      (normalized.startsWith("fc") ||
        normalized.startsWith("fd") ||
        normalized.startsWith("fe80:")))
  );
}

export function isUnsafeAdminMediaHost(hostname: string): boolean {
  const normalized = normalizeHostname(hostname);
  return isLocalOrPrivateAdminRemoteHost(normalized) || isPlaceholderHost(normalized);
}

function normalizeHostname(hostname: string): string {
  return hostname
    .toLowerCase()
    .replace(/^\[|\]$/g, "")
    .replace(/\.$/, "");
}

function isPlaceholderHost(hostname: string): boolean {
  return hostname === "example.com" || hostname.endsWith(".example.com");
}

function isPrivateIpv4Host(hostname: string): boolean {
  const parts = hostname.split(".");
  if (parts.length !== 4) {
    return false;
  }

  const bytes = parts.map((part) => {
    if (!/^\d{1,3}$/.test(part)) {
      return Number.NaN;
    }

    return Number(part);
  });

  if (bytes.some((value) => !Number.isInteger(value) || value < 0 || value > 255)) {
    return false;
  }

  const [first, second] = bytes;
  return (
    first === 10 ||
    first === 127 ||
    (first === 169 && second === 254) ||
    (first === 172 && second >= 16 && second <= 31) ||
    (first === 192 && second === 168) ||
    (first === 100 && second >= 64 && second <= 127) ||
    first >= 224
  );
}
