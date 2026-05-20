import { type Locale, getDictionary } from "@/lib/i18n";

export type AdminSectionKey =
  | "dashboard"
  | "support"
  | "users"
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

export function getAdminNavItems(locale: Locale): AdminNavEntry[] {
  const text = getDictionary(locale);

  return [
    { type: "link", key: "dashboard", href: `/${locale}/dashboard`, label: text.navDashboard },
    { type: "link", key: "support", href: `/${locale}/support`, label: text.navSupport },
    { type: "link", key: "users", href: `/${locale}/users`, label: text.navUsers },
    {
      type: "group",
      key: "templates",
      href: `/${locale}/templates/video`,
      label: text.navTemplates,
      items: [
        { type: "link", key: "video-templates", href: `/${locale}/templates/video`, label: text.navVideoTemplates },
        { type: "link", key: "image-templates", href: `/${locale}/templates/image`, label: text.navImageTemplates },
        { type: "link", key: "template-analytics", href: `/${locale}/templates/analytics`, label: text.navTemplateAnalytics },
        { type: "link", key: "template-categories", href: `/${locale}/templates/categories`, label: text.navTemplateCategories },
      ],
    },
  ];
}

function matchesAnyAdminPath(currentPath: string, ...targetPaths: string[]) {
  return targetPaths.some((targetPath) => matchesAdminPath(currentPath, targetPath));
}

export function getAdminPageMeta(locale: Locale, currentPath: string, userName: string): AdminPageMeta {
  const trimmedName = userName.trim();
  const fallbackName = locale === "ru" ? "администратор" : "administrator";
  const normalizedName = trimmedName ? trimmedName.charAt(0).toUpperCase() + trimmedName.slice(1) : fallbackName;

  if (matchesAdminPath(currentPath, "/dashboard")) {
    return {
      title: locale === "ru" ? "Дашборд" : "Dashboard",
      description:
        locale === "ru"
          ? `Обзор ключевых метрик и активности, ${normalizedName}.`
          : `Overview of key metrics and activity, ${normalizedName}.`,
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

  if (matchesAdminPath(currentPath, "/support")) {
    return {
      title: locale === "ru" ? "Поддержка" : "Support",
      description:
        locale === "ru"
          ? "Очередь диалогов поддержки с пользователями и быстрые ответы команды."
          : "Support conversation inbox with fast team replies.",
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
