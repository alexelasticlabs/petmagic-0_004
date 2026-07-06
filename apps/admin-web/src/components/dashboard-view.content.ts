import { type Locale } from "@/lib/i18n";

type DashboardOrderStatusType = "new" | "processing" | "delivered" | "cancelled";

export type DashboardCopy = {
  hero: {
    eyebrow: string;
    title: string;
    description: string;
  };
  revenueChart: {
    title: string;
    description: string;
    rangeLabel: string;
    ariaLabel: string;
    dateHeader: string;
    revenueHeader: string;
  };
  ordersSection: {
    title: string;
    description: string;
    viewAllLabel: string;
    headers: {
      order: string;
      user: string;
      amount: string;
      status: string;
    };
  };
  distributionSection: {
    title: string;
    totalLabel: string;
  };
  activitySection: {
    title: string;
    description: string;
  };
  stats: {
    users: string;
    premiumUsers: string;
    activeSubscriptions: string;
    generationsToday: string;
    failedGenerations: string;
    pendingJobs: string;
    paymentSuccessFailure: string;
    moderationQueue: string;
    orders: string;
    revenue: string;
    conversion: string;
    usersSubtext: string;
    premiumUsersSubtext: string;
    activeSubscriptionsSubtext: string;
    pendingJobsSubtext: string;
    paymentSuccessFailureSubtext: string;
    moderationQueueSubtext: string;
    ordersSubtext: string;
    revenueSubtext: string;
    conversionSubtext: string;
    live: string;
    todayShort: string;
    weekShort: string;
    monthShort: string;
    runningShort: string;
    currentWeek: string;
    pp: string;
  };
  states: {
    retry: string;
    refreshing: string;
    dashboardLoadErrorTitle: string;
    dashboardLoadErrorDescription: string;
    dashboardLoadingTitle: string;
    dashboardLoadingDescription: string;
    staleTitle: string;
    staleDescription: string;
    ordersUnavailableTitle: string;
    ordersUnavailableDescription: string;
    noPaymentsTitle: string;
    noPaymentsDescription: string;
    activityUnavailableTitle: string;
    activityUnavailableDescription: string;
    noActivityTitle: string;
    noActivityDescription: string;
  };
  orderStatusLabels: Record<DashboardOrderStatusType, string>;
  roleLabels: {
    administrators: string;
    moderators: string;
    users: string;
  };
  activityMessages: {
    registered: (userLabel: string) => string;
    orderUpdated: (userLabel: string, orderId: string) => string;
    orderFailed: (userLabel: string, orderId: string) => string;
    ticketUpdated: (ticketId: string, status: string) => string;
  };
  relativeTime: {
    justNow: string;
    minutesAgo: (value: number) => string;
    hoursAgo: (value: number) => string;
    daysAgo: (value: number) => string;
  };
};

