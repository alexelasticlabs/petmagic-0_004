import type { Locale } from "@/lib/i18n";

const templatesCategoryDiagnosticsText = {
  ru: {
    title: "Целостность каталога",
    description:
      "Ручная проверка находит активные шаблоны без категории, со ссылкой на архивную категорию или без записи в реестре.",
    run: "Запустить проверку",
    retry: "Повторить проверку",
    running: "Проверяем каталог…",
    notRunTitle: "Проверка ещё не запускалась",
    notRunDescription:
      "Запустите её перед публикацией каталога или после массового изменения категорий.",
    healthyTitle: "Каталог согласован",
    healthyDescription: "Все активные шаблоны используют доступные категории.",
    errorTitle: "Не удалось проверить каталог",
    errorDescription:
      "Категории продолжают работать. Повторите диагностику, когда соединение восстановится.",
    staleTitle: "Результат мог устареть",
    staleDescription:
      "После последней проверки категории изменились. Запустите диагностику повторно.",
    issuesTitle: "Найдены несоответствия",
    issuesDescription: "Откройте шаблон, исправьте категорию и затем повторите проверку.",
    activeTemplates: "Активных шаблонов",
    issues: "Несоответствий",
    affected: "Затронуто",
    generatedAt: "Проверено",
    searchLabel: "Поиск по результатам",
    searchPlaceholder: "Шаблон или категория",
    issueFilterLabel: "Тип проблемы",
    allIssues: "Все проблемы",
    emptyCategory: "Категория не указана",
    archivedCategory: "Категория в архиве",
    missingCategory: "Категория отсутствует",
    unknownIssue: "Неизвестное несоответствие",
    emptyCategoryHint: "Укажите доступную категорию в редакторе шаблона.",
    archivedCategoryHint: "Выберите активную категорию или верните текущую из архива.",
    missingCategoryHint: "Создайте категорию в реестре или выберите существующую.",
    unknownIssueHint: "Проверьте категорию шаблона в редакторе.",
    issueColumn: "Проблема",
    templateColumn: "Шаблон",
    categoryColumn: "Категория",
    typeColumn: "Тип",
    updatedColumn: "Обновлён",
    actionColumn: "Действие",
    emptyValue: "Не указана",
    openEditor: "Открыть редактор",
    filteredEmpty: "По выбранным условиям несоответствий нет.",
    resultCount: (visible: number, total: number) => `Показано ${visible} из ${total}`,
  },
  en: {
    title: "Catalog integrity",
    description:
      "A manual check finds active templates with an empty category, an archived category, or no registry entry.",
    run: "Run check",
    retry: "Run again",
    running: "Checking catalog…",
    notRunTitle: "The check has not been run",
    notRunDescription: "Run it before publishing the catalog or after bulk category changes.",
    healthyTitle: "Catalog is consistent",
    healthyDescription: "Every active template uses an available category.",
    errorTitle: "Catalog check failed",
    errorDescription:
      "Category management is still available. Retry diagnostics when the connection recovers.",
    staleTitle: "Result may be stale",
    staleDescription: "Categories changed after the last check. Run diagnostics again.",
    issuesTitle: "Integrity issues found",
    issuesDescription: "Open a template, fix its category, and then run the check again.",
    activeTemplates: "Active templates",
    issues: "Issues",
    affected: "Affected",
    generatedAt: "Checked",
    searchLabel: "Search results",
    searchPlaceholder: "Template or category",
    issueFilterLabel: "Issue type",
    allIssues: "All issues",
    emptyCategory: "Category is empty",
    archivedCategory: "Category is archived",
    missingCategory: "Category is missing",
    unknownIssue: "Unknown integrity issue",
    emptyCategoryHint: "Choose an available category in the template editor.",
    archivedCategoryHint: "Choose an active category or restore the current category.",
    missingCategoryHint: "Create the registry category or choose an existing one.",
    unknownIssueHint: "Review the template category in the editor.",
    issueColumn: "Issue",
    templateColumn: "Template",
    categoryColumn: "Category",
    typeColumn: "Type",
    updatedColumn: "Updated",
    actionColumn: "Action",
    emptyValue: "Not set",
    openEditor: "Open editor",
    filteredEmpty: "No issues match the selected filters.",
    resultCount: (visible: number, total: number) => `Showing ${visible} of ${total}`,
  },
} as const;

export type TemplatesCategoryDiagnosticsText = (typeof templatesCategoryDiagnosticsText)["en"];

export function getTemplatesCategoryDiagnosticsText(
  locale: Locale
): TemplatesCategoryDiagnosticsText {
  return templatesCategoryDiagnosticsText[locale] as TemplatesCategoryDiagnosticsText;
}
