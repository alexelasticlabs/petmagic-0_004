import { type TemplateType } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

const templatesCatalogLocaleText = {
  ru: {
    intlLocale: "ru-RU",
    videoTitle: "Видео шаблоны",
    imageTitle: "Шаблоны изображений",
    videoDescription: "Каталог видео-шаблонов, статусы, категории и параметры доступа.",
    imageDescription: "Каталог шаблонов изображений, статусы, категории и параметры доступа.",
    createVideoTemplate: "Создать видео шаблон",
    createImageTemplate: "Создать шаблон изображения",
    manageCategories: "Управление категориями",
    analyticsAction: "Аналитика",
    templateActionsAdminOnly: "Управление шаблонами доступно только администратору.",
    analyticsUnavailableTitle: "Метрики шаблонов временно недоступны",
    analyticsUnavailableDescription:
      "Каталог остается доступным, но просмотры, генерации и ошибки могут быть неполными.",
    archiveTabsLabel: "Фильтр архива",
    allTemplates: "Все шаблоны",
    archivedTemplates: "Архив",
    searchLabel: "Поиск шаблонов",
    searchPlaceholder: "Поиск по названию, описанию, тегам...",
    allCategories: "Все категории",
    accessLabel: "Доступ",
    qaOnlyLabel: "Только QA",
    allAccess: "Все",
    allStatuses: "Все статусы",
    sortLabel: "Сортировка",
    sortNewest: "Новые сначала",
    sortNewestDescription: "Сначала свежие шаблоны",
    sortTitle: "По названию",
    sortTitleDescription: "Алфавитный порядок",
    sortTokens: "По PawSpark",
    sortTokensDescription: "По стоимости в PawSpark",
    viewToggleLabel: "Переключение вида",
    cardsView: "Карточки",
    listView: "Список",
    testAction: "Тест",
    tokensShort: "PawSpark",
    updatedLabel: "Обновлен",
    updatedShort: "Обновлен",
    previousPageLabel: "Предыдущая страница шаблонов",
    nextPageLabel: "Следующая страница шаблонов",
    retry: "Повторить",
    cancel: "Отмена",
    tableTemplate: "Шаблон",
    tableType: "Тип",
    tableViews: "Просмотры",
    tableStarts: "Запуски",
    tableConversion: "Конверсия",
    tableSuccess: "Успех",
    tableAverageCost: "Средняя стоимость",
    tokenUnit: "ток.",
    metricCost: "Стоимость",
    metricViews: "Просмотры",
    metricGenerations: "Генерации",
    metricErrors: "Ошибки",
    pageSummary: (currentPage: number, shownStart: number, shownEnd: number, totalCount: number) =>
      `Страница ${currentPage}: ${shownStart}-${shownEnd} из ${totalCount}`,
    archiveConfirmDescription: (templateLabel: string) =>
      `${templateLabel}: шаблон будет скрыт из активного каталога.`,
  },
  en: {
    intlLocale: "en-US",
    videoTitle: "Video Templates",
    imageTitle: "Image Templates",
    videoDescription: "Motion template catalog, statuses, categories, and access settings.",
    imageDescription: "Image template catalog, statuses, categories, and access settings.",
    createVideoTemplate: "Create video template",
    createImageTemplate: "Create image template",
    manageCategories: "Manage categories",
    analyticsAction: "Analytics",
    templateActionsAdminOnly: "Template management actions are available to Admin only.",
    analyticsUnavailableTitle: "Template metrics are temporarily unavailable",
    analyticsUnavailableDescription:
      "The catalog is still available, but views, generations, and error metrics may be incomplete.",
    archiveTabsLabel: "Archive filter",
    allTemplates: "All templates",
    archivedTemplates: "Archive",
    searchLabel: "Search templates",
    searchPlaceholder: "Search by title, description, tags...",
    allCategories: "All categories",
    accessLabel: "Access",
    qaOnlyLabel: "QA only",
    allAccess: "All",
    allStatuses: "All statuses",
    sortLabel: "Sort",
    sortNewest: "Newest first",
    sortNewestDescription: "Most recent templates first",
    sortTitle: "By title",
    sortTitleDescription: "Alphabetical order",
    sortTokens: "By PawSpark",
    sortTokensDescription: "By PawSpark cost",
    viewToggleLabel: "View mode",
    cardsView: "Cards",
    listView: "List",
    testAction: "Test",
    tokensShort: "PawSpark",
    updatedLabel: "Updated",
    updatedShort: "Updated",
    previousPageLabel: "Previous templates page",
    nextPageLabel: "Next templates page",
    retry: "Retry",
    cancel: "Cancel",
    tableTemplate: "Template",
    tableType: "Type",
    tableViews: "Views",
    tableStarts: "Starts",
    tableConversion: "Conversion",
    tableSuccess: "Success",
    tableAverageCost: "Average cost",
    tokenUnit: "tok.",
    metricCost: "Template cost",
    metricViews: "Views",
    metricGenerations: "Generations",
    metricErrors: "Errors",
    pageSummary: (currentPage: number, shownStart: number, shownEnd: number, totalCount: number) =>
      `Page ${currentPage}: showing ${shownStart}-${shownEnd} of ${totalCount}`,
    archiveConfirmDescription: (templateLabel: string) =>
      `${templateLabel}: the template will be hidden from the active catalog.`,
  },
} as const;

type TemplatesCatalogLocaleText = (typeof templatesCatalogLocaleText)["en"];

export type TemplatesCatalogViewText = Omit<
  TemplatesCatalogLocaleText,
  | "videoTitle"
  | "imageTitle"
  | "videoDescription"
  | "imageDescription"
  | "createVideoTemplate"
  | "createImageTemplate"
> & {
  title: string;
  description: string;
  createTemplate: string;
};

export function getTemplatesCatalogViewText(
  locale: Locale,
  templateType: TemplateType
): TemplatesCatalogViewText {
  const localeText = templatesCatalogLocaleText[locale] as TemplatesCatalogLocaleText;
  const isVideoTemplate = templateType === "Video";

  return {
    ...localeText,
    title: isVideoTemplate ? localeText.videoTitle : localeText.imageTitle,
    description: isVideoTemplate ? localeText.videoDescription : localeText.imageDescription,
    createTemplate: isVideoTemplate
      ? localeText.createVideoTemplate
      : localeText.createImageTemplate,
  };
}

export function getTemplatesCatalogIntlLocale(locale: Locale): string {
  return templatesCatalogLocaleText[locale].intlLocale;
}
