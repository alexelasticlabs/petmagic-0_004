import { type Locale } from "@/lib/i18n";
import { type AdminTheme } from "@/lib/theme";

export type AdminNotificationCategory =
  "support" | "users" | "templates" | "economy" | "promo" | "system";

export type AdminNotificationFilter = "all" | "unread" | AdminNotificationCategory;

type AdminChromeCopy = {
  rtfLocale: "ru" | "en";
  accessGateChecking: string;
  skipToContent: string;
  roles: {
    admin: string;
    moderator: string;
    adminFallback: string;
  };
  realtimeSupport: {
    title: string;
    fallback: string;
  };
  logoutDialog: {
    title: string;
    description: string;
    cancel: string;
  };
  sidebar: {
    brandTitle: string;
    brandCaption: string;
    closeNavigationLabel: string;
    navigationLabel: string;
    supportUnreadLabel: (count: number) => string;
  };
  topbar: {
    themeLabel: (theme: AdminTheme) => string;
    nextThemeAriaLabel: (theme: AdminTheme) => string;
    sidebarToggleLabel: (sidebarOpen: boolean) => string;
    notificationFiltersLabel: string;
    notificationTriggerLabel: (open: boolean) => string;
    filterLabels: Record<AdminNotificationFilter, string>;
    centerTitle: string;
    summary: (unreadCount: number, supportUnreadCount: number) => string;
    close: string;
    fullHistory: string;
    moreActions: string;
    markAllRead: string;
    clearRead: string;
    critical: string;
    pinned: string;
    needsAttention: string;
    supportSummaryTitle: (count: number) => string;
    supportSummaryMessage: string;
    groupLabels: {
      today: string;
      yesterday: string;
      earlier: string;
    };
    categoryLabels: Record<AdminNotificationCategory, string>;
    emptyTitle: string;
    emptyMessage: string;
  };
  commandPalette: {
    triggerLabel: string;
    triggerAriaLabel: string;
    dialogTitle: string;
    searchLabel: string;
    searchPlaceholder: string;
    userSearchLabel: string;
    userSearchPlaceholder: string;
    resultsLabel: string;
    sectionsLabel: string;
    usersLabel: string;
    userSearchMinimum: string;
    usersLoading: string;
    usersLoadingMessage: string;
    usersErrorTitle: string;
    usersErrorMessage: string;
    retryLabel: string;
    usersEmptyTitle: string;
    usersEmptyMessage: string;
    currentPage: string;
    emptyTitle: string;
    emptyMessage: string;
    closeLabel: string;
    navigateHint: string;
  };
  langDropdown: {
    languageLabel: string;
    triggerLabel: string;
    currentLabel: string;
    currentLanguageName: string;
    ruOption: string;
    enOption: string;
  };
  loginScreen: {
    welcomeTitle: string;
    welcomeSubtitle: string;
    previewWindowTitle: string;
    copyright: string;
    themeLabel: string;
    toggleThemeAriaLabel: string;
  };
  loginCard: {
    emailPlaceholder: string;
    passwordPlaceholder: string;
    validationError: string;
    noAccess: string;
    hidePassword: string;
    showPassword: string;
    contactText: string;
    contactLinkText: string;
    orText: string;
  };
};

