import { type Locale } from "@/lib/i18n";

type DashboardOrderStatusType = "new" | "processing" | "delivered" | "cancelled";
export type DashboardStatSection = "overview" | "commerce" | "operations";
export type DashboardCommercePeriodDays = 7 | 30 | 90;
export type DashboardSystemStatus = "healthy" | "degraded" | "unhealthy";

export const DASHBOARD_COMMERCE_PERIOD_DAYS: readonly DashboardCommercePeriodDays[] = [7, 30, 90];

export type DashboardCopy = {
  hero: {
    eyebrow: string;
    title: string;
    description: string;
  };
  revenueChart: {
    title: string;
    description: (periodLabel: string) => string;
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
  systemStatusSection: {
    title: string;
    description: string;
    overallLabel: string;
    updatedAt: (time: string) => string;
    unavailableTitle: string;
    unavailableDescription: string;
    staleTitle: string;
    staleDescription: string;
    unknownCheck: string;
    nextStepLabel: string;
    checkLabels: Record<string, string>;
    statusLabels: Record<DashboardSystemStatus, string>;
    statusDescriptions: Record<DashboardSystemStatus, string>;
  };
  attentionSection: {
    title: string;
    description: string;
    openLabel: string;
    allClearTitle: string;
    allClearDescription: string;
    partialTitle: string;
    partialDescription: string;
    items: {
      supportUnread: { label: string; description: string };
      supportUnassigned: { label: string; description: string };
      failedPayments: { label: string; description: (periodLabel: string) => string };
      failedGenerations: { label: string; description: string };
      exhaustedRefunds: { label: string; description: string };
      moderation: { label: string; description: string };
      systemStatus: {
        label: string;
        degradedDescription: string;
        unhealthyDescription: string;
      };
    };
  };
  statSections: Record<DashboardStatSection, { title: string; description: string }>;
  stats: {
    users: string;
    premiumUsers: string;
    activeSubscriptions: string;
    generationsToday: string;
    failedGenerations: string;
    pendingJobs: string;
    refundRecovery: string;
    paymentSuccessFailure: string;
    moderationQueue: string;
    orders: string;
    revenue: string;
    conversion: string;
    usersSubtext: string;
    premiumUsersSubtext: string;
    activeSubscriptionsSubtext: string;
    activeSubscriptionsCountSubtext: string;
    pendingJobsSubtext: string;
    refundRecoverySubtext: string;
    paymentSuccessFailureSubtext: (periodLabel: string) => string;
    moderationQueueSubtext: string;
    ordersSubtext: (periodLabel: string) => string;
    revenueSubtext: (periodLabel: string) => string;
    conversionSubtext: (periodLabel: string) => string;
    loadedValue: string;
    todayShort: string;
    weekShort: string;
    monthShort: string;
    runningShort: string;
    exhaustedShort: string;
    currentPeriod: (periodLabel: string) => string;
    pp: string;
    noComparison: string;
    allClear: string;
    requiresReview: string;
    noErrorsToday: string;
    openSection: (label: string) => string;
  };
  commercePeriod: {
    label: string;
    options: Record<DashboardCommercePeriodDays, string>;
  };
  states: {
    retry: string;
    refresh: string;
    refreshing: string;
    lastUpdated: (time: string) => string;
    dashboardLoadErrorTitle: string;
    dashboardLoadErrorDescription: string;
    dashboardLoadingTitle: string;
    dashboardLoadingDescription: string;
    staleTitle: string;
    staleDescription: string;
    sectionUnavailableTitle: string;
    sectionUnavailableDescription: string;
    revenueUnavailableTitle: string;
    revenueUnavailableDescription: string;
    distributionUnavailableTitle: string;
    distributionUnavailableDescription: string;
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
      description:
        "Последняя загруженная сводка по пользователям, монетизации, поддержке и операциям.",
    },
    revenueChart: {
      title: "Динамика выручки",
      description: (periodLabel) => `Успешные платежи за ${periodLabel.toLowerCase()}`,
      ariaLabel: "График выручки",
      dateHeader: "Дата",
      revenueHeader: "Выручка",
    },
    ordersSection: {
      title: "Последние заказы",
      description: "Последние загруженные события платежей",
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
      description: "Последние загруженные события из модулей",
    },
    systemStatusSection: {
      title: "Состояние системы",
      description: "Показываем, что именно требует проверки и какое действие нужно выполнить",
      overallLabel: "Общий статус",
      updatedAt: (time) => `Проверено: ${time}`,
      unavailableTitle: "Системный статус недоступен",
      unavailableDescription:
        "Остальные данные сохранены. Повторите обновление, чтобы проверить критичные контуры.",
      staleTitle: "Системный статус устарел",
      staleDescription:
        "Срок актуальности проверки истёк. Обновите данные перед оценкой состояния контуров.",
      unknownCheck: "Системный контур",
      checkLabels: {
        api: "API",
        subscriptionCatalog: "Покупки и подписки",
        storeAccountBinding: "Проверка покупок в магазинах",
        generationScheduler: "Планировщик генераций",
      },
      nextStepLabel: "Следующий шаг:",
      statusLabels: {
        healthy: "Работает",
        degraded: "Требует внимания",
        unhealthy: "Недоступно",
      },
      statusDescriptions: {
        healthy: "Контур отвечает штатно.",
        degraded: "Контур отвечает, но требует проверки.",
        unhealthy: "Контур недоступен или настроен некорректно.",
      },
    },
    attentionSection: {
      title: "Требует внимания",
      description: "Открытые операционные сигналы по последней загрузке",
      openLabel: "Открыть",
      allClearTitle: "Открытых сигналов нет",
      allClearDescription:
        "Все источники блока доступны: непрочитанных и неназначенных обращений, ошибок и очереди модерации нет.",
      partialTitle: "Проверка выполнена не полностью",
      partialDescription:
        "Часть источников недоступна, поэтому статус «всё обработано» пока нельзя подтвердить.",
      items: {
        supportUnread: {
          label: "Непрочитанные обращения",
          description: "Новые сообщения ожидают реакции администратора",
        },
        supportUnassigned: {
          label: "Обращения без исполнителя",
          description: "Открытые диалоги ещё не назначены администратору",
        },
        failedPayments: {
          label: "Платежи с ошибкой",
          description: (periodLabel) => `Ошибки за ${periodLabel.toLowerCase()}`,
        },
        failedGenerations: {
          label: "Ошибки генераций",
          description: "Ошибки за последние 7 дней",
        },
        exhaustedRefunds: {
          label: "Возвраты с исчерпанными попытками",
          description: "Автоматический возврат остановлен и требует проверенного восстановления",
        },
        moderation: {
          label: "Очередь модерации",
          description: "Материалы ожидают решения модератора",
        },
        systemStatus: {
          label: "Состояние системы",
          degradedDescription: "Один или несколько критичных контуров требуют проверки",
          unhealthyDescription: "Один или несколько критичных контуров недоступны",
        },
      },
    },
    statSections: {
      overview: {
        title: "Ключевые показатели",
        description: "Пользователи, монетизация и конверсия в одном месте",
      },
      commerce: {
        title: "Подписки и платежи",
        description: "Состояние премиум-доступа и расчётов",
      },
      operations: {
        title: "Генерации и модерация",
        description: "Очереди и события, которые требуют контроля",
      },
    },
    stats: {
      users: "Пользователи",
      premiumUsers: "Премиум-пользователи",
      activeSubscriptions: "Активные подписки",
      generationsToday: "Генерации сегодня",
      failedGenerations: "Ошибки генераций",
      pendingJobs: "Очередь генераций",
      refundRecovery: "Возвраты генераций",
      paymentSuccessFailure: "Платежи успех/ошибка",
      moderationQueue: "Очередь модерации",
      orders: "Заказы",
      revenue: "Выручка",
      conversion: "Конверсия",
      usersSubtext: "новые за 7 дней к предыдущим 7",
      premiumUsersSubtext: "доля от всех пользователей",
      activeSubscriptionsSubtext: "доля от всех пользователей",
      activeSubscriptionsCountSubtext: "активные подписки провайдеров",
      pendingJobsSubtext: "ожидают обработки",
      refundRecoverySubtext: "возвраты списаний в очереди worker",
      paymentSuccessFailureSubtext: (periodLabel) => `за ${periodLabel.toLowerCase()}`,
      moderationQueueSubtext: "ожидающие элементы модерации",
      ordersSubtext: (periodLabel) =>
        `заказы за ${periodLabel.toLowerCase()} к предыдущему периоду`,
      revenueSubtext: (periodLabel) =>
        `выручка за ${periodLabel.toLowerCase()} к предыдущему периоду`,
      conversionSubtext: (periodLabel) => `доля успешных заказов за ${periodLabel.toLowerCase()}`,
      loadedValue: "загружено",
      todayShort: "сегодня",
      weekShort: "за неделю",
      monthShort: "за 30 дней",
      runningShort: "в работе",
      exhaustedShort: "исчерпано",
      currentPeriod: (periodLabel) => `текущий период: ${periodLabel.toLowerCase()}`,
      pp: " п.п.",
      noComparison: "нет базы",
      allClear: "всё обработано",
      requiresReview: "требует проверки",
      noErrorsToday: "ошибок сегодня нет",
      openSection: (label) => `Открыть раздел: ${label}`,
    },
    commercePeriod: {
      label: "Период коммерции",
      options: {
        7: "7 дней",
        30: "30 дней",
        90: "90 дней",
      },
    },
    states: {
      retry: "Повторить",
      refresh: "Обновить данные",
      refreshing: "Обновляем...",
      lastUpdated: (time) => `Последняя загрузка: ${time}`,
      dashboardLoadErrorTitle: "Не удалось загрузить дашборд",
      dashboardLoadErrorDescription: "Проверьте доступ к API и повторите позже.",
      dashboardLoadingTitle: "Загружаем данные",
      dashboardLoadingDescription:
        "Загружаем последнюю доступную сводку из модулей пользователей, экономики и поддержки.",
      staleTitle: "Данные могут быть устаревшими",
      staleDescription:
        "Показываем последнюю загруженную версию дашборда, потому что обновление KPI завершилось ошибкой.",
      sectionUnavailableTitle: "Часть показателей недоступна",
      sectionUnavailableDescription:
        "Карточки по недоступным источникам скрыты. Доступные показатели сохранены.",
      revenueUnavailableTitle: "График выручки недоступен",
      revenueUnavailableDescription:
        "Источник экономики не ответил; данные графика не заменены нулевыми значениями.",
      distributionUnavailableTitle: "Распределение пользователей недоступно",
      distributionUnavailableDescription:
        "Источник пользовательских метрик не ответил; повторите загрузку раздела.",
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
      description: "Last loaded user, monetization, support, and operations data in one place.",
    },
    revenueChart: {
      title: "Revenue dynamics",
      description: (periodLabel) => `Successful payments over ${periodLabel.toLowerCase()}`,
      ariaLabel: "Revenue chart",
      dateHeader: "Date",
      revenueHeader: "Revenue",
    },
    ordersSection: {
      title: "Recent orders",
      description: "Last loaded purchase events",
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
      description: "Last loaded events across modules",
    },
    systemStatusSection: {
      title: "System status",
      description: "See what needs attention, why it matters, and the next correct action",
      overallLabel: "Overall status",
      updatedAt: (time) => `Checked: ${time}`,
      unavailableTitle: "System status is unavailable",
      unavailableDescription:
        "Other dashboard data remains available. Refresh to check the critical paths again.",
      staleTitle: "System status is stale",
      staleDescription:
        "The status freshness window has expired. Refresh before relying on the path checks.",
      unknownCheck: "System path",
      checkLabels: {
        api: "API",
        subscriptionCatalog: "Purchases and subscriptions",
        storeAccountBinding: "Store purchase verification",
        generationScheduler: "Generation scheduler",
      },
      nextStepLabel: "Next step:",
      statusLabels: {
        healthy: "Operational",
        degraded: "Needs attention",
        unhealthy: "Unavailable",
      },
      statusDescriptions: {
        healthy: "The path is operating normally.",
        degraded: "The path responds but requires review.",
        unhealthy: "The path is unavailable or misconfigured.",
      },
    },
    attentionSection: {
      title: "Needs attention",
      description: "Open operational signals from the last load",
      openLabel: "Open",
      allClearTitle: "No open signals",
      allClearDescription:
        "All attention sources are available, with no unread or unassigned support, failures, or moderation backlog.",
      partialTitle: "Check is incomplete",
      partialDescription:
        "Some sources are unavailable, so an all-clear status cannot be confirmed yet.",
      items: {
        supportUnread: {
          label: "Unread support conversations",
          description: "New messages are waiting for an admin response",
        },
        supportUnassigned: {
          label: "Unassigned conversations",
          description: "Open conversations are not assigned to an admin",
        },
        failedPayments: {
          label: "Failed payments",
          description: (periodLabel) => `Failures over ${periodLabel.toLowerCase()}`,
        },
        failedGenerations: {
          label: "Failed generations",
          description: "Failures over the last 7 days",
        },
        exhaustedRefunds: {
          label: "Refund attempts exhausted",
          description: "Automatic refund processing stopped and needs verified recovery",
        },
        moderation: {
          label: "Moderation queue",
          description: "Items are waiting for a moderation decision",
        },
        systemStatus: {
          label: "System status",
          degradedDescription: "One or more critical paths require review",
          unhealthyDescription: "One or more critical paths are unavailable",
        },
      },
    },
    statSections: {
      overview: {
        title: "Key metrics",
        description: "Users, monetization, and conversion in one place",
      },
      commerce: {
        title: "Subscriptions and payments",
        description: "Premium access and payment processing status",
      },
      operations: {
        title: "Generation and moderation",
        description: "Queues and events that need attention",
      },
    },
    stats: {
      users: "Users",
      premiumUsers: "Premium users",
      activeSubscriptions: "Active subscriptions",
      generationsToday: "Generations today",
      failedGenerations: "Failed generations",
      pendingJobs: "Pending jobs",
      refundRecovery: "Generation refunds",
      paymentSuccessFailure: "Payments success/fail",
      moderationQueue: "Moderation queue",
      orders: "Orders",
      revenue: "Revenue",
      conversion: "Conversion",
      usersSubtext: "new in 7d vs previous 7d",
      premiumUsersSubtext: "share of all users",
      activeSubscriptionsSubtext: "share of all users",
      activeSubscriptionsCountSubtext: "active provider subscriptions",
      pendingJobsSubtext: "waiting for processing",
      refundRecoverySubtext: "charge refunds queued for the worker",
      paymentSuccessFailureSubtext: (periodLabel) => `over ${periodLabel.toLowerCase()}`,
      moderationQueueSubtext: "pending moderation items",
      ordersSubtext: (periodLabel) => `orders in ${periodLabel.toLowerCase()} vs previous period`,
      revenueSubtext: (periodLabel) => `revenue in ${periodLabel.toLowerCase()} vs previous period`,
      conversionSubtext: (periodLabel) => `successful orders ratio in ${periodLabel.toLowerCase()}`,
      loadedValue: "loaded",
      todayShort: "today",
      weekShort: "week",
      monthShort: "30d",
      runningShort: "running",
      exhaustedShort: "exhausted",
      currentPeriod: (periodLabel) => `current period: ${periodLabel.toLowerCase()}`,
      pp: "pp",
      noComparison: "no baseline",
      allClear: "all clear",
      requiresReview: "needs review",
      noErrorsToday: "no errors today",
      openSection: (label) => `Open section: ${label}`,
    },
    commercePeriod: {
      label: "Commerce period",
      options: {
        7: "7 days",
        30: "30 days",
        90: "90 days",
      },
    },
    states: {
      retry: "Retry",
      refresh: "Refresh data",
      refreshing: "Refreshing...",
      lastUpdated: (time) => `Last loaded: ${time}`,
      dashboardLoadErrorTitle: "Failed to load dashboard",
      dashboardLoadErrorDescription: "Please verify API access and try again.",
      dashboardLoadingTitle: "Loading data",
      dashboardLoadingDescription:
        "Loading the latest available data from users, economy, and support modules.",
      staleTitle: "Data may be stale",
      staleDescription: "Showing the last loaded dashboard because the KPI refresh failed.",
      sectionUnavailableTitle: "Some metrics are unavailable",
      sectionUnavailableDescription:
        "Cards backed by unavailable sources are hidden while available metrics remain visible.",
      revenueUnavailableTitle: "Revenue chart is unavailable",
      revenueUnavailableDescription:
        "The economy source did not respond; chart data was not replaced with zero values.",
      distributionUnavailableTitle: "User distribution is unavailable",
      distributionUnavailableDescription:
        "The user metrics source did not respond; retry loading this section.",
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
