import { getAdminPageMetaCopy } from "@/lib/admin-navigation.content";
import { canAccessAdminSection } from "@/lib/admin-rbac";
import { type Locale, getDictionary } from "@/lib/i18n";

export type AdminSectionKey =
  | "dashboard"
  | "economy"
  | "gamification"
  | "promo-codes"
  | "support"
  | "moderation"
  | "audit"
  | "users"
  | "email-broadcasts"
  | "generations"
  | "feedback"
  | "role-management"
  | "templates"
  | "image-templates"
  | "video-templates"
  | "template-analytics"
  | "template-categories"
  | "template-discovery"
  | "template-daily-featured";

export type AdminNavLink = {
  type: "link";
  key: Exclude<AdminSectionKey, "templates">;
  href: string;
  label: string;
};

export type AdminNavGroup = {
  type: "group";
  key: "templates";
  href: string;
  label: string;
  items: AdminNavLink[];
};

export type AdminNavEntry = AdminNavLink | AdminNavGroup;
export type AdminCommandItem = AdminNavLink & {
  groupLabel?: string;
};

type AdminPageMeta = {
  title: string;
  description: string;
};

export function stripLocalePrefix(pathname?: string | null) {
  if (!pathname) {
    return "/";
  }

  const normalized = pathname.replace(/^\/(ru|en)(?=\/|$)/, "") || "/";
  return normalized.startsWith("/") ? normalized : `/${normalized}`;
}

export function buildLocaleSwitchPath(
  targetLocale: Locale,
  pathname?: string | null,
  search?: string | null
) {
  const currentPath = stripLocalePrefix(pathname);
  const targetPath = currentPath === "/" ? `/${targetLocale}` : `/${targetLocale}${currentPath}`;
  const normalizedSearch = search?.replace(/^\?/, "") ?? "";

  return normalizedSearch ? `${targetPath}?${normalizedSearch}` : targetPath;
}

export function matchesAdminPath(currentPath: string, targetPath: string) {
  return currentPath === targetPath || currentPath.startsWith(`${targetPath}/`);
}

export function getAdminNavItems(
  locale: Locale,
  roles?: readonly string[] | null
): AdminNavEntry[] {
  const text = getDictionary(locale);

  const allItems: AdminNavEntry[] = [
    { type: "link", key: "dashboard", href: `/${locale}/dashboard`, label: text.navDashboard },
    { type: "link", key: "economy", href: `/${locale}/economy`, label: text.navEconomy },
    {
      type: "link",
      key: "gamification",
      href: `/${locale}/gamification`,
      label: text.navGamification,
    },
    { type: "link", key: "promo-codes", href: `/${locale}/promo-codes`, label: text.navPromoCodes },
    { type: "link", key: "support", href: `/${locale}/support`, label: text.navSupport },
    { type: "link", key: "moderation", href: `/${locale}/moderation`, label: text.navModeration },
    { type: "link", key: "audit", href: `/${locale}/audit`, label: text.navAudit },
    { type: "link", key: "users", href: `/${locale}/users`, label: text.navUsers },
    {
      type: "link",
      key: "email-broadcasts",
      href: `/${locale}/email-broadcasts`,
      label: text.navEmailBroadcasts,
    },
    {
      type: "link",
      key: "generations",
      href: `/${locale}/generations`,
      label: text.navGenerations,
    },
    {
      type: "link",
      key: "feedback",
      href: `/${locale}/feedback`,
      label: text.navFeedback,
    },
    {
      type: "link",
      key: "role-management",
      href: `/${locale}/roles`,
      label: text.navRoleManagement,
    },
    {
      type: "group",
      key: "templates",
      href: `/${locale}/templates`,
      label: text.navTemplates,
      items: [
        {
          type: "link",
          key: "template-discovery",
          href: `/${locale}/templates/discovery`,
          label: text.navTemplateDiscovery,
        },
        {
          type: "link",
          key: "video-templates",
          href: `/${locale}/templates/video`,
          label: text.navVideoTemplates,
        },
        {
          type: "link",
          key: "image-templates",
          href: `/${locale}/templates/image`,
          label: text.navImageTemplates,
        },
        {
          type: "link",
          key: "template-analytics",
          href: `/${locale}/templates/analytics`,
          label: text.navTemplateAnalytics,
        },
        {
          type: "link",
          key: "template-daily-featured",
          href: `/${locale}/templates/daily-featured`,
          label: text.navTemplateDailyFeatured,
        },
        {
          type: "link",
          key: "template-categories",
          href: `/${locale}/templates/categories`,
          label: text.navTemplateCategories,
        },
      ],
    },
  ];

  const effectiveRoles = roles ?? [];
  return allItems
    .map((entry) => {
      if (entry.type === "link") {
        return canAccessAdminSection(effectiveRoles, entry.key) ? entry : null;
      }

      const items = entry.items.filter((item) => canAccessAdminSection(effectiveRoles, item.key));

      return items.length > 0 && canAccessAdminSection(effectiveRoles, entry.key)
        ? { ...entry, items }
        : null;
    })
    .filter((entry): entry is AdminNavEntry => entry !== null);
}

