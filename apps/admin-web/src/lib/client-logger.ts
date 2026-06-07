import { maskEmail, maskPhone, maskSignedUrl, sanitizeSensitiveText } from "@/lib/sensitive-display";

type ClientLogLevel = "error" | "warn";
type ClientLogContext = Record<string, unknown>;

const isProduction = process.env.NODE_ENV === "production";

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

  if (containsSensitiveInlineValue(value)) {
    return "[redacted]";
  }

  if (/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i.test(value)) {
    return maskEmail(value);
  }

  try {
    const url = new URL(value);
    return url.search || url.username || url.password ? maskSignedUrl(value) : url.toString();
  } catch {
    // Not a URL.
  }

  return sanitizeSensitiveText(value, 512);
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
