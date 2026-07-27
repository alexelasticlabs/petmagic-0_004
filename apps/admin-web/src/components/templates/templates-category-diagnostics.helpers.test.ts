import { describe, expect, it } from "vitest";

import {
  buildTemplateCategoryEditorPath,
  filterTemplateCategoryDiagnosticItems,
} from "@/components/templates/templates-category-diagnostics.helpers";
import type { AdminTemplateCategoryDiagnosticItem } from "@/lib/api-client.types.template-category-diagnostics";

const items: AdminTemplateCategoryDiagnosticItem[] = [
  {
    templateId: "image/id?unsafe",
    issueKind: "missing_category",
    title: "Magic portrait",
    category: "Legacy pets",
    normalizedCategory: "LEGACY PETS",
    templateType: "Image",
    status: "Active",
    updatedAtUtc: "2026-07-27T00:00:00.000Z",
  },
  {
    templateId: "video-id",
    issueKind: "archived_category",
    title: "Dance loop",
    category: "Seasonal",
    normalizedCategory: "SEASONAL",
    templateType: "Video",
    status: "Active",
    updatedAtUtc: "2026-07-27T00:00:00.000Z",
  },
];

describe("template category diagnostics helpers", () => {
  it("builds allowlisted editor routes with an encoded template ID", () => {
    expect(buildTemplateCategoryEditorPath("ru", items[0])).toBe(
      "/ru/templates/image/editor?templateId=image%2Fid%3Funsafe"
    );
    expect(buildTemplateCategoryEditorPath("en", items[1])).toBe(
      "/en/templates/video/editor?templateId=video-id"
    );
  });

  it("filters locally without putting diagnostic text into a URL", () => {
    expect(filterTemplateCategoryDiagnosticItems(items, "missing_category", " portrait ")).toEqual([
      items[0],
    ]);
    expect(filterTemplateCategoryDiagnosticItems(items, "archived_category", "seasonal")).toEqual([
      items[1],
    ]);
    expect(filterTemplateCategoryDiagnosticItems(items, "empty_category", "")).toEqual([]);
  });
});
