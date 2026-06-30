import {
  maskEmail,
  maskPhone,
  maskSignedUrl,
  sanitizeSensitiveText,
} from "@/lib/sensitive-display";

type ClientLogLevel = "error" | "warn";
type ClientLogContext = Record<string, unknown>;

const isProduction = process.env.NODE_ENV === "production";
const ABSOLUTE_LOG_URL_PATTERN = /\b(?:https?|blob|data):[^\s<>"')]+/gi;
const LOCAL_PATH_PATTERN =
  /\b(?:[A-Za-z]:\\|file:\/\/|\/(?:Users|home|tmp|var|private|data)\/)[^\s<>"')]+/g;

function normalizeContext(context?: ClientLogContext): ClientLogContext | undefined {
  if (!context) {
    return undefined;
  }

  const entries = Object.entries(context).map(([key, value]) => [
    key,
    maskSensitiveValue(key, value, new WeakSet()),
  ]);
  return Object.fromEntries(entries);
}

function emit(level: ClientLogLevel, event: string, context?: ClientLogContext): void {
  const payload = {
    level,
    event,
    timestamp: new Date().toISOString(),
    context: normalizeContext(context),
  };

  if (level === "error") {
    console.error(`[client:${event}]`, payload);
    return;
  }

  if (level === "warn") {
    console.warn(`[client:${event}]`, payload);
    return;
  }
}

function maskSensitiveValue(key: string, value: unknown, seen: WeakSet<object>): unknown {
  if (value == null) {
    return value;
  }

  if (value instanceof Error) {
    return maskSensitiveValue(
      key,
      {
        name: value.name,
        message: value.message,
        stack: isProduction ? undefined : value.stack,
      },
      seen
    );
  }

  if (typeof value === "string") {
    return maskSensitiveString(key, value);
  }

  if (Array.isArray(value)) {
    if (seen.has(value)) {
      return "[circular]";
    }

    seen.add(value);
    return value.map((item) => maskSensitiveValue(key, item, seen));
  }

  if (typeof value === "object") {
    if (seen.has(value)) {
      return "[circular]";
    }

    seen.add(value);
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([childKey, childValue]) => [
        childKey,
        maskSensitiveValue(childKey, childValue, seen),
      ])
    );
  }

  return value;
}

function maskSensitiveString(key: string, value: string): string {
  const normalizedKey = key.toLowerCase();
  if (looksLikeOpaqueMediaKey(normalizedKey)) {
    return maskOpaqueLocation(value);
  }

  if (
    normalizedKey.includes("authorization") ||
    normalizedKey.includes("token") ||
    normalizedKey.includes("secret") ||
    normalizedKey.includes("password") ||
    normalizedKey.includes("receipt") ||
    normalizedKey.includes("apiKey".toLowerCase())
  ) {
    return value.startsWith("Bearer ") ? "Bearer ***" : "***";
  }

  if (normalizedKey.includes("email")) {
    return maskEmail(value);
  }

  if (normalizedKey.includes("phone")) {
    return maskPhone(value);
  }

  if (looksLikePathKey(normalizedKey) && looksLikeFilesystemPath(value)) {
    return "[redacted-path]";
  }

  if (containsSensitiveInlineValue(value)) {
    return "[redacted]";
  }

  if (/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i.test(value)) {
    return maskEmail(value);
  }

  try {
    return maskOpaqueLocation(new URL(value).toString());
  } catch {
    // Not a URL.
  }

  return sanitizeLogText(value, 512);
}

function containsSensitiveInlineValue(value: string): boolean {
  const normalizedValue = value.toLowerCase();
  return (
    /\bbearer\s+[a-z0-9._~+/-]+=*/i.test(value) ||
    /"(authorization|access_?token|refresh_?token|token|secret|password|api_?key|receipt)"\s*:/i.test(
      value
    ) ||
    /\b(authorization|access_?token|refresh_?token|token|secret|password|api_?key|receipt)=/i.test(
      value
    ) ||
    /\b(signature|x-amz-signature|x-goog-signature|expires|x-amz-credential|x-goog-credential)=/i.test(
      value
    ) ||
    normalizedValue.includes("x-amz-signature=") ||
    normalizedValue.includes("x-goog-signature=")
  );
}

function sanitizeLogText(value: string, maxLength: number): string {
  return sanitizeSensitiveText(
    value
      .replace(ABSOLUTE_LOG_URL_PATTERN, (match) => maskOpaqueLocation(match))
      .replace(LOCAL_PATH_PATTERN, "[redacted-path]"),
    maxLength
  );
}

function looksLikeOpaqueMediaKey(key: string): boolean {
  return (
    key.includes("url") ||
    key.includes("uri") ||
    key.includes("href") ||
    key.includes("link") ||
    key.includes("attachment") ||
    key.includes("media") ||
    key.includes("preview") ||
    key.includes("reference") ||
    key.includes("avatar") ||
    key.includes("image") ||
    key.includes("video") ||
    key.includes("blob")
  );
}

function looksLikePathKey(key: string): boolean {
  return (
    key.includes("filepath") ||
    key.includes("localpath") ||
    key.includes("sourcepath") ||
    key.includes("pathname") ||
    key.includes("imagepath") ||
    key.includes("videopath") ||
    key.includes("avatarpath")
  );
}

function looksLikeFilesystemPath(value: string): boolean {
  return (
    /^[a-z]:\\/i.test(value) ||
    value.startsWith("/") ||
    value.startsWith("\\\\") ||
    value.startsWith("file://")
  );
}

function maskOpaqueLocation(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    return "***";
  }

  if (trimmed.startsWith("blob:")) {
    return "blob:***";
  }

  if (trimmed.startsWith("data:")) {
    return "data:***";
  }

  if (trimmed.startsWith("file://") || looksLikeFilesystemPath(trimmed)) {
    return "[redacted-path]";
  }

  try {
    const url = new URL(trimmed);
    if (url.protocol === "http:" || url.protocol === "https:") {
      return `${url.origin}/***`;
    }

    return `${url.protocol}***`;
  } catch {
    return maskSignedUrl(trimmed);
  }
}

export function sanitizeClientLogContextForTesting(
  context: ClientLogContext
): ClientLogContext | undefined {
  return normalizeContext(context);
}

export function sanitizeClientLogTextForTesting(key: string, value: string): string {
  return maskSensitiveString(key, value);
}

export const clientLogger = {
  error(event: string, context?: ClientLogContext): void {
    emit("error", event, context);
  },
  warn(event: string, context?: ClientLogContext): void {
    emit("warn", event, context);
  },
  info(): void {},
  debug(): void {},
};
