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

  return (
    isAdminLocalDevelopmentHost(normalized) ||
    normalized === "::" ||
    normalized === "0.0.0.0" ||
    isPrivateIpv4Host(normalized) ||
    isPrivateIpv6Host(normalized)
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

  return isPrivateIpv4Bytes(bytes);
}

function isPrivateIpv4Bytes(bytes: readonly number[]): boolean {
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

function isPrivateIpv6Host(hostname: string): boolean {
  if (!hostname.includes(":")) {
    return false;
  }

  if (hostname.startsWith("fc") || hostname.startsWith("fd") || hostname.startsWith("fe80:")) {
    return true;
  }

  const mappedIpv4Bytes = parseIpv4MappedIpv6Bytes(hostname);
  return mappedIpv4Bytes ? isPrivateIpv4Bytes(mappedIpv4Bytes) : false;
}

function parseIpv4MappedIpv6Bytes(hostname: string): readonly number[] | null {
  const prefix = "::ffff:";
  if (!hostname.startsWith(prefix)) {
    return null;
  }

  const mapped = hostname.slice(prefix.length);
  if (mapped.includes(".")) {
    const parts = mapped.split(".");
    if (parts.length !== 4) {
      return null;
    }

    const bytes = parts.map((part) => (/^\d{1,3}$/.test(part) ? Number(part) : Number.NaN));
    return bytes.some((value) => !Number.isInteger(value) || value < 0 || value > 255)
      ? null
      : bytes;
  }

  const groups = mapped.split(":");
  if (groups.length !== 2) {
    return null;
  }

  const words = groups.map((group) => {
    if (!/^[0-9a-f]{1,4}$/.test(group)) {
      return Number.NaN;
    }

    return Number.parseInt(group, 16);
  });

  if (words.some((value) => !Number.isInteger(value) || value < 0 || value > 0xffff)) {
    return null;
  }

  const [high, low] = words;
  return [high >> 8, high & 0xff, low >> 8, low & 0xff];
}
