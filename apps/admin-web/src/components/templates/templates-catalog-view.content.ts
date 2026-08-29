import { type TemplateType } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

const templatesCatalogLocaleText = {
  ru: {
    intlLocale: "ru-RU",
    allTitle: "Управление шаблонами",
    videoTitle: "Видео шаблоны",
    imageTitle: "Шаблоны изображений",
    allDescription:
      "Каталог, публикация и качество image/video шаблонов в одном рабочем пространстве.",
    videoDescription: "Каталог видео-шаблонов, статусы, категории и параметры доступа.",
    imageDescription: "Каталог шаблонов изображений, статусы, категории и параметры доступа.",
    createVideoTemplate: "Создать видео шаблон",
    createImageTemplate: "Создать шаблон изображения",
    createTemplate: "Создать шаблон",
    chooseTemplateType: "Выберите тип нового шаблона",
    manageCategories: "Управление категориями",
    typesLabel: "Тип шаблонов",
    allTypes: "Все",
    videoTypes: "Видео",
    imageTypes: "Изображения",
    totalMetric: "Всего",
    activeMetric: "Активны",
    draftsMetric: "Черновики",
    missingPreviewMetric: "Без превью",
    previewUnavailable: "Не удалось показать превью",
    previewUnavailableDescription: "Проверьте файл в редакторе шаблона.",
    qaOnlyMetric: "Только QA",
    filtersLabel: "Фильтры каталога",
    showFilters: "Показать фильтры",
    hideFilters: "Скрыть фильтры",
    resetFilters: "Сбросить",
    activeFilters: (count: number) => `Активных фильтров: ${count}`,
    visibilityLabel: "Видимость",
    allVisibility: "Любая",
    publicVisibility: "Публичные",
    qaVisibility: "Только QA",
    readinessLabel: "Готовность",
    allReadiness: "Любая",
    readyReadiness: "С превью",
    missingPreviewReadiness: "Без превью",
    publicationControlTitle: "Контроль публикации",
    publicationControlDescription: "Быстрый переход к шаблонам, требующим внимания.",
    quickLinksTitle: "Быстрые переходы",
    analyticsHubAction: "Аналитика шаблонов",
    dailyFeaturedAction: "Шаблон дня",
    categoriesAction: "Категории",
    filteredEmptyTitle: "По этим условиям шаблонов нет",
    filteredEmptyDescription: "Сбросьте фильтры или измените поисковый запрос.",
    catalogEmptyTitle: "Каталог пока пуст",
    catalogEmptyDescription: "Создайте первый шаблон, чтобы подготовить его к публикации.",
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
    tableAverageCost: "Стоимость шаблона",
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
    allTitle: "Template management",
    videoTitle: "Video Templates",
    imageTitle: "Image Templates",
    allDescription:
      "Catalog, publishing, and image/video template quality in one operational workspace.",
    videoDescription: "Motion template catalog, statuses, categories, and access settings.",
    imageDescription: "Image template catalog, statuses, categories, and access settings.",
    createVideoTemplate: "Create video template",
    createImageTemplate: "Create image template",
    createTemplate: "Create template",
    chooseTemplateType: "Choose the new template type",
    manageCategories: "Manage categories",
    typesLabel: "Template type",
    allTypes: "All",
    videoTypes: "Video",
    imageTypes: "Images",
    totalMetric: "Total",
    activeMetric: "Active",
    draftsMetric: "Drafts",
    missingPreviewMetric: "Missing preview",
    previewUnavailable: "Preview is unavailable",
    previewUnavailableDescription: "Check the file in the template editor.",
    qaOnlyMetric: "QA only",
    filtersLabel: "Catalog filters",
    showFilters: "Show filters",
    hideFilters: "Hide filters",
    resetFilters: "Reset",
    activeFilters: (count: number) => `Active filters: ${count}`,
    visibilityLabel: "Visibility",
    allVisibility: "Any",
    publicVisibility: "Public",
    qaVisibility: "QA only",
    readinessLabel: "Readiness",
    allReadiness: "Any",
    readyReadiness: "Has preview",
    missingPreviewReadiness: "Missing preview",
    publicationControlTitle: "Publishing control",
    publicationControlDescription: "Open templates that need operator attention.",
    quickLinksTitle: "Quick links",
    analyticsHubAction: "Template analytics",
    dailyFeaturedAction: "Template of the day",
    categoriesAction: "Categories",
    filteredEmptyTitle: "No templates match these filters",
    filteredEmptyDescription: "Reset the filters or change the search query.",
    catalogEmptyTitle: "The catalog is empty",
    catalogEmptyDescription: "Create the first template and prepare it for publishing.",
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
    tableAverageCost: "Template cost",
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
  | "allTitle"
  | "videoDescription"
  | "imageDescription"
  | "allDescription"
  | "createVideoTemplate"
  | "createImageTemplate"
  | "createTemplate"
> & {
  title: string;
  description: string;
  createVideoTemplate: string;
  createImageTemplate: string;
  createTemplate: string;
};

export function getTemplatesCatalogViewText(
  locale: Locale,
  templateType?: TemplateType
): TemplatesCatalogViewText {
  const localeText = templatesCatalogLocaleText[locale] as TemplatesCatalogLocaleText;
  if (!templateType) {
    return {
      ...localeText,
      title: localeText.allTitle,
      description: localeText.allDescription,
      createTemplate: localeText.createTemplate,
    };
  }

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