const adminChromeCopy: Record<Locale, AdminChromeCopy> = {
  ru: {
    rtfLocale: "ru",
    accessGateChecking: "Проверяем доступ...",
    skipToContent: "Перейти к основному содержимому",
    roles: {
      admin: "Администратор",
      moderator: "Модератор",
      adminFallback: "Администратор",
    },
    realtimeSupport: {
      title: "Поддержка",
      fallback: "В поддержке появилось новое сообщение",
    },
    logoutDialog: {
      title: "Выйти из админ-панели?",
      description: "Текущая сессия будет очищена, и для возврата потребуется повторный вход.",
      cancel: "Отмена",
    },
    sidebar: {
      brandTitle: "PetMagic Admin",
      brandCaption: "Операционная админ-зона",
      closeNavigationLabel: "Закрыть навигацию",
      navigationLabel: "Навигация админ-панели",
      supportUnreadLabel: (count) => `${count} новых сообщений в поддержке`,
    },
    topbar: {
      themeLabel: (theme) => (theme === "dark" ? "Тёмная" : "Светлая"),
      nextThemeAriaLabel: (theme) =>
        theme === "dark" ? "Включить светлую тему" : "Включить тёмную тему",
      sidebarToggleLabel: (sidebarOpen) =>
        sidebarOpen ? "Закрыть навигацию" : "Открыть навигацию",
      notificationFiltersLabel: "Фильтры уведомлений",
      notificationTriggerLabel: (open) => (open ? "Закрыть уведомления" : "Открыть уведомления"),
      filterLabels: {
        all: "Все",
        unread: "Новые",
        support: "Поддержка",
        users: "Пользователи",
        templates: "Шаблоны",
        economy: "Экономика",
        promo: "Промокоды",
        system: "Система",
      },
      centerTitle: "Уведомления",
      summary: (unreadCount, supportUnreadCount) =>
        `${unreadCount} новых в ленте${
          supportUnreadCount > 0 ? `, ${supportUnreadCount} новых сообщений в поддержке` : ""
        }`,
      close: "Закрыть уведомления",
      fullHistory: "Вся история",
      moreActions: "Другие действия",
      markAllRead: "Прочитать всё",
      clearRead: "Очистить прочитанное",
      critical: "Критично",
      pinned: "Закреплено",
      needsAttention: "требует внимания",
      supportSummaryTitle: (count) => `${count} новых сообщений в поддержке`,
      supportSummaryMessage:
        "Открой очередь поддержки и разберите новые или непрочитанные диалоги.",
      groupLabels: {
        today: "Сегодня",
        yesterday: "Вчера",
        earlier: "Ранее",
      },
      categoryLabels: {
        support: "Поддержка",
        users: "Пользователи",
        templates: "Шаблоны",
        economy: "Экономика",
        promo: "Промокоды",
        system: "Система",
      },
      emptyTitle: "Пока пусто",
      emptyMessage:
        "Важные действия из поддержки, пользователей и шаблонов будут появляться здесь.",
    },
    commandPalette: {
      triggerLabel: "Поиск",
      triggerAriaLabel: "Поиск по разделам и командам",
      dialogTitle: "Быстрый переход",
      searchLabel: "Найти раздел",
      searchPlaceholder: "Пользователи, экономика, шаблоны...",
      userSearchLabel: "Найти раздел или пользователя",
      userSearchPlaceholder: "Раздел, имя, email или ID пользователя...",
      resultsLabel: "Доступные результаты",
      sectionsLabel: "Разделы",
      usersLabel: "Пользователи",
      userSearchMinimum: "Введите не менее 2 символов для поиска пользователей.",
      usersLoading: "Ищем пользователей",
      usersLoadingMessage: "Разделы остаются доступны во время поиска.",
      usersErrorTitle: "Не удалось найти пользователей",
      usersErrorMessage: "Разделы доступны. Повторите поиск пользователей.",
      retryLabel: "Повторить",
      usersEmptyTitle: "Пользователи не найдены",
      usersEmptyMessage: "Проверьте имя, email или ID. Разделы выше по-прежнему доступны.",
      currentPage: "Текущая страница",
      emptyTitle: "Ничего не найдено",
      emptyMessage: "Попробуйте название раздела или группы навигации.",
      closeLabel: "Закрыть",
      navigateHint: "Enter — открыть, ↑↓ — выбрать, Esc — закрыть",
    },
    langDropdown: {
      languageLabel: "Язык интерфейса",
      triggerLabel: "Выбрать язык интерфейса",
      currentLabel: "Текущий язык",
      currentLanguageName: "Русский",
      ruOption: "Русский",
      enOption: "English",
    },
    loginScreen: {
      welcomeTitle: "Добро пожаловать!",
      welcomeSubtitle: "Войдите в панель администратора, чтобы продолжить работу",
      previewWindowTitle: "Дашборд",
      copyright: "© 2026 Админ-панель. Все права защищены.",
      themeLabel: "Тема",
      toggleThemeAriaLabel: "Сменить тему",
    },
    loginCard: {
      emailPlaceholder: "Введите email",
      passwordPlaceholder: "Введите пароль",
      validationError: "Введите корректный email и пароль.",
      noAccess: "Доступ к админ-панели есть только у администраторов или модераторов.",
      hidePassword: "Скрыть пароль",
      showPassword: "Показать пароль",
      contactText: "Проблемы с доступом? ",
      contactLinkText: "Свяжитесь с администратором",
      orText: "или",
    },
  },
  en: {
    rtfLocale: "en",
    accessGateChecking: "Checking access...",
    skipToContent: "Skip to main content",
    roles: {
      admin: "Administrator",
      moderator: "Moderator",
      adminFallback: "Administrator",
    },
    realtimeSupport: {
      title: "Support",
      fallback: "A new support message arrived",
    },
    logoutDialog: {
      title: "Log out of admin panel?",
      description: "The current session will be cleared and signing in again will be required.",
      cancel: "Cancel",
    },
    sidebar: {
      brandTitle: "PetMagic Admin",
      brandCaption: "Operational admin workspace",
      closeNavigationLabel: "Close navigation",
      navigationLabel: "Admin navigation",
      supportUnreadLabel: (count) => `${count} new support messages`,
    },
    topbar: {
      themeLabel: (theme) => (theme === "dark" ? "Dark" : "Light"),
      nextThemeAriaLabel: (theme) =>
        theme === "dark" ? "Switch to light theme" : "Switch to dark theme",
      sidebarToggleLabel: (sidebarOpen) => (sidebarOpen ? "Close navigation" : "Open navigation"),
      notificationFiltersLabel: "Notification filters",
      notificationTriggerLabel: (open) => (open ? "Close notifications" : "Open notifications"),
      filterLabels: {
        all: "All",
        unread: "Unread",
        support: "Support",
        users: "Users",
        templates: "Templates",
        economy: "Economy",
        promo: "Promo",
        system: "System",
      },
      centerTitle: "Notifications",
      summary: (unreadCount, supportUnreadCount) =>
        `${unreadCount} unread in feed${
          supportUnreadCount > 0 ? `, ${supportUnreadCount} new support messages` : ""
        }`,
      close: "Close notifications",
      fullHistory: "Full history",
      moreActions: "More actions",
      markAllRead: "Mark all read",
      clearRead: "Clear read",
      critical: "Critical",
      pinned: "Pinned",
      needsAttention: "needs attention",
      supportSummaryTitle: (count) => `${count} new support messages`,
      supportSummaryMessage: "Open the support queue to process new and unread conversations.",
      groupLabels: {
        today: "Today",
        yesterday: "Yesterday",
        earlier: "Earlier",
      },
      categoryLabels: {
        support: "Support",
        users: "Users",
        templates: "Templates",
        economy: "Economy",
        promo: "Promo",
        system: "System",
      },
      emptyTitle: "Nothing here yet",
      emptyMessage: "Important events from support, users, and templates will appear here.",
    },
    commandPalette: {
      triggerLabel: "Search",
      triggerAriaLabel: "Search sections and commands",
      dialogTitle: "Quick navigation",
      searchLabel: "Find a section",
      searchPlaceholder: "Users, economy, templates...",
      userSearchLabel: "Find a section or user",
      userSearchPlaceholder: "Section, name, email, or user ID...",
      resultsLabel: "Available results",
      sectionsLabel: "Sections",
      usersLabel: "Users",
      userSearchMinimum: "Enter at least 2 characters to search users.",
      usersLoading: "Searching users",
      usersLoadingMessage: "Sections remain available while the search runs.",
      usersErrorTitle: "Could not search users",
      usersErrorMessage: "Sections are still available. Retry the user search.",
      retryLabel: "Retry",
      usersEmptyTitle: "No users found",
      usersEmptyMessage: "Check the name, email, or ID. Sections above remain available.",
      currentPage: "Current page",
      emptyTitle: "No results",
      emptyMessage: "Try a section or navigation group name.",
      closeLabel: "Close",
      navigateHint: "Enter to open, ↑↓ to select, Esc to close",
    },
    langDropdown: {
      languageLabel: "Interface language",
      triggerLabel: "Choose interface language",
      currentLabel: "Current language",
      currentLanguageName: "English",
      ruOption: "Русский",
      enOption: "English",
    },
    loginScreen: {
      welcomeTitle: "Welcome!",
      welcomeSubtitle: "Sign in to the admin panel to continue your work",
      previewWindowTitle: "Dashboard",
      copyright: "© 2026 Admin Panel. All rights reserved.",
      themeLabel: "Theme",
      toggleThemeAriaLabel: "Toggle theme",
    },
    loginCard: {
      emailPlaceholder: "Enter email",
      passwordPlaceholder: "Enter password",
      validationError: "Enter a valid email and password.",
      noAccess: "Admin panel access is available only for Admin or Moderator roles.",
      hidePassword: "Hide password",
      showPassword: "Show password",
      contactText: "Access issues? ",
      contactLinkText: "Contact administrator",
      orText: "or",
    },
  },
};

export function getAdminChromeCopy(locale: Locale): AdminChromeCopy {
  return adminChromeCopy[locale];
}
