import { type AdminSystemStatus } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

export type DashboardSystemStatusGuidance = {
  description: string;
  nextStep?: string;
};

const genericGuidance: Record<Locale, Record<AdminSystemStatus, DashboardSystemStatusGuidance>> = {
  ru: {
    healthy: { description: "Проверка прошла: контур работает штатно." },
    degraded: {
      description: "Контур отвечает, но его состояние нельзя считать полностью подтверждённым.",
      nextStep: "Проверьте конфигурацию и повторите проверку после исправления.",
    },
    unhealthy: {
      description: "Контур недоступен или настроен некорректно; часть функций может не работать.",
      nextStep: "Проверьте конфигурацию и логи сервиса, затем повторите проверку.",
    },
  },
  en: {
    healthy: { description: "The check passed: this path is operating normally." },
    degraded: {
      description: "The path responds, but its state has not been fully confirmed.",
      nextStep: "Review the configuration and run the check again after the fix.",
    },
    unhealthy: {
      description: "The path is unavailable or misconfigured; some features may not work.",
      nextStep: "Review service configuration and logs, then run the check again.",
    },
  },
};

const guidanceByCheck: Partial<
  Record<string, Record<Locale, Partial<Record<AdminSystemStatus, DashboardSystemStatusGuidance>>>>
> = {
  storeAccountBinding: {
    ru: {
      healthy: { description: "Новые покупки проверяются по привязке к аккаунту магазина." },
      degraded: {
        description:
          "Новые покупки не заблокированы, но пока принимаются и старые покупки без привязки к аккаунту магазина.",
        nextStep:
          "Подтвердите покупку и восстановление покупки в Apple и Google sandbox, затем включите строгую проверку привязки.",
      },
    },
    en: {
      healthy: { description: "New purchases are verified against the store account binding." },
      degraded: {
        description:
          "New purchases are not blocked, but legacy purchases without a store account binding are still accepted.",
        nextStep:
          "Confirm a purchase and restore flow in Apple and Google sandbox, then enable strict binding verification.",
      },
    },
  },
  subscriptionCatalog: {
    ru: {
      healthy: { description: "Каталог подписок доступен для проверки покупок." },
      degraded: {
        description:
          "Каталог подписок доступен не полностью; часть предложений может быть недоступна.",
        nextStep: "Проверьте продукты и цены в App Store Connect и Google Play Console.",
      },
      unhealthy: {
        description: "Каталог подписок недоступен, поэтому покупки Premium нельзя подтвердить.",
        nextStep: "Проверьте настройки продуктов и ключи магазинов, затем повторите проверку.",
      },
    },
    en: {
      healthy: { description: "The subscription catalog is available for purchase verification." },
      degraded: {
        description:
          "The subscription catalog is only partially available; some offers may be unavailable.",
        nextStep: "Review products and prices in App Store Connect and Google Play Console.",
      },
      unhealthy: {
        description:
          "The subscription catalog is unavailable, so Premium purchases cannot be verified.",
        nextStep: "Review store products and credentials, then run the check again.",
      },
    },
  },
  generationScheduler: {
    ru: {
      healthy: { description: "Очередь генераций настроена и готова принимать новые задания." },
      degraded: {
        description: "Очередь генераций отвечает, но параметры запуска требуют проверки.",
        nextStep: "Проверьте worker и активный режим scheduler, затем обновите статус.",
      },
      unhealthy: {
        description: "Очередь генераций не готова надёжно обрабатывать новые задания.",
        nextStep:
          "Проверьте worker, очередь и конфигурацию scheduler перед возобновлением трафика.",
      },
    },
    en: {
      healthy: { description: "The generation queue is configured and ready for new jobs." },
      degraded: {
        description: "The generation queue responds, but its runtime configuration needs review.",
        nextStep: "Review the worker and active scheduler mode, then refresh the status.",
      },
      unhealthy: {
        description: "The generation queue is not ready to process new work reliably.",
        nextStep: "Review the worker, queue, and scheduler configuration before resuming traffic.",
      },
    },
  },
};

export function getDashboardSystemStatusGuidance(
  locale: Locale,
  key: string,
  status: AdminSystemStatus
): DashboardSystemStatusGuidance {
  return guidanceByCheck[key]?.[locale]?.[status] ?? genericGuidance[locale][status];
}
