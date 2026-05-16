export type TemplateMediaKind = "video" | "image";

export function inferTemplateMediaKind(contentType: string, url: string): TemplateMediaKind {
  const normalizedContentType = contentType.toLowerCase();
  const normalizedUrl = url.toLowerCase();

  if (normalizedContentType.startsWith("video/") || normalizedUrl.endsWith(".mp4") || normalizedUrl.endsWith(".webm") || normalizedUrl.endsWith(".mov")) {
    return "video";
  }

  return "image";
}
