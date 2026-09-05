import { getAdminErrorMessage } from "@/lib/admin-error-message";
import type { Dictionary } from "@/lib/i18n";

// Only known API codes become actionable copy. Raw provider details stay behind
// the shared admin error sanitizer, including during automatic media uploads.
export function getTemplateEditorErrorMessage(
  error: unknown,
  text: Dictionary,
  fallback: string
): string {
  if (error && typeof error === "object") {
    const candidate = error as { code?: unknown; validationErrors?: unknown };
    const codes = [
      candidate.code,
      ...(Array.isArray(candidate.validationErrors) ? candidate.validationErrors : []),
    ];
    for (const code of codes) {
      switch (code) {
        case "templates.preview_duration_required":
        case "templates.preview_duration_invalid":
          return text.editorPreviewDurationError;
        case "templates.media_metadata_invalid":
        case "templates.preview_optimization_invalid":
          return text.editorMediaReadError;
        case "templates.media_metadata_timed_out":
        case "templates.preview_optimization_timed_out":
        case "templates.media_metadata_failed":
        case "templates.preview_optimization_failed":
        case "templates.media_storage_failed":
          return text.editorMediaRetryError;
      }
    }
  }
  return getAdminErrorMessage(error, fallback);
}
