import { canAccessAdminSection } from "@/lib/admin-rbac";
import { type Locale, getDictionary } from "@/lib/i18n";

export type AdminSectionKey =
  | "dashboard"
  | "economy"
  | "promo-codes"
  | "support"
  | "moderation"
  | "users"
  | "generations"
  | "role-management"
  | "templates"
  | "image-templates"
  | "video-templates"
  | "template-analytics"
  | "template-categories";

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

export function buildLocaleSwitchPath(targetLocale: Locale, pathname?: string | null) {
  const currentPath = stripLocalePrefix(pathname);
  return currentPath === "/" ? `/${targetLocale}` : `/${targetLocale}${currentPath}`;
}

export function matchesAdminPath(currentPath: string, targetPath: string) {
  return currentPath === targetPath || currentPath.startsWith(`${targetPath}/`);
}

export function getAdminNavItems(locale: Locale, roles?: readonly string[] | null): AdminNavEntry[] {
  const text = getDictionary(locale);

  const allItems: AdminNavEntry[] = [
    { type: "link", key: "dashboard", href: `/${locale}/dashboard`, label: text.navDashboard },
    { type: "link", key: "economy", href: `/${locale}/economy`, label: text.navEconomy },
    { type: "link", key: "promo-codes", href: `/${locale}/promo-codes`, label: text.navPromoCodes },
    { type: "link", key: "support", href: `/${locale}/support`, label: text.navSupport },
    { type: "link", key: "moderation", href: `/${locale}/moderation`, label: text.navModeration },
    { type: "link", key: "users", href: `/${locale}/users`, label: text.navUsers },
    { type: "link", key: "generations", href: `/${locale}/generations`, label: text.navGenerations },
    { type: "link", key: "role-management", href: `/${locale}/roles`, label: text.navRoleManagement },
    {
      type: "group",
      key: "templates",
      href: `/${locale}/templates/video`,
      label: text.navTemplates,
      items: [
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

function matchesAnyAdminPath(currentPath: string, ...targetPaths: string[]) {
  return targetPaths.some((targetPath) => matchesAdminPath(currentPath, targetPath));
}

export function getAdminPageMeta(
  locale: Locale,
  currentPath: string,
  userName: string
): AdminPageMeta {
  const trimmedName = userName.trim();
  const fallbackName = locale === "ru" ? "администратор" : "administrator";
  const normalizedName = trimmedName
    ? trimmedName.charAt(0).toUpperCase() + trimmedName.slice(1)
    : fallbackName;

  if (matchesAdminPath(currentPath, "/dashboard")) {
    return {
      title: locale === "ru" ? "Дашборд" : "Dashboard",
      description:
        locale === "ru"
          ? `Обзор ключевых метрик и активности, ${normalizedName}.`
          : `Overview of key metrics and activity, ${normalizedName}.`,
    };
  }

  if (matchesAdminPath(currentPath, "/economy")) {
    return {
      title: locale === "ru" ? "Экономика" : "Economy",
      description:
        locale === "ru"
          ? "Баланс, покупки, история движения валюты и управление пакетами пополнения."
          : "Balance, purchases, currency movement history, and top-up pack management.",
    };
  }

  if (matchesAdminPath(currentPath, "/promo-codes")) {
    return {
      title: locale === "ru" ? "Промокоды" : "Promo codes",
      description:
        locale === "ru"
          ? "Промокоды: создание, лимиты, период действия и история активаций."
          : "Promo codes: creation, limits, availability window, and redemption history.",
    };
  }

  if (matchesAdminPath(currentPath, "/users")) {
    return {
      title: locale === "ru" ? "Пользователи" : "Users",
      description:
        locale === "ru"
          ? "Управление ролями, премиум-статусом и доступом пользователей."
          : "Manage roles, premium status, and user access.",
    };
  }

  if (matchesAdminPath(currentPath, "/generations")) {
    return {
      title: locale === "ru" ? "Генерации" : "Generations",
      description:
        locale === "ru"
          ? "Очередь и история генераций с фильтрами по статусу, provider, пользователю и job id."
          : "Generation queue and history with status, provider, user, and job id filters.",
    };
  }

  if (matchesAdminPath(currentPath, "/roles")) {
    return {
      title: locale === "ru" ? "Управление ролями" : "Role Management",
      description:
        locale === "ru"
          ? "Список Admin и Moderator, назначение и снятие Moderator с backend audit log."
          : "Admin and Moderator lists with Moderator assignment and removal backed by audit log.",
    };
  }

  if (matchesAdminPath(currentPath, "/support")) {
    return {
      title: locale === "ru" ? "Поддержка" : "Support",
      description:
        locale === "ru"
          ? "Очередь диалогов поддержки с пользователями и быстрые ответы команды."
          : "Support conversation inbox with fast team replies.",
    };
  }

  if (matchesAdminPath(currentPath, "/moderation")) {
    return {
      title: locale === "ru" ? "Модерация" : "Moderation",
      description:
        locale === "ru"
          ? "Очередь жалоб и обратной связи по шаблонам с approve/reject решением."
          : "Complaint and feedback queue for templates with approve/reject decisions.",
    };
  }

  if (matchesAnyAdminPath(currentPath, "/templates/image", "/image-templates")) {
    return {
      title: locale === "ru" ? "Шаблоны изображений" : "Image templates",
      description:
        locale === "ru"
          ? "Каталог и настройки шаблонов для генерации изображений."
          : "Catalog and settings for image generation templates.",
    };
  }

  if (matchesAnyAdminPath(currentPath, "/templates/video", "/video-templates")) {
    return {
      title: locale === "ru" ? "Видео шаблоны" : "Video templates",
      description:
        locale === "ru"
          ? "Управление видео-сценариями, референсами и моделями."
          : "Manage video scenarios, references, and model settings.",
    };
  }

  if (matchesAdminPath(currentPath, "/templates/categories")) {
    return {
      title: locale === "ru" ? "Категории шаблонов" : "Template categories",
      description:
        locale === "ru"
          ? "Сводка по категориям, типам шаблонов и наполнению каталога."
          : "Overview of categories, template types, and catalog coverage.",
    };
  }

  if (matchesAdminPath(currentPath, "/templates/analytics")) {
    return {
      title: locale === "ru" ? "Аналитика шаблонов" : "Template analytics",
      description:
        locale === "ru"
          ? "Общая статистика по просмотрам, генерациям, расходам и эффективности шаблонов."
          : "Overview of template views, generations, spend, and performance.",
    };
  }

  if (matchesAdminPath(currentPath, "/templates")) {
    return {
      title: locale === "ru" ? "Шаблоны" : "Templates",
      description:
        locale === "ru"
          ? "Управление видео-шаблонами, шаблонами изображений, категориями и состояниями каталога."
          : "Manage video and image templates, categories, and catalog states.",
    };
  }

  return {
    title: locale === "ru" ? "PetMagic Admin" : "PetMagic Admin",
    description:
      locale === "ru"
        ? "Рабочая зона администратора PetMagic."
        : "PetMagic administrator workspace.",
  };
}
