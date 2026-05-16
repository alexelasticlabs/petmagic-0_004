export type TemplateMediaKind = "video" | "image";

export function inferTemplateMediaKind(contentType: string, url: string): TemplateMediaKind {
  const normalizedContentType = contentType.toLowerCase();
  const normalizedUrl = url.toLowerCase();

  if (normalizedContentType.startsWith("video/") || normalizedUrl.endsWith(".mp4") || normalizedUrl.endsWith(".webm") || normalizedUrl.endsWith(".mov")) {
    return "video";
  }

  return "image";
}

export function formatTemplateFileSize(raw: string): string {
  const value = Number.parseInt(raw, 10);
  if (Number.isNaN(value) || value <= 0) {
    return "--";
  }

  if (value < 1024) {
    return `${value} B`;
  }

  if (value < 1024 * 1024) {
    return `${(value / 1024).toFixed(1)} KB`;
  }

  return `${(value / (1024 * 1024)).toFixed(1)} MB`;
}
