import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { isUnsafeTemplateMediaUrl } from "@/components/templates/template-secure-media";
import { readTemplateTestPageLibrarySource } from "@/components/templates/template-test-page.test-source";
import { readTemplatesAnalyticsHubPageLibrarySource } from "@/components/templates/templates-analytics-hub-page.test-source";
import { readTemplatesCatalogViewLibrarySource } from "@/components/templates/templates-catalog-view.test-source";

const phonePreviewPath = fileURLToPath(
  new URL("./template-phone-preview-card.tsx", import.meta.url)
);
const analyticsOverviewPath = fileURLToPath(
  new URL("./template-analytics-overview-sections.tsx", import.meta.url)
);
const analyticsDetailSectionsPath = fileURLToPath(
  new URL("./template-analytics-detail-sections.tsx", import.meta.url)
);
const previewAssetSectionPath = fileURLToPath(
  new URL("./template-preview-asset-section.tsx", import.meta.url)
);
const editorSectionsPath = fileURLToPath(
  new URL("./template-editor-sections.tsx", import.meta.url)
);
const secureMediaPath = fileURLToPath(new URL("./template-secure-media.tsx", import.meta.url));

describe("template preview media URL exposure", () => {
  it("keeps template media inside the guarded renderer and falls back for configured public assets", () => {
    const sources = [
      readTemplatesCatalogViewLibrarySource(),
      readFileSync(phonePreviewPath, "utf8"),
      readFileSync(analyticsOverviewPath, "utf8"),
      readFileSync(analyticsDetailSectionsPath, "utf8"),
      readTemplatesAnalyticsHubPageLibrarySource(),
      readFileSync(previewAssetSectionPath, "utf8"),
      readFileSync(editorSectionsPath, "utf8"),
      readTemplateTestPageLibrarySource(),
    ].join("\n");
    const secureMediaSource = readFileSync(secureMediaPath, "utf8");

    expect(sources).not.toContain("src={template.previewAsset.url}");
    expect(sources).not.toContain("src={previewUrl}");
    expect(sources).not.toContain("src={trimmedUrl}");
    expect(sources).not.toContain("src={effectivePreviewUrl}");
    expect(sources).not.toContain("src={effectiveReferenceUrl}");
    expect(sources).not.toContain("href={item.outputUrl}");
    expect(sources).not.toContain("{item.outputUrl}");
    expect(sources).not.toContain("value={form.previewUrl}");
    expect(sources).not.toContain("value={form.referenceUrl}");
    expect(sources).toContain("<TemplateSecureMedia");
    expect(secureMediaSource).toContain("URL.createObjectURL(blob)");
    expect(secureMediaSource).toContain("const activeObjectUrlRef = useRef<string | null>(null);");
    expect(secureMediaSource).toContain("const revokeActiveObjectUrl = useCallback(");
    expect(secureMediaSource).toContain("const markRemoteMediaFailed = useCallback(");
    expect(secureMediaSource).toContain(
      "revokeActiveObjectUrl();\n        activeObjectUrlRef.current = createdObjectUrl;"
    );
    expect(secureMediaSource).toContain(
      "if (createdObjectUrl && activeObjectUrlRef.current === createdObjectUrl)"
    );
    expect(secureMediaSource).toContain("onError={markRemoteMediaFailed}");
    expect(secureMediaSource).toContain("fetchWithTimeout(url");
    expect(secureMediaSource).toContain('credentials: "omit"');
    expect(secureMediaSource).not.toContain('credentials: "include"');
    expect(secureMediaSource).toContain("templates.secure_media_fetch_failed");
    expect(secureMediaSource).toContain("templates.secure_media_unsafe_host_blocked");
    expect(secureMediaSource).toContain("export function isUnsafeTemplateMediaUrl(");
    expect(secureMediaSource).toContain("function getBlockedUnsafeTemplateMediaUrlDetails(");
    expect(secureMediaSource).toContain("function getMediaFetchErrorName(error: unknown)");
    expect(secureMediaSource).toContain("function formatTemplateMediaLogText(");
    expect(secureMediaSource).toContain("rawLength: url.length");
    expect(secureMediaSource).toContain('startsWithSlash: url.startsWith("/")');
    expect(secureMediaSource).toContain("isBlobOrData: isLocalObjectUrl(url)");
    expect(secureMediaSource).toContain(
      "templateId: formatTemplateMediaLogText(logContext?.templateId)"
    );
    expect(secureMediaSource).toContain(
      "contentType: formatTemplateMediaLogText(logContext?.contentType)"
    );
    expect(secureMediaSource).toContain(
      "surface: formatTemplateMediaLogText(logContext?.surface, 48)"
    );
    expect(secureMediaSource).toContain("errorName: getMediaFetchErrorName(error)");
    expect(secureMediaSource).not.toContain("templateId: logContext?.templateId");
    expect(secureMediaSource).not.toContain("contentType: logContext?.contentType");
    expect(secureMediaSource).not.toContain("surface: logContext?.surface");
    expect(secureMediaSource).not.toContain("error,\n        });");
    expect(secureMediaSource).not.toContain(
      'clientLogger.warn("templates.secure_media_origin_check_failed", { url'
    );
    expect(secureMediaSource).not.toContain(
      'clientLogger.warn("templates.secure_media_unsafe_host_blocked", { url'
    );
    expect(secureMediaSource).toContain("const fallBackToDirectRemoteUrl = useCallback(");
    expect(secureMediaSource).toContain("useDirectUrl: true");
    expect(secureMediaSource).toContain('referrerPolicy="no-referrer"');
    expect(secureMediaSource).toContain(
      "storage origin does not expose CORS headers to JavaScript"
    );
  });

  it("blocks unsafe template media URLs before direct rendering or fetching", () => {
    expect(isUnsafeTemplateMediaUrl("https://localhost/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://api.localhost/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://host.docker.internal/templates/preview.jpg")).toBe(
      true
    );
    expect(isUnsafeTemplateMediaUrl("https://backend:5000/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://0.0.0.0/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://192.168.1.5/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://10.0.0.5/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://169.254.169.254/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://[::1]/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://[::]/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://[fd00::1]/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://cdn.example.com/templates/preview.jpg")).toBe(true);
    expect(isUnsafeTemplateMediaUrl("https://cdn.petmagic.ai/templates/preview.jpg")).toBe(false);
  });

  it("sanitizes visible template media file names before rendering them", () => {
    const previewAssetSource = readFileSync(previewAssetSectionPath, "utf8");
    const editorSectionsSource = readFileSync(editorSectionsPath, "utf8");
    const templateTestSource = readTemplateTestPageLibrarySource();

    expect(previewAssetSource).toContain("sanitizeSensitiveText(");
    expect(editorSectionsSource).toContain("sanitizeSensitiveText(");
    expect(templateTestSource).toContain("const safeFileName = sanitizeSensitiveText(fileName");
    expect(templateTestSource).not.toContain("alt={fileName}");
    expect(templateTestSource).not.toContain("{imageUrl ? fileName");
  });

  it("creates local template preview blob URLs only from file selection handlers", () => {
    const previewAssetSource = readFileSync(previewAssetSectionPath, "utf8");
    const editorSectionsSource = readFileSync(editorSectionsPath, "utf8");

    expect(previewAssetSource).toContain(
      "const localPreviewUrl = localPreview?.file === previewFile ? localPreview.url : null;"
    );
    expect(previewAssetSource).toContain("const objectUrl = URL.createObjectURL(file);");
    expect(previewAssetSource).toContain("setLocalPreview({ file, url: objectUrl });");
    expect(previewAssetSource).toContain(
      "} catch (error) {\n      URL.revokeObjectURL(objectUrl);"
    );
    expect(previewAssetSource).toContain("URL.revokeObjectURL(localPreview.url);");
    expect(previewAssetSource).not.toContain(
      "() => (previewFile ? URL.createObjectURL(previewFile) : null)"
    );

    expect(editorSectionsSource).toContain(
      "const localReferenceUrl = localReference?.file === referenceFile ? localReference.url : null;"
    );
    expect(editorSectionsSource).toContain("const objectUrl = URL.createObjectURL(file);");
    expect(editorSectionsSource).toContain("setLocalReference({ file, url: objectUrl });");
    expect(editorSectionsSource).toContain(
      "} catch (error) {\n      URL.revokeObjectURL(objectUrl);"
    );
    expect(editorSectionsSource).toContain("URL.revokeObjectURL(localReference.url);");
    expect(editorSectionsSource).not.toContain(
      "() => (referenceFile ? URL.createObjectURL(referenceFile) : null)"
    );
  });
});
