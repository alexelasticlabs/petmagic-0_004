import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type AdminDisplayError = {
  code?: string;
  status?: number;
  message?: string;
  detail?: string;
  validationErrors?: string[];
  retryAfterSeconds?: number;
};

export function getAdminErrorMessage(error: unknown, fallback: string): string {
  if (!error || typeof error !== "object") {
    return fallback;
  }

  const candidate = error as AdminDisplayError;
  if (candidate.code === "auth.retry_required_after_refresh") {
    return fallback;
  }

  if (Array.isArray(candidate.validationErrors) && candidate.validationErrors.length > 0) {
    const validationMessage = candidate.validationErrors
      .map(normalizeErrorText)
      .filter((value) => value && !isTechnicalMessage(value))
      .map((value) => sanitizeDisplayErrorText(value))
      .join(" ");

    if (validationMessage) {
      return validationMessage;
    }

    return fallback;
  }

  const rawDetail =
    typeof candidate.detail === "string" ? normalizeErrorText(candidate.detail) : "";
  if (rawDetail && !isTechnicalMessage(rawDetail) && !isGenericApiProblemDetail(rawDetail)) {
    return sanitizeDisplayErrorText(rawDetail);
  }

  const rawMessage =
    typeof candidate.message === "string" ? normalizeErrorText(candidate.message) : "";
  if (rawMessage && !isTechnicalMessage(rawMessage) && !isGenericApiProblemDetail(rawMessage)) {
    const message = sanitizeDisplayErrorText(rawMessage);
    return message;
  }

  return fallback;
}

export function getAdminRetryAfterSeconds(error: unknown): number | null {
  if (!error || typeof error !== "object") {
    return null;
  }

  const candidate = error as AdminDisplayError;
  const value = candidate.retryAfterSeconds;
  return typeof value === "number" && Number.isInteger(value) && value > 0 && value <= 3_600
    ? value
    : null;
}

function normalizeErrorText(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function sanitizeDisplayErrorText(value: string): string {
  return sanitizeSensitiveText(normalizeErrorText(value), 240);
}

function isTechnicalMessage(value: string): boolean {
  const trimmed = value.trim();
  return (
    /^API request failed with status \d+$/i.test(trimmed) ||
    /^(Request data is invalid|Session expired\. Sign in again|You do not have permission to perform this action|Requested resource was not found|This action conflicts with the current server state|Request validation failed|Too many requests\. Try again shortly|Server error\. Try again later|Request failed\. Try again)\.$/i.test(
      trimmed
    ) ||
    /^TypeError:/i.test(trimmed) ||
    /^[a-z0-9_.-]+$/i.test(trimmed) ||
    trimmed.startsWith("{") ||
    trimmed.startsWith("[")
  );
}

function isGenericApiProblemDetail(value: string): boolean {
  const normalized = normalizeErrorText(value);
  return (
    /^(Authentication failed|External authentication request is invalid|External authentication failed|Request failed\. Try again)\.$/i.test(
      normalized
    ) ||
    /^(?:[\w\s'-]+)\b(?:is|are|was|were)\b.*\b(?:invalid|not found|unavailable|forbidden|not allowed|temporarily unavailable|already linked|not linked|expired)\.$/i.test(
      normalized
    ) ||
    /^(?:At least one|Current)\b.*\b(?:must remain|must be accepted)\.$/i.test(normalized) ||
    /^(?:Identity|Template|Generation|Billing|Payment|Premium|Support|Feedback|Pet|Gamification|Account|Session|Email|Avatar|Media|Webhook|Catalog|Resource|Operation|Action|Request)\b.*\b(?:failed|invalid|unavailable|forbidden|not found|not allowed|temporarily unavailable|could not be completed|does not allow this action)\.$/i.test(
      normalized
    ) ||
    /\bReload and try again\.$/i.test(normalized) ||
    /^(?:Requested|Selected|Associated|Current)\b.*\b(?:not found|unavailable|invalid|could not be completed)\.$/i.test(
      normalized
    ) ||
    /^(?:Too many|Not enough)\b.*\b(?:try again later|complete this action)\.$/i.test(normalized)
  );
}
