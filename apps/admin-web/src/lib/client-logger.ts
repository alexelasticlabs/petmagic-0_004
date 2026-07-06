import {
  maskEmail,
  maskPhone,
  maskSignedUrl,
  sanitizeSensitiveText,
} from "@/lib/sensitive-display";

type ClientLogLevel = "error" | "warn";
type ClientLogContext = Record<string, unknown>;

const isProduction = process.env.NODE_ENV === "production";
const MAX_LOG_CONTEXT_DEPTH = 4;
const MAX_LOG_CONTEXT_KEYS = 32;
const MAX_LOG_ARRAY_ITEMS = 20;
const ABSOLUTE_LOG_URL_PATTERN = /\b(?:https?|blob|data):[^\s<>"')]+/gi;
const LOCAL_PATH_PATTERN =
  /\b(?:[A-Za-z]:\\|file:\/\/|\/(?:Users|home|tmp|var|private|data)\/)[^\s<>"')]+/g;

function normalizeContext(context?: ClientLogContext): ClientLogContext | undefined {
  if (!context) {
    return undefined;
  }

  const entries = Object.entries(context).map(([key, value]) => [
    key,
    maskSensitiveValue(key, value, new WeakSet(), 0),
  ]);
  return Object.fromEntries(entries);
}

function emit(level: ClientLogLevel, event: string, context?: ClientLogContext): void {
  const safeEvent = sanitizeLogEvent(event);
  const payload = {
    level,
    event: safeEvent,
    timestamp: new Date().toISOString(),
    context: normalizeContext(context),
  };

  if (level === "error") {
    console.error(`[client:${safeEvent}]`, payload);
    return;
  }

  if (level === "warn") {
    console.warn(`[client:${safeEvent}]`, payload);
    return;
  }
}

function maskSensitiveValue(
  key: string,
  value: unknown,
  seen: WeakSet<object>,
  depth: number
): unknown {
  if (value == null) {
    return value;
  }

  if (looksLikeTransportPayloadKey(key)) {
    return "[redacted-payload]";
  }

  if (value instanceof Error) {
    return maskSensitiveValue(
      key,
      {
        name: value.name,
        message: value.message,
        stack: isProduction ? undefined : value.stack,
      },
      seen,
      depth
    );
  }

  if (typeof value === "string") {
    return maskSensitiveString(key, value);
  }

  if (depth >= MAX_LOG_CONTEXT_DEPTH) {
    return "[truncated-depth]";
  }

  if (Array.isArray(value)) {
    if (seen.has(value)) {
      return "[circular]";
    }

    seen.add(value);
    const visibleItems = value
      .slice(0, MAX_LOG_ARRAY_ITEMS)
      .map((item) => maskSensitiveValue(key, item, seen, depth + 1));
    if (value.length > MAX_LOG_ARRAY_ITEMS) {
      visibleItems.push(`[truncated:${value.length - MAX_LOG_ARRAY_ITEMS}]`);
    }

    return visibleItems;
  }

  if (typeof value === "object") {
    if (seen.has(value)) {
      return "[circular]";
    }

    seen.add(value);
    const entries = Object.entries(value as Record<string, unknown>);
    const visibleEntries = entries.slice(0, MAX_LOG_CONTEXT_KEYS);
    const sanitized = Object.fromEntries(
      visibleEntries.map(([childKey, childValue]) => [
        childKey,
        maskSensitiveValue(childKey, childValue, seen, depth + 1),
      ])
    );

    if (entries.length > MAX_LOG_CONTEXT_KEYS) {
      sanitized.__truncated_keys = entries.length - MAX_LOG_CONTEXT_KEYS;
    }

    return sanitized;
  }

  return value;
}

function maskSensitiveString(key: string, value: string): string {
  const normalizedKey = key.toLowerCase();
  if (looksLikeStableIdentifierKey(normalizedKey)) {
    return "***";
  }

  if (looksLikeOpaqueMediaKey(normalizedKey)) {
    return maskOpaqueLocation(value);
  }

  if (looksLikeUserFileNameKey(normalizedKey)) {
    return "***";
  }

  if (
    normalizedKey.includes("authorization") ||
    normalizedKey.includes("token") ||
    normalizedKey.includes("jwt") ||
    normalizedKey.includes("session") ||
    normalizedKey.includes("cookie") ||
    normalizedKey.includes("credential") ||
    normalizedKey.includes("signature") ||
    normalizedKey.includes("secret") ||
    normalizedKey.includes("password") ||
    normalizedKey.includes("receipt") ||
    normalizedKey.includes("apiKey".toLowerCase()) ||
    looksLikePaymentProviderIdentifierKey(normalizedKey)
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
    /"(authorization|access_?token|refresh_?token|token|secret|password|api_?key|receipt|server_?verification_?data|local_?verification_?data|verification_?data|signed_?transaction_?info|signed_?payload|purchase_?token|customer_?id|external_?payment_?id|external_?subscription_?id|payment_?intent_?id|setup_?intent_?id|checkout_?session_?id|stripe_?session_?id)"\s*:/i.test(
      value
    ) ||
    /"(jwt|session|cookie|set-cookie|credential|signature)"\s*:/i.test(value) ||
    /\b(authorization|access_?token|refresh_?token|token|secret|password|api_?key|receipt|server_?verification_?data|local_?verification_?data|verification_?data|signed_?transaction_?info|signed_?payload|purchase_?token|customer_?id|external_?payment_?id|external_?subscription_?id|payment_?intent_?id|setup_?intent_?id|checkout_?session_?id|stripe_?session_?id)=/i.test(
      value
    ) ||
    /\b(jwt|session|cookie|set-cookie|credential|signature)=/i.test(value) ||
    /\b(x[-_]?api[-_]?key|api[-_]?key|x[-_]?fal[-_]?key|fal[-_]?key|stripe[-_]?signature|x[-_]?goog[-_]?signature|x[-_]?webhook[-_]?signature)\s*[:=]/i.test(
      value
    ) ||
    /\b(user_?ids?|profile_?user_?ids?|owner_?user_?ids?|subject_?ids?|account_?ids?|account_?scope|user_?scope|scope|pet_?ids?|pet_?photo_?ids?|generation_?ids?|template_?ids?|assignment_?ids?|conversation_?ids?|message_?ids?|ticket_?ids?|attachment_?ids?|purchase_?ids?|subscription_?ids?|order_?ids?|feedback_?ids?|report_?ids?|moderation_?ids?)\s*[:=]/i.test(
      value
    ) ||
    /\b[a-z0-9_-]*(?:user[_-]?ids?|account[_-]?ids?|pet[_-]?ids?|generation(?:[_-]?result)?[_-]?ids?|template[_-]?ids?|assignment[_-]?ids?|conversation[_-]?ids?|message[_-]?ids?|ticket[_-]?ids?|attachment[_-]?ids?|purchase[_-]?ids?|subscription[_-]?ids?|feedback[_-]?ids?|report[_-]?ids?|moderation[_-]?ids?|order[_-]?ids?)\s*[:=]/i.test(
      value
    ) ||
    /\b[a-z0-9_-]*file[_-]?names?\s*[:=]/i.test(value) ||
    /\b(signature|x-amz-signature|x-goog-signature|expires|x-amz-credential|x-goog-credential)=/i.test(
      value
    ) ||
    normalizedValue.includes("x-amz-signature=") ||
    normalizedValue.includes("x-goog-signature=")
  );
}

function looksLikeStableIdentifierKey(key: string): boolean {
  const normalized = key.replace(/[^a-z0-9]/g, "");
  return (
    looksLikeCompoundStableIdentifierKey(normalized) ||
    normalized === "userid" ||
    normalized === "profileuserid" ||
    normalized === "owneruserid" ||
    normalized === "subjectid" ||
    normalized === "accountid" ||
    normalized === "accountscope" ||
    normalized === "userscope" ||
    normalized === "scope" ||
    normalized === "petid" ||
    normalized === "petphotoid" ||
    normalized === "generationid" ||
    normalized === "templateid" ||
    normalized === "assignmentid" ||
    normalized === "conversationid" ||
    normalized === "messageid" ||
    normalized === "ticketid" ||
    normalized === "attachmentid" ||
    normalized === "purchaseid" ||
    normalized === "subscriptionid" ||
    normalized === "feedbackid" ||
    normalized === "reportid" ||
    normalized === "moderationid" ||
    normalized === "orderid"
  );
}

function looksLikePaymentProviderIdentifierKey(key: string): boolean {
  const normalized = key.replace(/[^a-z0-9]/g, "");
  return (
    normalized === "customerid" ||
    normalized === "externalpaymentid" ||
    normalized === "externalsubscriptionid" ||
    normalized === "paymentintentid" ||
    normalized === "setupintentid" ||
    normalized === "checkoutsessionid" ||
    normalized === "stripesessionid"
  );
}

function looksLikeCompoundStableIdentifierKey(key: string): boolean {
  if (key === "requestid" || key === "correlationid" || key === "traceid") {
    return false;
  }

  const stableIdDomains = [
    "userid",
    "accountid",
    "petid",
    "generationid",
    "generationresultid",
    "templateid",
    "assignmentid",
    "conversationid",
    "messageid",
    "ticketid",
    "attachmentid",
    "purchaseid",
    "subscriptionid",
    "feedbackid",
    "reportid",
    "moderationid",
    "orderid",
  ];

  return stableIdDomains.some(
    (domain) =>
      (key.endsWith(domain) && key.length > domain.length) ||
      key === `${domain}s` ||
      (key.endsWith(`${domain}s`) && key.length > domain.length + 1)
  );
}

function looksLikeUserFileNameKey(key: string): boolean {
  const normalized = key.replace(/[^a-z0-9]/g, "");
  return (
    normalized === "filename" ||
    normalized === "filenames" ||
    normalized.endsWith("filename") ||
    normalized.endsWith("filenames")
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

function sanitizeLogEvent(event: string): string {
  const trimmed = event.trim();
  if (!trimmed) {
    return "unknown";
  }

  if (
    containsSensitiveInlineValue(trimmed) ||
    /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i.test(trimmed) ||
    /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i.test(trimmed)
  ) {
    return "redacted";
  }

  return sanitizeLogText(trimmed, 128)
    .replace(/\s+/g, "_")
    .replace(/[^\w.:/-]+/g, "_");
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

function looksLikeTransportPayloadKey(key: string): boolean {
  const normalized = key.toLowerCase().replace(/[^a-z0-9]/g, "");
  return (
    normalized === "payload" ||
    normalized === "rawpayload" ||
    normalized === "apipayload" ||
    normalized === "providerpayload" ||
    normalized === "webhookpayload" ||
    normalized === "verificationdata" ||
    normalized === "serververificationdata" ||
    normalized === "localverificationdata" ||
    normalized === "signedtransactioninfo" ||
    normalized === "signedpayload" ||
    normalized === "purchasetoken" ||
    normalized === "body" ||
    normalized === "rawbody" ||
    normalized === "requestbody" ||
    normalized === "responsebody" ||
    normalized === "requestdata" ||
    normalized === "responsedata" ||
    normalized === "formdata" ||
    normalized === "headers" ||
    normalized === "requestheaders" ||
    normalized === "responseheaders"
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
