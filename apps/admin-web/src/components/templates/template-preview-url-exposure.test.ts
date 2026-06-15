import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const catalogPath = fileURLToPath(new URL("./templates-catalog-view.tsx", import.meta.url));
const phonePreviewPath = fileURLToPath(
  new URL("./template-phone-preview-card.tsx", import.meta.url)
);
const analyticsOverviewPath = fileURLToPath(
  new URL("./template-analytics-overview-sections.tsx", import.meta.url)
);
const analyticsDetailSectionsPath = fileURLToPath(
  new URL("./template-analytics-detail-sections.tsx", import.meta.url)
);
const analyticsHubPath = fileURLToPath(
  new URL("./templates-analytics-hub-page.tsx", import.meta.url)
);
const previewAssetSectionPath = fileURLToPath(
  new URL("./template-preview-asset-section.tsx", import.meta.url)
);
const editorSectionsPath = fileURLToPath(
  new URL("./template-editor-sections.tsx", import.meta.url)
);
const templateTestPath = fileURLToPath(new URL("./template-test-page.tsx", import.meta.url));
const secureMediaPath = fileURLToPath(new URL("./template-secure-media.tsx", import.meta.url));

describe("template preview media URL exposure", () => {
  it("does not render backend template media URLs directly in image or video src attributes", () => {
    const sources = [
      readFileSync(catalogPath, "utf8"),
      readFileSync(phonePreviewPath, "utf8"),
      readFileSync(analyticsOverviewPath, "utf8"),
      readFileSync(analyticsDetailSectionsPath, "utf8"),
      readFileSync(analyticsHubPath, "utf8"),
      readFileSync(previewAssetSectionPath, "utf8"),
      readFileSync(editorSectionsPath, "utf8"),
      readFileSync(templateTestPath, "utf8"),
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
    expect(secureMediaSource).toContain("function shouldUseDirectMediaUrl(url: string)");
    expect(secureMediaSource).toContain("candidate.origin !== globalThis.location.origin");
    expect(secureMediaSource).toContain("fetchWithTimeout(url");
    expect(secureMediaSource).toContain("templates.secure_media_fetch_failed");
    expect(secureMediaSource).toContain("function getMediaFetchErrorName(error: unknown)");
    expect(secureMediaSource).toContain("errorName: getMediaFetchErrorName(error)");
    expect(secureMediaSource).not.toContain("error,\n        });");
  });

  it("sanitizes visible template media file names before rendering them", () => {
    const previewAssetSource = readFileSync(previewAssetSectionPath, "utf8");
    const editorSectionsSource = readFileSync(editorSectionsPath, "utf8");
    const templateTestSource = readFileSync(templateTestPath, "utf8");

    expect(previewAssetSource).toContain("sanitizeSensitiveText(");
    expect(editorSectionsSource).toContain("sanitizeSensitiveText(");
    expect(templateTestSource).toContain("const safeFileName = sanitizeSensitiveText(fileName");
    expect(templateTestSource).not.toContain("alt={fileName}");
    expect(templateTestSource).not.toContain("{imageUrl ? fileName");
  });
});
