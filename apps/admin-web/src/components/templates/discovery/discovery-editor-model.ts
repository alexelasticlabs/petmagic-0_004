import type {
  DiscoveryDocument,
  DiscoveryLocale,
  DiscoverySection,
} from "@/lib/api-client.discovery";

export function moveDiscoveryItem<T>(items: readonly T[], from: number, to: number): T[] {
  if (from < 0 || to < 0 || from >= items.length || to >= items.length || from === to)
    return [...items];
  const next = [...items];
  const [item] = next.splice(from, 1);
  next.splice(to, 0, item);
  return next;
}

export function newDiscoverySection(categoryId: string, categoryName: string): DiscoverySection {
  return {
    id: crypto.randomUUID(),
    categoryId,
    isEnabled: true,
    showInCarousel: true,
    showAsRail: true,
    heroTemplateId: null,
    selectionMode: "Latest",
    itemLimit: 6,
    templateIds: [],
    copy: { en: { title: categoryName, subtitle: "" } },
  };
}

export function discoverySectionTitle(
  section: DiscoverySection,
  locale: DiscoveryLocale,
  categoryName?: string
): string {
  return section.copy[locale]?.title.trim() || section.copy.en?.title.trim() || categoryName || "—";
}

export function discoveryDiff(before: DiscoveryDocument | undefined, after: DiscoveryDocument) {
  const previous = new Map(before?.sections.map((section) => [section.id, section]) ?? []);
  const current = new Map(after.sections.map((section) => [section.id, section]));
  const added = after.sections.filter((section) => !previous.has(section.id)).length;
  const removed = before?.sections.filter((section) => !current.has(section.id)).length ?? 0;
  const changed = after.sections.filter(
    (section) =>
      previous.has(section.id) &&
      JSON.stringify(previous.get(section.id)) !== JSON.stringify(section)
  ).length;
  const reordered =
    (before?.sections
      .filter((section) => current.has(section.id))
      .map((section) => section.id)
      .join(",") ?? "") !==
    after.sections
      .filter((section) => previous.has(section.id))
      .map((section) => section.id)
      .join(",");
  const beforePage = before ? { ...before, sections: undefined } : {};
  const afterPage = { ...after, sections: undefined };
  return {
    added,
    removed,
    changed,
    reordered,
    pageChanged: JSON.stringify(beforePage) !== JSON.stringify(afterPage),
  };
}
