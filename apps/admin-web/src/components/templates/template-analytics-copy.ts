import { type Locale } from "@/lib/i18n";

export function getTemplateAnalyticsCopy(locale: Locale) {
  const isRu = locale === "ru";

  return {
    pageTitle: isRu ? "Аналитика" : "Analytics",
    backToCatalog: isRu ? "К каталогу" : "Back to catalog",
    openEditor: isRu ? "Открыть редактор" : "Open editor",
    loading: isRu ? "Загрузка аналитики шаблона..." : "Loading template analytics...",
    loadError: isRu
      ? "Не удалось загрузить аналитику шаблона."
      : "Failed to load template analytics.",
    rangeLabel: isRu ? "Период аналитики" : "Analytics period",
    range7: isRu ? "7 дней" : "7 days",
    range30: isRu ? "30 дней" : "30 days",
    range90: isRu ? "90 дней" : "90 days",
    rangeAll: isRu ? "Всё время" : "All time",
    comparePeriod: isRu ? "Сравнить период" : "Compare period",
    exportAnalytics: isRu ? "Экспорт JSON" : "Export JSON",
    compareNoBase: isRu ? "нет базы сравнения" : "no comparison base",
    templateOverviewTitle: isRu ? "Карточка шаблона" : "Template card",
    templateIdLabel: "ID",
    categoryLabel: isRu ? "Категория" : "Category",
    priceLabel: isRu ? "Доступ" : "Access",
    tokenCostLabel: isRu ? "Цена запуска" : "Run price",
    estimatedTemplateCostLabel: isRu ? "Себестоимость, $" : "Provider cost, $",
    createdLabel: isRu ? "Создан" : "Created",
    updatedLabel: isRu ? "Обновлён" : "Updated",
    totalRuns: isRu ? "Всего запусков" : "Total runs",
    successRate: isRu ? "Успешность" : "Success rate",
    completedRuns: isRu ? "Успешные" : "Completed",
    failedRuns: isRu ? "Ошибки" : "Failed",
    totalTokenCost: isRu ? "Всего PawSpark" : "Total PawSpark cost",
    averageTokenCost: isRu ? "Средняя стоимость" : "Average PawSpark cost",
    views: isRu ? "Просмотры" : "Views",
    viewsHint: isRu
      ? "События view из публичного template endpoint."
      : "View events from the public template endpoint.",
    generationStarts: isRu ? "Запуски генерации" : "Generation starts",
    generationStartsHint: isRu
      ? "Созданные задания генерации за выбранный период."
      : "Generation jobs created in the selected period.",
    successfulGenerations: isRu ? "Успешные генерации" : "Successful generations",
    successfulGenerationsHint: isRu
      ? "Задания, завершённые готовым видео."
      : "Jobs completed with an output video.",
    generationConversion: isRu ? "Конверсия в результат" : "Result conversion",
    generationConversionHint: isRu
      ? "Доля успешных jobs среди запусков."
      : "Completed jobs as a share of started jobs.",
    tokenSpend: isRu ? "Потрачено PawSpark" : "PawSpark spend",
    tokenSpendHint: isRu
      ? "Суммарная стоимость запусков в PawSpark."
      : "Total PawSpark cost of runs.",
    complaints: isRu ? "Жалобы" : "Complaints",
    complaintsHint: isRu
      ? "События complaint из публичного analytics endpoint."
      : "Complaint events from the public analytics endpoint.",
    feedbackTitle: isRu ? "Жалобы и фидбек" : "Complaints and feedback",
    feedbackHint: isRu
      ? "Последние обращения пользователей по шаблону: complaint и feedback события с текстом и метаданными."
      : "Latest user complaints and feedback for this template with message text and event metadata.",
    feedbackFilterLabel: isRu ? "Фильтр фидбека" : "Feedback filter",
    feedbackFilterAll: isRu ? "Все" : "All",
    feedbackFilterComplaint: isRu ? "Жалобы" : "Complaints",
    feedbackFilterFeedback: isRu ? "Фидбек" : "Feedback",
    feedbackSearchLabel: isRu ? "Поиск по тексту фидбека" : "Search feedback text",
    feedbackSearchPlaceholder: isRu ? "Поиск по тексту сообщения" : "Search message text",
    feedbackLoading: isRu ? "Загрузка обращений..." : "Loading feedback...",
    feedbackEmpty: isRu
      ? "Пока нет пользовательских жалоб или фидбека по этому шаблону."
      : "There is no user complaint or feedback for this template yet.",
    feedbackFilteredEmpty: isRu
      ? "По текущему фильтру и поиску ничего не найдено."
      : "No items matched the current filter and search.",
    feedbackLoadError: isRu
      ? "Не удалось загрузить жалобы и фидбек."
      : "Failed to load complaints and feedback.",
    feedbackMessageMissing: isRu ? "Без текста сообщения." : "No message text provided.",
    feedbackTypeComplaint: isRu ? "Жалоба" : "Complaint",
    feedbackTypeFeedback: isRu ? "Фидбек" : "Feedback",
    feedbackSourceLabel: isRu ? "Источник" : "Source",
    feedbackDeviceLabel: isRu ? "Устройство" : "Device",
    feedbackCountryLabel: isRu ? "Страна" : "Country",
    activeQueue: isRu ? "Активная очередь" : "Active queue",
    averageGenerationTime: isRu ? "Среднее время" : "Average generation time",
    lastRun: isRu ? "Последний запуск" : "Last run",
    lastCompleted: isRu ? "Последний успех" : "Last completed",
    snapshotTitle: isRu ? "Сводка по шаблону" : "Template snapshot",
    snapshotHint: isRu
      ? "Этот блок собирается из существующей admin statistics модели и служит опорной сводкой для dashboard выше."
      : "This block is built from the existing admin statistics model and acts as the anchor summary for the dashboard above.",
    trendTitle: isRu ? "Динамика запусков" : "Run trend",
    trendHint: isRu
      ? "Группировка generation jobs по дням создания шаблонных запусков."
      : "Generation jobs grouped by creation day.",
    trendEmpty: isRu
      ? "Для этого шаблона ещё нет исторических точек тренда."
      : "There are no trend points for this template yet.",
    chartRuns: isRu ? "Запуски" : "Runs",
    chartCompleted: isRu ? "Успешные" : "Completed",
    chartFailed: isRu ? "Ошибки" : "Failed",
    chartTokens: isRu ? "PawSpark" : "PawSpark",
    chartDuration: isRu ? "Время" : "Duration",
    statusBreakdownTitle: isRu ? "Состояние пайплайна" : "Pipeline health",
    statusBreakdownHint: isRu
      ? "Распределение текущих и завершённых состояний генерации."
      : "Distribution of current and completed generation pipeline states.",
    runsInQueue: isRu ? "В очереди" : "Queued",
    processingNow: isRu ? "В обработке" : "Processing",
    sourcesTitle: isRu ? "Источники просмотров" : "View sources",
    sourcesHint: isRu
      ? "Реальные source breakdown из template view events."
      : "Real source breakdown from template view events.",
    instrumentationPending: isRu
      ? "Нужна запись событий в публичном приложении/API, чтобы показывать эти метрики без догадок."
      : "Public app/API instrumentation is required to show this without guessing.",
    retentionTitle: isRu ? "Воронка генерации" : "Generation funnel",
    retentionHint: isRu
      ? "Реальная operational воронка по generation jobs."
      : "Real operational funnel from generation jobs.",
    funnelStarted: isRu ? "Начали генерацию" : "Started generation",
    funnelCompleted: isRu ? "Дождались результата" : "Completed result",
    funnelFailed: isRu ? "Получили ошибку" : "Failed",
    funnelActive: isRu ? "Ещё в работе" : "Still active",
    geographyTitle: isRu ? "География пользователей" : "User geography",
    geographyHint: isRu
      ? "Реальная география из событий public traffic, если страна была записана."
      : "Real geography from public traffic events when country was captured.",
    devicesTitle: isRu ? "Устройства" : "Devices",
    devicesHint: isRu
      ? "Реальное распределение устройств из записанных analytics events."
      : "Real device distribution from recorded analytics events.",
    recentRunsTitle: isRu ? "Последние генерации" : "Recent generations",
    recentRunsHint: isRu
      ? "Последние задания по этому шаблону с минимальным operational срезом."
      : "Latest jobs for this template with a compact operational snapshot.",
    recentRunsAllHint: isRu
      ? "Все доступные генерации по этому шаблону за весь период, который хранится в системе."
      : "All available generations for this template across the full retained history.",
    recentRunsLatest: isRu ? "Последние" : "Latest",
    recentRunsAll: isRu ? "Все генерации" : "All generations",
    recentRunsFailed: isRu ? "Ошибочные" : "Failed only",
    recentRunsLoading: isRu ? "Загрузка..." : "Loading...",
    recentRunsExpandError: isRu
      ? "Не удалось загрузить полный список генераций."
      : "Failed to load the full generation history.",
    recentRunsEmpty: isRu
      ? "У шаблона пока нет недавних генераций."
      : "This template has no recent generations yet.",
    failedRunsHint: isRu
      ? "Все завершившиеся с ошибкой генерации по шаблону с кодом и текстом причины."
      : "All failed generations for this template with failure code and reason text.",
    failedRunsEmpty: isRu
      ? "По этому шаблону пока нет ошибочных генераций."
      : "There are no failed generations for this template yet.",
    generationIdHeader: isRu ? "ID генерации" : "Generation ID",
    userHeader: isRu ? "Пользователь" : "User",
    recentCreated: isRu ? "Создан" : "Created",
    recentStatus: isRu ? "Статус" : "Status",
    recentTokens: isRu ? "PawSpark" : "PawSpark",
    recentDuration: isRu ? "Время" : "Duration",
    recentModels: isRu ? "Модели" : "Models",
    failureCodeHeader: isRu ? "Код ошибки" : "Failure code",
    failureReasonHeader: isRu ? "Причина" : "Reason",
    recentOutput: isRu ? "Выход" : "Output",
    openOutput: isRu ? "Открыть" : "Open",
    noOutput: isRu ? "Нет" : "None",
    failureBreakdownTitle: isRu ? "Breakdown ошибок" : "Failure breakdown",
    failureBreakdownHint: isRu
      ? "Сводка по failure codes из завершившихся с ошибкой generation jobs."
      : "Summary of failure codes from failed generation jobs.",
    failuresEmpty: isRu
      ? "Пока нет зарегистрированных ошибок по этому шаблону."
      : "There are no recorded failures for this template yet.",
    lastFailure: isRu ? "Последняя" : "Last",
    unknownFailure: isRu ? "Неизвестная ошибка" : "Unknown failure",
    preprocessingModel: isRu ? "Image model" : "Image model",
    motionModel: isRu ? "Motion model" : "Motion model",
    noData: isRu
      ? "У шаблона пока нет запусков. После первых генераций здесь появятся полноценные метрики."
      : "This template has no runs yet. Full metrics will appear here after the first generations.",
  };
}
