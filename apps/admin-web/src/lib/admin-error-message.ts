import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type AdminDisplayError = {
  status?: number;
  message?: string;
  validationErrors?: string[];
};

export function getAdminErrorMessage(error: unknown, fallback: string): string {
  if (!error || typeof error !== "object") {
    return fallback;
  }

  const candidate = error as AdminDisplayError;
  const statusMessage = getStatusMessage(candidate.status);
  if (Array.isArray(candidate.validationErrors) && candidate.validationErrors.length > 0) {
    const validationMessage = candidate.validationErrors
      .map(normalizeErrorText)
      .filter((value) => value && !isTechnicalMessage(value))
      .map((value) => sanitizeDisplayErrorText(value))
      .join(" ");

    if (validationMessage) {
      return validationMessage;
    }

    return statusMessage ?? fallback;
  }

  const rawMessage = typeof candidate.message === "string" ? normalizeErrorText(candidate.message) : "";
  if (rawMessage && !isTechnicalMessage(rawMessage)) {
    const message = sanitizeDisplayErrorText(rawMessage);
    return message;
  }

  return statusMessage ?? fallback;
}

function getStatusMessage(status: number | undefined): string | null {
  if (status === 400) {
    return "Request data is invalid.";
  }

  if (status === 401) {
    return "Session expired. Sign in again.";
  }

  if (status === 403) {
    return "You do not have permission to perform this action.";
  }

  if (status === 404) {
    return "Requested resource was not found.";
  }

  if (status === 409) {
    return "This action conflicts with the current server state.";
  }

  if (status === 422) {
    return "Request validation failed.";
  }

  if (typeof status === "number" && status >= 500) {
    return "Server error. Try again later.";
  }

  return null;
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
    /^TypeError:/i.test(trimmed) ||
    /^[a-z0-9_.-]+$/i.test(trimmed) ||
    trimmed.startsWith("{") ||
    trimmed.startsWith("[")
  );
}