export function getAdminCommandItems(
  locale: Locale,
  roles?: readonly string[] | null
): AdminCommandItem[] {
  return getAdminNavItems(locale, roles).flatMap((entry) => {
    if (entry.type === "link") {
      return [entry];
    }

    return entry.items.map((item) => ({
      ...item,
      groupLabel: entry.label,
    }));
  });
}

export function filterAdminCommandItems(
  items: readonly AdminCommandItem[],
  query: string
): AdminCommandItem[] {
  const normalizedQuery = query.trim().toLocaleLowerCase();
  if (!normalizedQuery) {
    return [...items];
  }

  return items.filter((item) =>
    `${item.label} ${item.groupLabel ?? ""}`.toLocaleLowerCase().includes(normalizedQuery)
  );
}

function matchesAnyAdminPath(currentPath: string, ...targetPaths: string[]) {
  return targetPaths.some((targetPath) => matchesAdminPath(currentPath, targetPath));
}

export function getAdminPageMeta(
  locale: Locale,
  currentPath: string,
  userName: string
): AdminPageMeta {
  const copy = getAdminPageMetaCopy(locale);
  const trimmedName = userName.trim();
  const fallbackName = copy.fallbackAdministratorName;
  const normalizedName = trimmedName
    ? trimmedName.charAt(0).toUpperCase() + trimmedName.slice(1)
    : fallbackName;

  if (matchesAdminPath(currentPath, "/dashboard")) {
    return {
      title: copy.dashboard.title,
      description: copy.dashboard.description(normalizedName),
    };
  }

  if (matchesAdminPath(currentPath, "/economy")) {
    return copy.economy;
  }

  if (matchesAdminPath(currentPath, "/gamification")) {
    return copy.gamification;
  }

  if (matchesAdminPath(currentPath, "/promo-codes")) {
    return copy.promoCodes;
  }

  if (currentPath.startsWith("/users/")) {
    return copy.userProfile;
  }

  if (matchesAdminPath(currentPath, "/users")) {
    return copy.users;
  }

  if (matchesAdminPath(currentPath, "/email-broadcasts")) {
    return copy.emailBroadcasts;
  }

  if (matchesAdminPath(currentPath, "/generations")) {
    return copy.generations;
  }

  if (matchesAdminPath(currentPath, "/feedback")) {
    return copy.feedback;
  }

  if (matchesAdminPath(currentPath, "/roles")) {
    return copy.roleManagement;
  }

  if (matchesAdminPath(currentPath, "/support")) {
    return copy.support;
  }

  if (matchesAdminPath(currentPath, "/moderation")) {
    return copy.moderation;
  }

  if (matchesAdminPath(currentPath, "/audit")) {
    return copy.audit;
  }

  if (matchesAdminPath(currentPath, "/notifications")) {
    return copy.notifications;
  }

  if (
    matchesAnyAdminPath(currentPath, "/templates/image/analytics", "/templates/video/analytics")
  ) {
    return copy.templateAnalytics;
  }

  if (matchesAnyAdminPath(currentPath, "/templates/image", "/image-templates")) {
    return copy.imageTemplates;
  }

  if (matchesAnyAdminPath(currentPath, "/templates/video", "/video-templates")) {
    return copy.videoTemplates;
  }

  if (matchesAdminPath(currentPath, "/templates/categories")) {
    return copy.templateCategories;
  }

  if (matchesAdminPath(currentPath, "/templates/discovery")) {
    return copy.templateDiscovery;
  }

  if (matchesAdminPath(currentPath, "/templates/daily-featured")) {
    return copy.templateDailyFeatured;
  }

  if (matchesAdminPath(currentPath, "/templates/analytics")) {
    return copy.templateAnalytics;
  }

  if (matchesAdminPath(currentPath, "/templates")) {
    return copy.templates;
  }

  return copy.workspace;
}
