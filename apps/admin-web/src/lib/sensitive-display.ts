const EMPTY_DISPLAY = "—";
const EMAIL_PATTERN = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi;
const URL_PATTERN = /\bhttps?:\/\/[^\s<>"')]+/gi;
const PHONE_PATTERN = /(^|[^\w])(\+?\d[\d\s().-]{6,}\d)(?=$|[^\w])/g;
const SECRET_ASSIGNMENT_PATTERN =
  /\b(authorization|access_?token|refresh_?token|token|jwt|session|cookie|set-cookie|secret|password|api_?key|credential|signature|stripe_signature|receipt)\s*[:=]\s*["']?[^"',\s}&]+/gi;
const CARD_ASSIGNMENT_PATTERN = /\b(card(?:_?number)?|pan|cvv|cvc)\s*[:=]\s*["']?[\d\s-]{3,19}/gi;
const BEARER_TOKEN_PATTERN = /\bBearer\s+[A-Za-z0-9._~+/=-]+/gi;
const JWT_PATTERN = /\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g;
const STRIPE_SECRET_PATTERN = /\b(?:sk|pk|rk)_(?:live|test)_[A-Za-z0-9]+\b/g;

export function maskEmail(value: string | null | undefined): string {
  const trimmed = value?.trim();
  if (!trimmed) {
    return EMPTY_DISPLAY;
  }

  const atIndex = trimmed.indexOf("@");
  if (atIndex <= 0 || atIndex === trimmed.length - 1) {
    return maskMiddle(trimmed);
  }

  const local = trimmed.slice(0, atIndex);
  const domain = trimmed.slice(atIndex + 1);
  const [domainHead = "", ...domainRest] = domain.split(".");
  const visibleLocal =
    local.length <= 1 ? (local[0] ?? "*") : local.slice(0, Math.min(2, local.length));
  const visibleDomain = domainHead.length <= 1 ? (domainHead[0] ?? "*") : domainHead[0];
  const suffix = domainRest.length ? `.${domainRest.join(".")}` : "";

  return `${visibleLocal}***@${visibleDomain}***${suffix}`;
}

export function maskPhone(value: string | null | undefined): string {
  const trimmed = value?.trim();
  if (!trimmed) {
    return EMPTY_DISPLAY;
  }

  const digits = trimmed.replace(/\D/g, "");
  if (digits.length < 6) {
    return maskMiddle(trimmed);
  }

  return `${digits.slice(0, 2)}***${digits.slice(-2)}`;
}

export function maskSignedUrl(value: string | null | undefined): string {
  const trimmed = value?.trim();
  if (!trimmed) {
    return EMPTY_DISPLAY;
  }

  if (trimmed.startsWith("blob:")) {
    return "blob:***";
  }

  if (trimmed.startsWith("data:")) {
    return "data:***";
  }

  if (trimmed.startsWith("file://")) {
    return "[redacted-path]";
  }

  try {
    const url = new URL(trimmed);
    if (url.protocol === "http:" || url.protocol === "https:") {
      return `${url.origin}/***`;
    }

    return `${url.protocol}***`;
  } catch {
    return trimmed.length > 80 ? `${trimmed.slice(0, 80)}...` : trimmed;
  }
}

export function sanitizeSensitiveText(value: string | null | undefined, maxLength = 512): string {
  const normalized = value
    ?.replace(/\s+/g, " ")
    .trim()
    .replace(EMAIL_PATTERN, (match) => maskEmail(match))
    .replace(URL_PATTERN, (match) => maskSignedUrl(match))
    .replace(SECRET_ASSIGNMENT_PATTERN, (_match, key: string) => `${key}=[redacted]`)
    .replace(CARD_ASSIGNMENT_PATTERN, (_match, key: string) => `${key}=[redacted]`)
    .replace(
      PHONE_PATTERN,
      (_match, prefix: string, phone: string) => `${prefix}${maskPhone(phone)}`
    )
    .replace(BEARER_TOKEN_PATTERN, "Bearer [redacted]")
    .replace(JWT_PATTERN, "[redacted-token]")
    .replace(STRIPE_SECRET_PATTERN, "[redacted-secret]");

  if (!normalized) {
    return EMPTY_DISPLAY;
  }

  if (normalized.length <= maxLength) {
    return normalized;
  }

  return `${normalized.slice(0, Math.max(0, maxLength - 3)).trimEnd()}...`;
}

export function getAdminUserDisplayName(user: {
  displayName?: string | null;
  email?: string | null;
  userId: string;
}): string {
  const email = user.email?.trim();
  return user.displayName?.trim() || (email ? maskEmail(email) : shortIdentifier(user.userId));
}

export function shortIdentifier(value: string, visibleLength = 8): string {
  return value.trim().slice(0, visibleLength) || EMPTY_DISPLAY;
}

function maskMiddle(value: string): string {
  if (value.length <= 2) {
    return `${value[0] ?? "*"}***`;
  }

  return `${value.slice(0, 2)}***${value.slice(-1)}`;
}
