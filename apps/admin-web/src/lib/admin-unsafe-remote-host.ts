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
  const legacyBytes = parseLegacyIpv4HostBytes(hostname);
  if (legacyBytes) {
    return isPrivateIpv4Bytes(legacyBytes);
  }

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

function parseLegacyIpv4HostBytes(hostname: string): readonly number[] | null {
  const parts = hostname.split(".");
  if (parts.length < 1 || parts.length > 4 || parts.some((part) => part.length === 0)) {
    return null;
  }

  const values = parts.map(parseLegacyIpv4Part);
  if (values.some((value) => value === null || value < 0)) {
    return null;
  }

  const numeric = values as number[];
  const lastMax = 2 ** (8 * (5 - numeric.length));
  if (
    numeric.slice(0, -1).some((value) => value > 0xff) ||
    numeric[numeric.length - 1] >= lastMax
  ) {
    return null;
  }

  let address = 0;
  for (let index = 0; index < numeric.length - 1; index += 1) {
    address = (address << 8) | numeric[index];
  }

  address = (address << (8 * (5 - numeric.length))) | numeric[numeric.length - 1];
  return [(address >>> 24) & 0xff, (address >>> 16) & 0xff, (address >>> 8) & 0xff, address & 0xff];
}

function parseLegacyIpv4Part(value: string): number | null {
  if (value.startsWith("0x")) {
    const hex = value.slice(2);
    return /^[0-9a-f]+$/.test(hex) ? Number.parseInt(hex, 16) : null;
  }

  if (value.length > 1 && value.startsWith("0")) {
    return /^[0-7]+$/.test(value) ? Number.parseInt(value, 8) : null;
  }

  return /^[0-9]+$/.test(value) ? Number.parseInt(value, 10) : null;
}

function isPrivateIpv4Bytes(bytes: readonly number[]): boolean {
  const [first, second] = bytes;
  return (
    first === 0 ||
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

  if (isExpandedIpv6AnyOrLoopback(hostname) || isUnsafeIpv6Prefix(hostname)) {
    return true;
  }

  const mappedIpv4Bytes = parseIpv4MappedOrCompatibleIpv6Bytes(hostname);
  return mappedIpv4Bytes ? isPrivateIpv4Bytes(mappedIpv4Bytes) : false;
}

function isUnsafeIpv6Prefix(hostname: string): boolean {
  const [firstGroup] = hostname.split(":");
  if (!/^[0-9a-f]{1,4}$/.test(firstGroup)) {
    return false;
  }

  const firstWord = Number.parseInt(firstGroup, 16);
  return (
    (firstWord >= 0xfc00 && firstWord <= 0xfdff) ||
    (firstWord >= 0xfe80 && firstWord <= 0xfeff) ||
    firstWord >= 0xff00
  );
}

function isExpandedIpv6AnyOrLoopback(hostname: string): boolean {
  const groups = hostname.split(":");
  return (
    groups.length === 8 &&
    groups.slice(0, 7).every(isZeroIpv6Group) &&
    (groups[7] === "0" || groups[7] === "1")
  );
}

function parseIpv4MappedOrCompatibleIpv6Bytes(hostname: string): readonly number[] | null {
  const mappedPrefix = "::ffff:";
  if (hostname.startsWith(mappedPrefix)) {
    return parseMappedIpv4Suffix(hostname.slice(mappedPrefix.length));
  }

  const compatiblePrefix = "::";
  if (hostname.startsWith(compatiblePrefix)) {
    return parseMappedIpv4Suffix(hostname.slice(compatiblePrefix.length));
  }

  const groups = hostname.split(":");
  if ((groups.length !== 7 && groups.length !== 8) || !groups.slice(0, 5).every(isZeroIpv6Group)) {
    return null;
  }

  if (groups[5] === "ffff") {
    return parseMappedIpv4Suffix(groups.slice(6).join(":"));
  }

  if (isZeroIpv6Group(groups[5])) {
    return parseMappedIpv4Suffix(groups.slice(6).join(":"));
  }

  return null;
}

function parseMappedIpv4Suffix(mapped: string): readonly number[] | null {
  if (mapped.includes(".")) {
    return parseDottedIpv4Bytes(mapped);
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

function parseDottedIpv4Bytes(mapped: string): readonly number[] | null {
  const parts = mapped.split(".");
  if (parts.length !== 4) {
    return null;
  }

  const bytes = parts.map((part) => (/^\d{1,3}$/.test(part) ? Number(part) : Number.NaN));
  return bytes.some((value) => !Number.isInteger(value) || value < 0 || value > 255) ? null : bytes;
}

function isZeroIpv6Group(group: string): boolean {
  return /^[0]{1,4}$/.test(group);
}
