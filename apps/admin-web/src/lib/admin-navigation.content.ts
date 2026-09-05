import { type Locale } from "@/lib/i18n";

type AdminPageMetaCopy = {
  fallbackAdministratorName: string;
  dashboard: { title: string; description: (userName: string) => string };
  economy: { title: string; description: string };
  gamification: { title: string; description: string };
  promoCodes: { title: string; description: string };
  users: { title: string; description: string };
  emailBroadcasts: { title: string; description: string };
  userProfile: { title: string; description: string };
  generations: { title: string; description: string };
  feedback: { title: string; description: string };
  roleManagement: { title: string; description: string };
  support: { title: string; description: string };
  moderation: { title: string; description: string };
  audit: { title: string; description: string };
  notifications: { title: string; description: string };
  imageTemplates: { title: string; description: string };
  videoTemplates: { title: string; description: string };
  templateCategories: { title: string; description: string };
  templateDiscovery: { title: string; description: string };
  templateDailyFeatured: { title: string; description: string };
  templateAnalytics: { title: string; description: string };
  templates: { title: string; description: string };
  workspace: { title: string; description: string };
};

const adminPageMetaCopy: Record<Locale, AdminPageMetaCopy> = {
  ru: {
    templateDiscovery: { title: "Главная каталога", description: "Категории, обложки и подборки для мобильной витрины." },
    emailBroadcasts: {
      title: "Email-рассылки",
      description: "Создание писем, выбор получателей и контроль отправки.",
    },
    fallbackAdministratorName: "администратор",
    dashboard: {
      title: "Дашборд",
      description: (userName) => `Обзор ключевых метрик и активности, ${userName}.`,
    },
    economy: {
      title: "Экономика",
      description: "Баланс, покупки, история движения валюты и управление пакетами пополнения.",
    },
    gamification: {
      title: "Геймификация",
      description:
        "Метрики вовлечённости, недельные задания, достижения и диагностика прогресса пользователей.",
    },
    promoCodes: {
      title: "Промокоды",
      description: "Промокоды: создание, лимиты, период действия и история активаций.",
    },
    users: {
      title: "Пользователи",
      description: "Управление ролями, премиум-статусом и доступом пользователей.",
    },
    userProfile: {
      title: "Профиль пользователя",
      description: "",
    },
    generations: {
      title: "Генерации",
      description:
        "Очередь и история генераций с фильтрами по статусу, провайдеру, пользователю и ID задания.",
    },
    feedback: {
      title: "Фидбек",
      description:
        "Обратная связь по генерациям, багам, оплате и предложениям со статусами и возвратом кредитов.",
    },
    roleManagement: {
      title: "Управление ролями",
      description: "Поиск и управление доступом модераторов.",
    },
    support: {
      title: "Поддержка",
      description: "Очередь диалогов поддержки с пользователями и быстрые ответы команды.",
    },
    moderation: {
      title: "Модерация",
      description: "Очередь жалоб и обратной связи по шаблонам с решением одобрить или отклонить.",
    },
    audit: {
      title: "Журнал действий",
      description:
        "История административных действий с фильтрами по исполнителю, типу события и объекту.",
    },
    notifications: {
      title: "Уведомления",
      description:
        "Операционные события, требующие чтения, архивации или командного подтверждения.",
    },
    imageTemplates: {
      title: "Шаблоны изображений",
      description: "Каталог и настройки шаблонов для генерации изображений.",
    },
    videoTemplates: {
      title: "Видео шаблоны",
      description: "Управление видео-сценариями, референсами и моделями.",
    },
    templateCategories: {
      title: "Категории шаблонов",
      description: "Сводка по категориям, типам шаблонов и наполнению каталога.",
    },
    templateDailyFeatured: {
      title: "Шаблон дня",
      description: "Ручные назначения и автоматический выбор шаблона дня.",
    },
    templateAnalytics: {
      title: "Аналитика шаблонов",
      description: "Общая статистика по просмотрам, генерациям, расходам и эффективности шаблонов.",
    },
    templates: {
      title: "Шаблоны",
      description:
        "Управление видео-шаблонами, шаблонами изображений, категориями и состояниями каталога.",
    },
    workspace: {
      title: "PetMagic Admin",
      description: "Рабочая зона администратора PetMagic.",
    },
  },
  en: {
    templateDiscovery: { title: "Discovery page", description: "Categories, covers and collections for mobile discovery." },
    emailBroadcasts: {
      title: "Email campaigns",
      description: "Compose messages, choose recipients, and track sending progress.",
    },
    fallbackAdministratorName: "administrator",
    dashboard: {
      title: "Dashboard",
      description: (userName) => `Overview of key metrics and activity, ${userName}.`,
    },
    economy: {
      title: "Economy",
      description: "Balance, purchases, currency movement history, and top-up pack management.",
    },
    gamification: {
      title: "Gamification",
      description:
        "Engagement metrics, weekly challenges, achievements, and user progress diagnostics.",
    },
    promoCodes: {
      title: "Promo codes",
      description: "Promo codes: creation, limits, availability window, and redemption history.",
    },
    users: {
      title: "Users",
      description: "Manage roles, premium status, and user access.",
    },
    userProfile: {
      title: "User profile",
      description: "",
    },
    generations: {
      title: "Generations",
      description: "Generation queue and history with status, provider, user, and job id filters.",
    },
    feedback: {
      title: "Feedback",
      description:
        "Generation, bug, payment, and general feedback with status handling and credit refunds.",
    },
    roleManagement: {
      title: "Role Management",
      description: "Find users and manage Moderator access.",
    },
    support: {
      title: "Support",
      description: "Support conversation inbox with fast team replies.",
    },
    moderation: {
      title: "Moderation",
      description: "Complaint and feedback queue for templates with approve/reject decisions.",
    },
    audit: {
      title: "Audit trail",
      description: "Administrative action history with actor, event type, and target filters.",
    },
    notifications: {
      title: "Notifications",
      description: "Operational events that require review, archive, or team acknowledgement.",
    },
    imageTemplates: {
      title: "Image templates",
      description: "Catalog and settings for image generation templates.",
    },
    videoTemplates: {
      title: "Video templates",
      description: "Manage video scenarios, references, and model settings.",
    },
    templateCategories: {
      title: "Template categories",
      description: "Overview of categories, template types, and catalog coverage.",
    },
    templateDailyFeatured: {
      title: "Daily Featured",
      description: "Manual assignments and auto-pick for Template of the Day.",
    },
    templateAnalytics: {
      title: "Template analytics",
      description: "Overview of template views, generations, spend, and performance.",
    },
    templates: {
      title: "Templates",
      description: "Manage video and image templates, categories, and catalog states.",
    },
    workspace: {
      title: "PetMagic Admin",
      description: "PetMagic administrator workspace.",
    },
  },
};

export function getAdminPageMetaCopy(locale: Locale): AdminPageMetaCopy {
  return adminPageMetaCopy[locale];
}
