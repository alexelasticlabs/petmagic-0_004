import { getAdminNavItems, type AdminNavEntry, type AdminSectionKey } from "@/lib/admin-navigation";
import { type Locale } from "@/lib/i18n";

export type AdminNavigationAreaKey =
  | "command-center"
  | "customers-access"
  | "operations-desk"
  | "content-studio"
  | "revenue-risk"
  | "growth-rewards";

export type AdminNavigationArea = {
  key: AdminNavigationAreaKey;
  label: string;
  items: AdminNavEntry[];
};

type AdminNavigationAreaDefinition = {
  key: AdminNavigationAreaKey;
  itemKeys: readonly AdminSectionKey[];
};

const adminNavigationAreaDefinitions: readonly AdminNavigationAreaDefinition[] = [
  { key: "command-center", itemKeys: ["dashboard"] },
  { key: "customers-access", itemKeys: ["users", "role-management"] },
  {
    key: "operations-desk",
    itemKeys: ["generations", "feedback", "support", "moderation", "audit"],
  },
  { key: "content-studio", itemKeys: ["templates"] },
  { key: "revenue-risk", itemKeys: ["economy"] },
  { key: "growth-rewards", itemKeys: ["promo-codes", "gamification"] },
];

const adminNavigationAreaLabels: Record<Locale, Record<AdminNavigationAreaKey, string>> = {
  ru: {
    "command-center": "Командный центр",
    "customers-access": "Клиенты и доступ",
    "operations-desk": "Операционный центр",
    "content-studio": "Контент-студия",
    "revenue-risk": "Выручка и риски",
    "growth-rewards": "Рост и награды",
  },
  en: {
    "command-center": "Command Center",
    "customers-access": "Customers & Access",
    "operations-desk": "Operations Desk",
    "content-studio": "Content Studio",
    "revenue-risk": "Revenue & Risk",
    "growth-rewards": "Growth & Rewards",
  },
};

export function getAdminNavigationAreas(
  locale: Locale,
  roles?: readonly string[] | null
): AdminNavigationArea[] {
  return buildAdminNavigationAreas(locale, getAdminNavItems(locale, roles));
}

export function buildAdminNavigationAreas(
  locale: Locale,
  navItems: readonly AdminNavEntry[]
): AdminNavigationArea[] {
  const itemsByKey = new Map<AdminSectionKey, AdminNavEntry>(
    navItems.map((item) => [item.key, item])
  );
  const labels = adminNavigationAreaLabels[locale];

  return adminNavigationAreaDefinitions
    .map((area) => ({
      key: area.key,
      label: labels[area.key],
      items: area.itemKeys
        .map((itemKey) => itemsByKey.get(itemKey))
        .filter((item): item is AdminNavEntry => item !== undefined),
    }))
    .filter((area) => area.items.length > 0);
}
