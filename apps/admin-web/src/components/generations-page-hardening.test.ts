import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readGenerationsPageLibrarySource } from "./generations-page.test-source";

const generationsContentPath = fileURLToPath(
  new URL("./generations-page.content.ts", import.meta.url)
);
const generationsStylesPath = fileURLToPath(
  new URL("./generations-page.module.css", import.meta.url)
);

describe("generations page hardening", () => {
  it("sanitizes generation display strings instead of rendering provider or failure values raw", () => {
    const source = readGenerationsPageLibrarySource();

    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("function formatSafeText");
    expect(source).toContain(
      "const failureText = formatSafeText(item.failureCode, text.noFailure)"
    );
    expect(source).toContain("const providerText = formatSafeText(item.provider)");
    expect(source).toContain('const modelText = formatSafeText(item.model, "")');
    expect(source).toContain("const templateTitle = formatSafeText(item.templateTitle)");
    expect(source).toContain("const generationIdText = formatShortId(item.generationId)");
    expect(source).toContain("const userIdText = formatShortId(item.userId)");
    expect(source).not.toContain("{item.provider}</AdminBadge>");
    expect(source).not.toContain("{item.model}</div>");
    expect(source).not.toContain("{item.failureCode}");
    expect(source).not.toContain("title={item.generationId}");
    expect(source).not.toContain("title={item.userId}");
  });

  it("localizes generation statuses and keeps unsupported retry/cancel actions out of the UI", () => {
    const source = readGenerationsPageLibrarySource();
    const contentSource = readFileSync(generationsContentPath, "utf8");

    expect(source).toContain(
      'import { getGenerationsPageText } from "./generations-page.content";'
    );
    expect(source).toContain("getGenerationsPageIntlLocale(");
    expect(source).toContain("type GenerationsPageText");
    expect(source).toContain("const text = getGenerationsPageText(locale);");
    expect(source).toContain("getGenerationsPageIntlLocale(locale)");
    expect(source).toContain("formatStatus(item.status, text)");
    expect(source).toContain("formatTemplateType(item.templateType, text)");
    expect(source).toContain("formatInputSourceType(item.inputSourceType, text)");
    expect(source).toContain("formatMappedLabel(text.feedbackTypeOptions, feedback.type)");
    expect(source).toContain("formatMappedLabel(text.feedbackStatusOptions, feedback.status)");
    expect(source).toContain("formatMappedLabel(text.feedbackPriorityOptions, feedback.priority)");
    expect(source).not.toContain("function getCopy(locale: Locale)");
    expect(source).not.toContain('const isRu = locale === "ru";');
    expect(source).not.toContain('locale === "ru" ? "ru-RU" : "en-US"');
    expect(source).not.toContain("unsupportedActions");
    expect(source).not.toContain("Retry/cancel не показаны");
    expect(source).not.toContain("Retry/cancel are hidden");
    expect(source).not.toContain("backend does not expose");
    expect(source).not.toContain("metaItems={[");

    expect(contentSource).toContain(
      "const generationsPageText: Record<Locale, GenerationsPageText> = {"
    );
    expect(contentSource).toContain(
      "export function getGenerationsPageIntlLocale(locale: Locale): string"
    );
    expect(contentSource).toContain('eyebrow: "Операции"');
    expect(contentSource).toContain('description:\n      "Операционный список заданий генерации');
    expect(contentSource).toContain('adminOnly: "Только Admin"');
    expect(contentSource).toContain('total: "Всего заданий"');
    expect(contentSource).toContain('allJobsScope: "Все задания"');
    expect(contentSource).toContain(
      'emptyDescription: "Измените фильтры или дождитесь новых заданий генерации."'
    );
    expect(contentSource).toContain('job: "Задание"');
    expect(contentSource).toContain('Pending: "Ожидает"');
    expect(contentSource).toContain('Running: "В работе"');
    expect(contentSource).toContain('Failed: "Ошибка"');
    expect(contentSource).toContain('Cancelled: "Отменена"');
    expect(contentSource).toContain('before: "До"');
    expect(contentSource).toContain('after: "После"');
    expect(contentSource).toContain('compareState: "Сравнение"');
    expect(contentSource).toContain('inputAsset: "Входной asset"');
    expect(contentSource).toContain('resultAsset: "Результат asset"');
    expect(contentSource).toContain('pet: "Питомец"');
    expect(contentSource).toContain('petPhoto: "Фото питомца"');
    expect(contentSource).toContain('debugTitle: "Отладка"');
    expect(contentSource).toContain('grantClean: "Выдать clean"');
    expect(contentSource).toContain('feedbackTab: "Отзывы"');
  });

  it("keeps generation search server-backed and disables repeated retry clicks", () => {
    const source = readGenerationsPageLibrarySource();

    expect(source).toContain("const debouncedProvider = useDebouncedValue(provider, 350)");
    expect(source).toContain("const debouncedUser = useDebouncedValue(user, 350)");
    expect(source).toContain("const debouncedSearch = useDebouncedValue(search, 350)");
    expect(source).toContain("GENERATION_PROVIDER_FILTER_MAX_LENGTH,");
    expect(source).toContain("GENERATION_SEARCH_FILTER_MAX_LENGTH,");
    expect(source).toContain("GENERATION_USER_FILTER_MAX_LENGTH,");
    expect(source).toContain("useAuthSession,");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain(
      'const canViewGenerations = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(source).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');
    expect(source).toContain("if (!canViewGenerations) {");
    expect(source).toContain('<AdminStateCard tone="info" title={text.loadingTitle} />');
    expect(source).toContain(
      "setSearch(event.target.value.slice(0, GENERATION_SEARCH_FILTER_MAX_LENGTH));"
    );
    expect(source).toContain(
      "setProvider(event.target.value.slice(0, GENERATION_PROVIDER_FILTER_MAX_LENGTH));"
    );
    expect(source).toContain(
      "setUser(event.target.value.slice(0, GENERATION_USER_FILTER_MAX_LENGTH));"
    );
    expect(source).toContain("maxLength={GENERATION_SEARCH_FILTER_MAX_LENGTH}");
    expect(source).toContain("maxLength={GENERATION_PROVIDER_FILTER_MAX_LENGTH}");
    expect(source).toContain("maxLength={GENERATION_USER_FILTER_MAX_LENGTH}");
    expect(source).toContain("normalizeAdminTemplateGenerationsQuery({");
    expect(source).toContain("fetchAdminTemplateGenerations(query, signal)");
    expect(source).toContain("enabled: canViewGenerations");
    expect(source).toContain("placeholderData: keepPreviousData");
    expect(source).toContain(
      "const isGenerationsRefreshing = generationsQuery.isFetching && generationsQuery.isPlaceholderData"
    );
    expect(source).toContain("const areGenerationFiltersLocked = generationsQuery.isFetching;");
    expect(source).toContain("generationsQuery.isLoading || isGenerationsRefreshing");
    expect(source).toContain("disabled={!canViewGenerations || generationsQuery.isFetching}");
    expect(source.match(/disabled=\{areGenerationFiltersLocked\}/g) ?? []).toHaveLength(4);
    expect(source).toContain("function requestGenerationsRetry()");
    expect(source).toContain(
      "if (!canViewGenerations || generationsQuery.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("onClick={requestGenerationsRetry}");
    expect(source).not.toContain("onClick={() => {\n                if (!canViewGenerations)");
    expect(source).not.toContain(".filter((item) => item.generationId");
    expect(source).not.toContain(".filter((item) => item.provider");
    expect(source).not.toContain(".filter((item) => item.userId");
    expect(source).not.toContain("setSearch(event.target.value);");
    expect(source).not.toContain("setProvider(event.target.value);");
    expect(source).not.toContain("setUser(event.target.value);");
  });

  it("keeps generation pagination accessible and usable on narrow screens", () => {
    const source = readGenerationsPageLibrarySource();
    const contentSource = readFileSync(generationsContentPath, "utf8");
    const stylesSource = readFileSync(generationsStylesPath, "utf8");

    expect(contentSource).toContain('previousPageLabel: "Предыдущая страница генераций"');
    expect(contentSource).toContain('nextPageLabel: "Следующая страница генераций"');
    expect(source).toContain('import { CaretDownIcon } from "@/components/admin/admin-icons";');
    expect(source).toContain("className={`${styles.button} ${styles.pagerButton}`}");
    expect(source).toContain("aria-label={text.previousPageLabel}");
    expect(source).toContain("aria-label={text.nextPageLabel}");
    expect(source).toContain("title={text.previousPageLabel}");
    expect(source).toContain("title={text.nextPageLabel}");
    expect(source).toContain(
      "<CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />"
    );
    expect(source).toContain(
      "<CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />"
    );
    expect(source).not.toContain("{text.previous}");
    expect(source).not.toContain("{text.next}");
    expect(source).toContain("disabled={pageIndex === 0 || generationsQuery.isFetching}");
    expect(source).toContain("disabled={!visiblePage?.hasMore || generationsQuery.isFetching}");
    expect(stylesSource).toContain(".pageInfo {\n    width: 100%;");
    expect(stylesSource).toContain(".pagerButton");
    expect(stylesSource).toContain(".pageIconPrevious");
    expect(stylesSource).toContain(".pageIconNext");
    expect(stylesSource).toContain(".pager .button:not(.pagerButton) {\n    width: 100%;");
    expect(stylesSource).toContain(".pagerButton {\n    width: auto;");
  });

  it("sources status KPI cards from backend aggregate metrics", () => {
    const source = readGenerationsPageLibrarySource();

    expect(source).toContain("fetchAdminTemplateGenerationMetrics(signal)");
    expect(source).toContain("adminQueryKeys.templateGenerationMetrics");
    expect(source).toContain("generationMetrics?.totalJobs");
    expect(source).toContain("generationMetrics?.pendingJobs");
    expect(source).toContain("generationMetrics?.runningJobs");
    expect(source).toContain("generationMetrics?.failedJobs");
    expect(source).toContain("generationMetrics?.retryingJobs");
    expect(source).toContain("generationMetrics?.cancelledJobs");
    expect(source).toContain("hint={text.allJobsScope}");
    expect(source).toContain('aria-busy={generationsQuery.isFetching ? "true" : undefined}');
    expect(source).not.toContain('currentPageScope: isRu ? "Текущая страница" : "Current page"');
    expect(source).not.toContain("items.filter((item) => item.status");
  });

  it("keeps generation metrics failures local without blocking the history table", () => {
    const source = readGenerationsPageLibrarySource();
    const stylesSource = readFileSync(generationsStylesPath, "utf8");

    expect(source).toContain("generationMetricsQuery.isError ? (");
    expect(source).toContain("text.metricsErrorTitle");
    expect(source).toContain("generationMetricsQuery.error");
    expect(source).toContain("function requestGenerationMetricsRetry()");
    expect(source).toContain(
      "if (!canViewGenerations || generationMetricsQuery.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("generationMetricsQuery.refetch().catch(() => undefined)");
    expect(source).toContain("disabled={!canViewGenerations || generationMetricsQuery.isFetching}");
    expect(source).toContain("onClick={requestGenerationMetricsRetry}");
    expect(source).toContain("className={styles.metricsWarning}");
    expect(stylesSource).toContain(".metricsWarning");
    expect(source).not.toContain(
      "generationMetricsQuery.isError ? (\n        <AdminStateCard\n          title={text.errorTitle}"
    );
  });

  it("uses theme tokens for generation status badge colors", () => {
    const source = readGenerationsPageLibrarySource();

    expect(source).toContain('return "var(--success)";');
    expect(source).toContain('return "var(--danger)";');
    expect(source).toContain('return "var(--neutral)";');
    expect(source).toContain('return "var(--magenta)";');
    expect(source).toContain('return "var(--info)";');
    expect(source).toContain('return "var(--warning)";');
    expect(source).not.toContain('return "#22c55e";');
    expect(source).not.toContain('return "#ef4444";');
    expect(source).not.toContain('return "#64748b";');
    expect(source).not.toContain('return "#a855f7";');
    expect(source).not.toContain('return "#3b82f6";');
    expect(source).not.toContain('return "#f59e0b";');
  });

  it("shows watermark unlock actor together with method, credits, and timestamp", () => {
    const source = readGenerationsPageLibrarySource();
    const contentSource = readFileSync(generationsContentPath, "utf8");

    expect(contentSource).toContain('watermarkUnlockedBy: "Разблокировал"');
    expect(contentSource).toContain('watermarkUnlockedBy: "Unlocked by"');
    expect(source).toContain("const watermarkUnlockedByText = item.watermarkUnlockedByUserId");
    expect(source).toContain("formatShortId(item.watermarkUnlockedByUserId)");
    expect(source).toContain("{text.watermarkUnlockedBy} {watermarkUnlockedByText}");
    expect(source).toContain("text.creditsLabel");
    expect(source).toContain("item.watermarkCreditsSpent");
    expect(source).toContain("item.watermarkUnlockedAtUtc");
  });

  it("guards clean watermark grants while a grant request or generation refresh is pending", () => {
    const source = readGenerationsPageLibrarySource();
    const contentSource = readFileSync(generationsContentPath, "utf8");

    expect(contentSource).toContain('grantCleanError: "Не удалось выдать clean download."');
    expect(source).toContain("const [grantCleanError, setGrantCleanError]");
    expect(source).toContain("setGrantCleanError(null);");
    expect(source).toContain(
      "setGrantCleanError(getAdminErrorMessage(error, text.grantCleanError));"
    );
    expect(source).toContain(
      '{grantCleanError ? <AdminStateCard tone="warning" title={grantCleanError} /> : null}'
    );
    expect(source).toContain("const grantingGenerationId = grantCleanMutation.variables ?? null;");
    expect(source).toContain(
      "const isGrantCleanLocked = grantCleanMutation.isPending || generationsQuery.isFetching;"
    );
    expect(source).toContain("function requestGrantClean(generationId: string)");
    expect(source).toContain(
      "if (!canViewGenerations || isGrantCleanLocked) {\n      return;\n    }"
    );
    expect(source).toContain("grantCleanMutation.mutate(generationId);");
    expect(source).toContain("grantCleanPending: boolean;");
    expect(source).toContain("disabled={grantCleanPending}");
    expect(source).toContain("grantCleanPending={isGrantCleanLocked}");
    expect(source).toContain("onGrantClean={requestGrantClean}");
    expect(source).toContain(
      'const detailsPanelId = `generation-details-${item.generationId.replace(/[^a-zA-Z0-9_-]/g, "-")}`;'
    );
    expect(source).toContain(
      "const toggleDetailsLabel = `${isExpanded ? text.hideDetails : text.showDetails}: ${generationIdText}`;"
    );
    expect(source).toContain("const grantCleanLabel = `${text.grantClean}: ${generationIdText}`;");
    expect(source).toContain("aria-expanded={isExpanded}");
    expect(source).toContain("aria-controls={detailsPanelId}");
    expect(source).toContain("aria-label={toggleDetailsLabel}");
    expect(source).toContain("title={toggleDetailsLabel}");
    expect(source).toContain("aria-label={grantCleanLabel}");
    expect(source).toContain("title={grantCleanLabel}");
    expect(source).toContain("<div className={styles.detailsPanel} id={detailsPanelId}>");
    expect(source).not.toContain(
      "onGrantClean={(generationId) => grantCleanMutation.mutate(generationId)}"
    );
  });

  it("keeps expanded generation feedback failures local and retryable", () => {
    const source = readGenerationsPageLibrarySource();
    const contentSource = readFileSync(generationsContentPath, "utf8");

    expect(contentSource).toContain(
      'feedbackError: "Не удалось загрузить отзывы по этой генерации"'
    );
    expect(source).toContain("feedbackQuery.isError ? (");
    expect(source).toContain("title={text.feedbackError}");
    expect(source).toContain(
      "description={getAdminErrorMessage(feedbackQuery.error, text.feedbackError)}"
    );
    expect(source).toContain("function requestFeedbackRetry()");
    expect(source).toContain("if (feedbackQuery.isFetching) {\n      return;\n    }");
    expect(source).toContain("disabled={feedbackQuery.isFetching}");
    expect(source).toContain("onClick={requestFeedbackRetry}");
    expect(source).toContain("void feedbackQuery.refetch().catch(() => undefined);");
    expect(source.indexOf("feedbackQuery.isError ? (")).toBeLessThan(
      source.indexOf("feedbackItems.length === 0")
    );
  });

  it("renders expanded generation previews through the secure media component", () => {
    const source = readGenerationsPageLibrarySource();

    expect(source).toContain(
      'import { TemplateSecureMedia } from "@/components/templates/template-secure-media";'
    );
    expect(source).not.toContain('import Image from "next/image";');
    expect(source).toContain("url={item.inputPreviewUrl}");
    expect(source).toContain('surface: "generations-before-preview"');
    expect(source).toContain("url={item.resultPreviewUrl}");
    expect(source).toContain('surface: "generations-after-preview"');
    expect(source).toContain("templateId: item.templateId");
    expect(source).not.toContain("src={item.inputPreviewUrl}");
    expect(source).not.toContain("src={item.resultPreviewUrl}");
  });

  it("keeps clean watermark grant refresh non-blocking after success", () => {
    const source = readGenerationsPageLibrarySource();

    expect(source).toContain(
      "await Promise.allSettled([\n        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),\n      ]);"
    );
    expect(source).not.toContain(
      "await queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) });"
    );
  });

  it("does not render stale placeholder rows while generation filters or pages refresh", () => {
    const source = readGenerationsPageLibrarySource();

    expect(source).toContain(
      "const visiblePage = generationsQuery.isPlaceholderData ? undefined : generationsQuery.data"
    );
    expect(source).toContain(
      "const visibleItems = useMemo(() => visiblePage?.items ?? [], [visiblePage])"
    );
    expect(source).toContain("const visibleTotalCount = visiblePage?.totalCount ?? 0");
    expect(source).toContain(
      "const visiblePageCount = Math.max(1, Math.ceil(visibleTotalCount / PAGE_SIZE))"
    );
    expect(source).toContain("visibleItems.length === 0");
    expect(source).toContain("visibleItems.map((item) =>");
    expect(source).toContain('{visibleTotalCount} {text.tableTotalLabel} /{" "}');
    expect(source).toContain("{text.page} {pageIndex + 1} {text.of} {visiblePageCount}");
    expect(source).toContain("const [expandedGeneration, setExpandedGeneration] = useState<{");
    expect(source).toContain("const queryKey = JSON.stringify(query);");
    expect(source).toContain(
      "expandedGeneration?.queryKey === queryKey ? expandedGeneration.generationId : null"
    );
    expect(source).toContain(
      "const visibleGenerationIds = useMemo(\n    () => new Set(visibleItems.map((item) => item.generationId)),"
    );
    expect(source).toContain(
      "if (!expandedGenerationId || visibleGenerationIds.has(expandedGenerationId)) {"
    );
    expect(source).toContain("queueMicrotask(() => setExpandedGeneration(null));");
    expect(source).toContain("function resetGenerationListContext(nextPageIndex = 0)");
    expect(source).toContain("setExpandedGeneration(null);");
    expect(source).toContain("setPageIndex(nextPageIndex);");
    expect(source).toContain("resetGenerationListContext();");
    expect(source).toContain("resetGenerationListContext(Math.max(0, pageIndex - 1))");
    expect(source).toContain("resetGenerationListContext(pageIndex + 1)");
    expect(source).toContain("setExpandedGeneration((current) =>");
    expect(source).toContain(
      "current?.queryKey === queryKey && current.generationId === generationId"
    );
    expect(source).not.toContain("setPageIndex((value) => Math.max(0, value - 1))");
    expect(source).not.toContain("setPageIndex((value) => value + 1)");
    expect(source).not.toContain("const items = page?.items ?? []");
    expect(source).not.toContain("items.length === 0");
    expect(source).not.toContain("items.map((item) =>");
    expect(source).not.toContain("const totalCount = page?.totalCount ?? 0");
  });

  it("keeps local generation controls accessible in locked and keyboard states", () => {
    const stylesSource = readFileSync(generationsStylesPath, "utf8");

    expect(stylesSource).toContain(
      ".input:focus-visible,\n.select:focus-visible,\n.button:focus-visible,\n.inlineAction:focus-visible"
    );
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain(".input:disabled,\n.select:disabled");
    expect(stylesSource).toContain("cursor: not-allowed;");
    expect(stylesSource).toContain("opacity: 0.62;");
    expect(stylesSource).not.toContain(".input:focus,\n.select:focus");
    expect(stylesSource).not.toContain("rgba(");
    expect(stylesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });
});
