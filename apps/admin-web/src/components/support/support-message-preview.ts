import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export const SUPPORT_MESSAGE_PREVIEW_MAX_LENGTH = 96;

export function formatSupportMessagePreview(
  value: string | null | undefined,
  fallback: string,
  maxLength = SUPPORT_MESSAGE_PREVIEW_MAX_LENGTH
): string {
  const trimmed = value?.trim();
  if (!trimmed) {
    return fallback;
  }

  return sanitizeSensitiveText(trimmed, maxLength);
}
