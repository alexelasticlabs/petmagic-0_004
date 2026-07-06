import { type Locale } from "@/lib/i18n";

const promoCodesViewText = {
  ru: {
    intlLocale: "ru-RU",
    notificationTitle: "Промокоды",
    archiveActionLabel: "Архивировать",
    archiveCancelLabel: "Отмена",
    adminOnlyMessage: "Управление промокодами доступно только администратору.",
    kpiCodesLabel: "Коды",
    kpiFilteredListHint: "Текущий отфильтрованный список.",
    kpiActiveLabel: "Активные",
    kpiUsesLabel: "Использования",
    kpiUsesHint: "Итоги считаются агрегатом по всем найденным промокодам.",
    kpiGrantedLabel: "Выдано",
    kpiGrantedHint: "Экспорт CSV выгружает текущую страницу результатов.",
    pageSizeAriaLabel: "Размер страницы",
    statusTabAll: "Все",
    statusTabActive: "Активные",
    statusTabDraft: "Черновики",
    statusTabPaused: "Приостановленные",
    statusTabExpired: "Истекшие",
    statusTabArchived: "Архивные",
    rewardAllLabel: "Все награды",
    pageSizeSuffix: "на странице",
    paginationShowing: "Показано",
    paginationOf: "из",
    paginationPage: "Страница",
    autoRefreshPrefix: "Автообновление",
  },
  en: {
    intlLocale: "en-US",
    notificationTitle: "Promo codes",
    archiveActionLabel: "Archive",
    archiveCancelLabel: "Cancel",
    adminOnlyMessage: "Promo code management is available to Admin only.",
    kpiCodesLabel: "Codes",
    kpiFilteredListHint: "Current filtered list.",
    kpiActiveLabel: "Active",
    kpiUsesLabel: "Uses",
    kpiUsesHint: "Totals are aggregated across all matching promo codes.",
    kpiGrantedLabel: "Granted",
    kpiGrantedHint: "CSV export includes the current result page.",
    pageSizeAriaLabel: "Page size",
    statusTabAll: "All",
    statusTabActive: "Active",
    statusTabDraft: "Drafts",
    statusTabPaused: "Paused",
    statusTabExpired: "Expired",
    statusTabArchived: "Archived",
    rewardAllLabel: "All rewards",
    pageSizeSuffix: "per page",
    paginationShowing: "Showing",
    paginationOf: "of",
    paginationPage: "Page",
    autoRefreshPrefix: "Auto refresh",
  },
} as const;

export type PromoCodesViewText = {
  [K in keyof (typeof promoCodesViewText)["en"]]: string;
};

export function getPromoCodesViewText(locale: Locale): PromoCodesViewText {
  return promoCodesViewText[locale] as PromoCodesViewText;
}

export function buildPromoCodesPageSizeLabel(locale: Locale, pageSize: number) {
  const text = getPromoCodesViewText(locale);
  return `${pageSize} ${text.pageSizeSuffix}`;
}

export function buildPromoCodesPaginationSummary(
  locale: Locale,
  shownRangeStart: string,
  shownRangeEnd: string,
  totalCount: string
) {
  const text = getPromoCodesViewText(locale);
  return `${text.paginationShowing} ${shownRangeStart}-${shownRangeEnd} ${text.paginationOf} ${totalCount}`;
}

export function buildPromoCodesPageLabel(locale: Locale, pageNumber: string) {
  const text = getPromoCodesViewText(locale);
  return `${text.paginationPage} ${pageNumber}`;
}

export function buildPromoCodesAutoRefreshLabel(locale: Locale, secondsUntilAutoRefresh: number) {
  const text = getPromoCodesViewText(locale);
  return `${text.autoRefreshPrefix}: ${secondsUntilAutoRefresh}s`;
}
