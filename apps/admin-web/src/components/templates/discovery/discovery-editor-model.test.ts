import { describe, expect, it } from "vitest";

import { getAdminNavItems } from "@/lib/admin-navigation";
import { canAccessAdminPath } from "@/lib/admin-rbac";
import type { DiscoveryDocument, DiscoverySection } from "@/lib/api-client.discovery";

import { discoveryDiff, discoverySectionTitle, moveDiscoveryItem } from "./discovery-editor-model";

const a: DiscoverySection = {
  id: "a",
  categoryId: "cat-a",
  isEnabled: true,
  showAsRail: true,
  showInCarousel: true,
  heroTemplateId: null,
  selectionMode: "Latest",
  itemLimit: 6,
  templateIds: [],
  copy: { en: { title: "Funny", subtitle: "" }, ru: { title: "", subtitle: "" } },
};
const b = { ...a, id: "b", categoryId: "cat-b" };
const doc: DiscoveryDocument = {
  schemaVersion: 1,
  copy: { en: { title: "Discovery", subtitle: "" } },
  sections: [a, b],
  carouselEnabled: true,
  searchEnabled: true,
  autoplayEnabled: true,
  autoplayIntervalMs: 7000,
};
describe("discovery editor", () => {
  it("reorders without mutating the input or accepting out-of-bounds moves", () => {
    expect(moveDiscoveryItem(doc.sections, 0, 1)).toEqual([b, a]);
    expect(doc.sections).toEqual([a, b]);
    expect(moveDiscoveryItem(doc.sections, -1, 0)).toEqual([a, b]);
  });
  it("distinguishes editorial changes from ordering in the publish diff", () => {
    expect(
      discoveryDiff(doc, { ...doc, sections: [b, { ...a, heroTemplateId: "cover" }] })
    ).toEqual({ added: 0, removed: 0, changed: 1, reordered: true, pageChanged: false });
    expect(discoveryDiff(doc, { ...doc, autoplayIntervalMs: 10000, sections: [a] })).toMatchObject({
      removed: 1,
      pageChanged: true,
      reordered: false,
    });
  });
  it("falls back to English without replacing the category identity", () => {
    expect(discoverySectionTitle(a, "ru", "Category")).toBe("Funny");
    expect(discoverySectionTitle({ ...a, copy: {} }, "ru", "Category")).toBe("Category");
    expect(a.categoryId).toBe("cat-a");
  });
  it("exposes discovery read access to both admin roles and blocks anonymous users", () => {
    expect(canAccessAdminPath(["Moderator"], "/templates/discovery")).toBe(true);
    expect(canAccessAdminPath([], "/templates/discovery")).toBe(false);
    const templates = getAdminNavItems("ru", ["Admin"]).find((item) => item.key === "templates");
    expect(templates?.type === "group" && templates.items[0].key).toBe("template-discovery");
  });
});