const dashboardCopy: Record<Locale, DashboardCopy> = {
  ru: {
    hero: {
      eyebrow: "Центр управления",
      title: "Обзор админки",
      description: "Актуальные метрики пользователей, монетизации и поддержки в реальном времени.",
    },
    revenueChart: {
      title: "Динамика выручки",
      description: "Последние семь дней по успешным платежам",
      rangeLabel: "Неделя",
      ariaLabel: "График выручки",
      dateHeader: "Дата",
      revenueHeader: "Выручка",
    },
    ordersSection: {
      title: "Последние заказы",
      description: "Живая лента платежей",
      viewAllLabel: "Смотреть все",
      headers: {
        order: "Заказ",
        user: "Пользователь",
        amount: "Сумма",
        status: "Статус",
      },
    },
    distributionSection: {
      title: "Распределение пользователей",
      totalLabel: "Всего",
    },
    activitySection: {
      title: "Активность",
      description: "Последние события из модулей",
    },
    stats: {
      users: "Пользователи",
      premiumUsers: "Премиум-пользователи",
      activeSubscriptions: "Активные подписки",
      generationsToday: "Генерации сегодня",
      failedGenerations: "Ошибки генераций",
      pendingJobs: "Очередь генераций",
      paymentSuccessFailure: "Платежи успех/ошибка",
      moderationQueue: "Очередь модерации",
      orders: "Заказы",
      revenue: "Выручка",
      conversion: "Конверсия",
      usersSubtext: "новые за 7 дней к предыдущим 7",
      premiumUsersSubtext: "по премиум-статусу",
      activeSubscriptionsSubtext: "статус активной подписки",
      pendingJobsSubtext: "ожидают обработки",
      paymentSuccessFailureSubtext: "за текущие 7 дней",
      moderationQueueSubtext: "ожидающие элементы модерации",
      ordersSubtext: "заказы за 7 дней к предыдущим 7",
      revenueSubtext: "выручка за 7 дней к предыдущим 7",
      conversionSubtext: "доля успешных заказов за 7 дней",
      live: "онлайн",
      todayShort: "сегодня",
      weekShort: "за неделю",
      monthShort: "за 30 дней",
      runningShort: "в работе",
      currentWeek: "текущая неделя",
      pp: " п.п.",
    },
    states: {
      retry: "Повторить",
      refreshing: "Обновляем...",
      dashboardLoadErrorTitle: "Не удалось загрузить дашборд",
      dashboardLoadErrorDescription: "Проверьте доступ к API и повторите позже.",
      dashboardLoadingTitle: "Загружаем данные",
      dashboardLoadingDescription:
        "Собираем актуальные метрики из модулей пользователей, экономики и поддержки.",
      staleTitle: "Данные могут быть устаревшими",
      staleDescription:
        "Показываем последнюю загруженную версию дашборда, потому что обновление KPI завершилось ошибкой.",
      ordersUnavailableTitle: "Заказы временно недоступны",
      ordersUnavailableDescription:
        "KPI дашборда загружены, но лента последних платежей не ответила.",
      noPaymentsTitle: "Платежей пока нет",
      noPaymentsDescription: "Последние платежи появятся здесь после первой успешной покупки.",
      activityUnavailableTitle: "Часть активности недоступна",
      activityUnavailableDescription:
        "Показываем доступные события; недоступные ленты можно перезагрузить.",
      noActivityTitle: "Активности пока нет",
      noActivityDescription:
        "События появятся после регистрации пользователей, платежей или обновлений поддержки.",
    },
    orderStatusLabels: {
      new: "Новый",
      processing: "В обработке",
      delivered: "Успешно",
      cancelled: "Ошибка",
    },
    roleLabels: {
      administrators: "Администраторы",
      moderators: "Модераторы",
      users: "Пользователи",
    },
    activityMessages: {
      registered: (userLabel) => `${userLabel} зарегистрировался в системе`,
      orderUpdated: (userLabel, orderId) => `${userLabel}: заказ ${orderId} обновлён`,
      orderFailed: (userLabel, orderId) => `${userLabel}: заказ ${orderId} завершился ошибкой`,
      ticketUpdated: (ticketId, status) => `Обновлён тикет ${ticketId}: ${status}`,
    },
    relativeTime: {
      justNow: "только что",
      minutesAgo: (value) => `${value} мин назад`,
      hoursAgo: (value) => `${value} ч назад`,
      daysAgo: (value) => `${value} дн назад`,
    },
  },
  en: {
    hero: {
      eyebrow: "Control center",
      title: "Admin Overview",
      description: "Live user, monetization, and support metrics in one place.",
    },
    revenueChart: {
      title: "Revenue dynamics",
      description: "Last seven days across successful payments",
      rangeLabel: "Week",
      ariaLabel: "Revenue chart",
      dateHeader: "Date",
      revenueHeader: "Revenue",
    },
    ordersSection: {
      title: "Recent orders",
      description: "Live stream of purchase events",
      viewAllLabel: "View all",
      headers: {
        order: "Order",
        user: "User",
        amount: "Amount",
        status: "Status",
      },
    },
    distributionSection: {
      title: "User distribution",
      totalLabel: "Total",
    },
    activitySection: {
      title: "Activity",
      description: "Latest events across modules",
    },
    stats: {
      users: "Users",
      premiumUsers: "Premium users",
      activeSubscriptions: "Active subscriptions",
      generationsToday: "Generations today",
      failedGenerations: "Failed generations",
      pendingJobs: "Pending jobs",
      paymentSuccessFailure: "Payments success/fail",
      moderationQueue: "Moderation queue",
      orders: "Orders",
      revenue: "Revenue",
      conversion: "Conversion",
      usersSubtext: "new in 7d vs previous 7d",
      premiumUsersSubtext: "by Premium status",
      activeSubscriptionsSubtext: "status Active",
      pendingJobsSubtext: "waiting for processing",
      paymentSuccessFailureSubtext: "current 7-day window",
      moderationQueueSubtext: "pending moderation items",
      ordersSubtext: "orders in 7d vs previous 7d",
      revenueSubtext: "revenue in 7d vs previous 7d",
      conversionSubtext: "successful orders ratio in last 7d",
      live: "live",
      todayShort: "today",
      weekShort: "week",
      monthShort: "30d",
      runningShort: "running",
      currentWeek: "current week",
      pp: "pp",
    },
    states: {
      retry: "Retry",
      refreshing: "Refreshing...",
      dashboardLoadErrorTitle: "Failed to load dashboard",
      dashboardLoadErrorDescription: "Please verify API access and try again.",
      dashboardLoadingTitle: "Loading data",
      dashboardLoadingDescription:
        "Gathering live metrics from users, economy, and support modules.",
      staleTitle: "Data may be stale",
      staleDescription: "Showing the last loaded dashboard because the KPI refresh failed.",
      ordersUnavailableTitle: "Orders temporarily unavailable",
      ordersUnavailableDescription:
        "Dashboard KPIs loaded, but the recent payments feed did not respond.",
      noPaymentsTitle: "No payments yet",
      noPaymentsDescription:
        "Recent payments will appear here after the first successful purchase.",
      activityUnavailableTitle: "Some activity is unavailable",
      activityUnavailableDescription: "Showing available events; unavailable feeds can be retried.",
      noActivityTitle: "No recent activity",
      noActivityDescription:
        "Events will appear after users register, payments update, or support tickets change.",
    },
    orderStatusLabels: {
      new: "New",
      processing: "Processing",
      delivered: "Succeeded",
      cancelled: "Failed",
    },
    roleLabels: {
      administrators: "Administrators",
      moderators: "Moderators",
      users: "Users",
    },
    activityMessages: {
      registered: (userLabel) => `${userLabel} registered in the system`,
      orderUpdated: (userLabel, orderId) => `${userLabel}: order ${orderId} updated`,
      orderFailed: (userLabel, orderId) => `${userLabel}: order ${orderId} failed`,
      ticketUpdated: (ticketId, status) => `Updated ticket ${ticketId}: ${status}`,
    },
    relativeTime: {
      justNow: "just now",
      minutesAgo: (value) => `${value} min ago`,
      hoursAgo: (value) => `${value}h ago`,
      daysAgo: (value) => `${value}d ago`,
    },
  },
};

const dashboardIntlLocales: Record<Locale, string> = {
  ru: "ru-RU",
  en: "en-US",
};

export function getDashboardCopy(locale: Locale): DashboardCopy {
  return dashboardCopy[locale];
}

export function getDashboardIntlLocale(locale: Locale): string {
  return dashboardIntlLocales[locale];
}
