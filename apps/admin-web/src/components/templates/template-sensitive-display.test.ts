import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readTemplatesCatalogViewLibrarySource } from "./templates-catalog-view.test-source";

const phonePreviewPath = fileURLToPath(
  new URL("./template-phone-preview-card.tsx", import.meta.url)
);
const overviewPath = fileURLToPath(
  new URL("./template-analytics-overview-sections.tsx", import.meta.url)
);
const analyticsPagePath = fileURLToPath(new URL("./template-analytics-page.tsx", import.meta.url));

describe("template sensitive display", () => {
  it("sanitizes template metadata before rendering phone preview copy", () => {
    const source = readFileSync(phonePreviewPath, "utf8");

    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("const normalizedTitle = sanitizeSensitiveText(title, 96)");
    expect(source).toContain(
      "const normalizedDescription = sanitizeSensitiveText(shortDescription, 180)"
    );
    expect(source).toContain("const normalizedCategory = sanitizeSensitiveText(category, 64)");
    expect(source).toContain(".map((tag) => sanitizeSensitiveText(tag, 40))");
    expect(source).not.toContain("const normalizedTitle = title.trim()");
    expect(source).not.toContain("const normalizedDescription = shortDescription.trim()");
    expect(source).not.toContain("const normalizedCategory = category.trim()");
  });

  it("sanitizes template analytics overview metadata before display", () => {
    const source = readFileSync(overviewPath, "utf8");

    expect(source).toContain("const safeTemplateTitle = sanitizeSensitiveText(template.title, 96)");
    expect(source).toContain(
      "const safeTemplateDescription = sanitizeSensitiveText(template.shortDescription, 180)"
    );
    expect(source).toContain(
      "const safeTemplateCategory = sanitizeSensitiveText(template.category, 64)"
    );
    expect(source).toContain("<h2>{safeTemplateTitle}</h2>");
    expect(source).toContain("<p>{safeTemplateDescription}</p>");
    expect(source).not.toContain("<h2>{template.title}</h2>");
    expect(source).not.toContain("<p>{template.shortDescription}</p>");
    expect(source).not.toContain("value={template.category}");
  });

  it("sanitizes template analytics page breadcrumb metadata before display", () => {
    const source = readFileSync(analyticsPagePath, "utf8");

    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("const templateTitle = sanitizeSensitiveText(template.title, 120)");
    expect(source).toContain("<Link href={editorPath}>{templateTitle}</Link>");
    expect(source).not.toContain("<Link href={editorPath}>{template.title}</Link>");
  });

  it("sanitizes template catalog list metadata and title attributes", () => {
    const source = readTemplatesCatalogViewLibrarySource();

    expect(source).toContain("const safeTemplateTitle = sanitizeSensitiveText(template.title, 96)");
    expect(source).toContain(
      "const safeTemplateDescription = sanitizeSensitiveText(template.shortDescription, 180)"
    );
    expect(source).toContain(
      "const safeTemplateCategory = sanitizeSensitiveText(template.category, 64)"
    );
    expect(source).toContain("title={safeTemplateDescription}");
    expect(source).toContain("<strong>{safeTemplateTitle}</strong>");
    expect(source).toContain("<span>{safeTemplateDescription}</span>");
    expect(source).not.toContain("title={template.shortDescription}");
    expect(source).not.toContain("<strong>{template.title}</strong>");
    expect(source).not.toContain("<span>{template.shortDescription}</span>");
    expect(source).not.toContain("<td data-label={text.categoryLabel}>{template.category}</td>");
  });
});
