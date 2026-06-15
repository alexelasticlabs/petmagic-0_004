import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const feedbackPagePath = fileURLToPath(new URL("./feedback-page.tsx", import.meta.url));
const feedbackStylesPath = fileURLToPath(new URL("./feedback-page.module.css", import.meta.url));

describe("feedback page hardening", () => {
  it("uses the shared admin session guard for Admin and Moderator feedback access", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain('import { useRouter } from "next/navigation";');
    expect(source).toContain(
      'import { ensureAdminSession } from "@/components/admin/admin-session";'
    );
    expect(source).toContain("const router = useRouter();");
    expect(source).toContain("ensureAdminSession(locale, router);");
    expect(source).toContain(
      'session?.user.roles.some((role) => role === "Admin" || role === "Moderator") ?? false'
    );
    expect(source).toContain("if (!canView) {");
    expect(source).toContain("<AdminStateCard title={text.loading} />");
    expect(source).not.toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');
  });

  it("debounces free-text filters before changing the backend query", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("ADMIN_FEEDBACK_FILTER_MAX_LENGTH,");
    expect(source).toContain("function useDebouncedValue(value: string, delayMs: number)");
    expect(source).toContain("const debouncedCategory = useDebouncedValue(category, 350);");
    expect(source).toContain("const debouncedPlatform = useDebouncedValue(platform, 350);");
    expect(source).toContain("const debouncedTemplateId = useDebouncedValue(templateId, 350);");
    expect(source).toContain("const debouncedUserId = useDebouncedValue(userId, 350);");
    expect(source).toContain("maxLength={ADMIN_FEEDBACK_FILTER_MAX_LENGTH}");
    expect(source).toContain("? event.target.value.slice(0, maxLength)");
    expect(source).toContain("category: debouncedCategory");
    expect(source).toContain("platform: debouncedPlatform");
    expect(source).toContain("templateId: debouncedTemplateId");
    expect(source).toContain("userId: debouncedUserId");
    expect(source).not.toContain("setCategory(value.slice");
    expect(source).not.toContain("setPlatform(event.target.value)");
  });

  it("treats the To date filter as the end of the selected day", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("function dateInputToUtcStart(value: string)");
    expect(source).toContain("function dateInputToUtcEnd(value: string)");
    expect(source).toContain("new Date(`${value}T23:59:59.999Z`).toISOString()");
    expect(source).toContain("fromUtc: dateInputToUtcStart(fromUtc)");
    expect(source).toContain("toUtc: dateInputToUtcEnd(toUtc)");
    expect(source).not.toContain("toUtc: toUtc ? new Date(toUtc).toISOString() : undefined");
  });

  it("guards manual retry and pagination while feedback data is fetching", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("const isFeedbackFetching = feedbackQuery.isFetching;");
    expect(source).toContain("const areFeedbackFiltersLocked = isFeedbackFetching;");
    expect(source).toContain("const isDetailsFetching = detailsQuery.isFetching;");
    expect(source).toContain(
      "const visiblePageData = feedbackQuery.isPlaceholderData ? undefined : pageData;"
    );
    expect(source).toContain("() => visiblePageData?.items ?? []");
    expect(source).toContain(
      "const isFeedbackRefreshing = feedbackQuery.isFetching && feedbackQuery.isPlaceholderData;"
    );
    expect(source).toContain("feedbackQuery.isLoading || isFeedbackRefreshing");
    expect(source).toContain("visibleFeedbackItems.map((item) => (");
    expect(source).not.toContain("pageData.items.map((item) => (");
    expect(source).toContain("disabled={isFeedbackFetching}");
    expect(source).toContain("function requestFeedbackRetry()");
    expect(source).toContain("if (isFeedbackFetching) {\n      return;\n    }");
    expect(source).toContain("void feedbackQuery.refetch().catch(() => undefined);");
    expect(source).toContain("onClick={requestFeedbackRetry}");
    expect(source).not.toContain(
      "onClick={() => {\n                  void feedbackQuery.refetch().catch(() => undefined);"
    );
    expect(source).toContain("disabled={page === 0 || isFeedbackFetching}");
    expect(source).toContain("disabled={!visiblePageData?.hasMore || isFeedbackFetching}");
    expect(source.match(/disabled=\{areFeedbackFiltersLocked\}/g) ?? []).toHaveLength(9);
    expect(source).toContain("disabled?: boolean;");
    expect(source).toContain("disabled = false");
    expect(source).toContain("disabled={disabled}");
    expect(source).toContain("function resetFeedbackSelection(nextPage = 0)");
    expect(source).toContain("setSelectedId(null);");
    expect(source).toContain("setPage(nextPage);");
    expect(source).toContain("function requestFeedbackPageChange(nextPage: number)");
    expect(source).toContain("if (nextPage < 0) {\n      return;\n    }");
    expect(source).toContain(
      "if (nextPage > page && !visiblePageData?.hasMore) {\n      return;\n    }"
    );
    expect(source).toContain("requestFeedbackPageChange(page - 1);");
    expect(source).toContain("requestFeedbackPageChange(page + 1);");
    expect(source).toContain('import { CaretDownIcon } from "@/components/admin/admin-icons";');
    expect(source).toContain("aria-label={text.previousPageLabel}");
    expect(source).toContain("aria-label={text.nextPageLabel}");
    expect(source).toContain("title={text.previousPageLabel}");
    expect(source).toContain("title={text.nextPageLabel}");
    expect(source).toContain(
      '<CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />'
    );
    expect(source).toContain(
      '<CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />'
    );
    expect(source).not.toContain("{text.previous}\n          </button>");
    expect(source).not.toContain("{text.next}\n          </button>");
  });

  it("clears selected feedback details when filters change", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source.match(/resetFeedbackSelection\(\);/g) ?? []).toHaveLength(9);
    expect(source).not.toContain("setStatus(value as typeof status);\n              setPage(0);");
    expect(source).not.toContain("setPriority(value as typeof priority);\n              setPage(0);");
    expect(source).not.toContain("setType(value as typeof type);\n              setPage(0);");
    expect(source).not.toContain("setCategory(value);\n              setPage(0);");
    expect(source).not.toContain("setPlatform(value);\n              setPage(0);");
    expect(source).not.toContain("setTemplateId(value);\n              setPage(0);");
    expect(source).not.toContain("setUserId(value);\n              setPage(0);");
    expect(source).not.toContain("setFromUtc(value);\n              setPage(0);");
    expect(source).not.toContain("setToUtc(value);\n              setPage(0);");
  });

  it("clears selected feedback details when refreshed results no longer contain it", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain(
      "const visibleFeedbackIds = useMemo(\n    () => new Set(visibleFeedbackItems.map((item) => item.id)),"
    );
    expect(source).toContain(
      "if (!visiblePageData || !selectedId || visibleFeedbackIds.has(selectedId)) {\n      return;\n    }"
    );
    expect(source).toContain("queueMicrotask(() => setSelectedId(null));");
    expect(source).toContain("}, [selectedId, visibleFeedbackIds, visiblePageData]);");
    expect(source).not.toContain("if (!pageData || !selectedId");
  });

  it("shows loading and retry states for selected feedback details", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("detailsLoading:");
    expect(source).toContain("detailsError:");
    expect(source).toContain("selectedId && detailsQuery.isLoading");
    expect(source).toContain("selectedId && detailsQuery.isError");
    expect(source).toContain(
      "description={getAdminErrorMessage(detailsQuery.error, text.detailsError)}"
    );
    expect(source).toContain("disabled={isDetailsFetching}");
    expect(source).toContain("function requestDetailsRetry()");
    expect(source).toContain("if (isDetailsFetching) {\n      return;\n    }");
    expect(source).toContain("void detailsQuery.refetch().catch(() => undefined);");
    expect(source).toContain("onClick={requestDetailsRetry}");
    expect(source).not.toContain(
      "onClick={() => {\n                void detailsQuery.refetch().catch(() => undefined);"
    );
  });

  it("shows mutation errors and prevents overlapping feedback detail actions", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH,");
    expect(source).toContain("saveError:");
    expect(source).toContain("refundError:");
    expect(source).toContain("updateMutation.isError");
    expect(source).toContain("refundMutation.isError");
    expect(source).toContain("maxLength={ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH}");
    expect(source).toContain(
      "setAdminNote(event.target.value.slice(0, ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH))"
    );
    expect(source).toContain("getAdminErrorMessage(updateMutation.error, text.saveError)");
    expect(source).toContain("getAdminErrorMessage(refundMutation.error, text.refundError)");
    expect(source).toContain("isDetailsFetching: boolean;");
    expect(source).toContain(
      "const isFeedbackActionLocked =\n    updateMutation.isPending || refundMutation.isPending || isDetailsFetching;"
    );
    expect(source).toContain("const isFeedbackDraftDirty =");
    expect(source).toContain('status !== ((details.status as FeedbackStatus) || "New")');
    expect(source).toContain('priority !== ((details.priority as FeedbackPriority) || "Low")');
    expect(source).toContain("adminNote !== (details.adminNote ?? \"\")");
    expect(source).toContain("const isSaveFeedbackDisabled = !isFeedbackDraftDirty || isFeedbackActionLocked;");
    expect(source).toContain(
      "const isRefundFeedbackDisabled = !details.canRefund || isFeedbackActionLocked;"
    );
    expect(source).toContain("const requestSaveFeedback = () => {");
    expect(source).toContain("if (isSaveFeedbackDisabled) {\n      return;\n    }");
    expect(source).toContain("const requestRefundFeedback = () => {");
    expect(source).toContain("if (isRefundFeedbackDisabled) {\n      return;\n    }");
    expect(source).toContain("disabled={isSaveFeedbackDisabled}");
    expect(source).toContain("onClick={requestSaveFeedback}");
    expect(source).toContain("disabled={isRefundFeedbackDisabled}");
    expect(source).toContain("onClick={requestRefundFeedback}");
    expect(source).toContain('aria-busy={isDetailsFetching ? "true" : undefined}');
    expect(source).toContain("disabled={isFeedbackActionLocked}");
    expect(source).toContain("isDetailsFetching={isDetailsFetching}");
    expect(source).not.toContain("onClick={() => updateMutation.mutate()}");
    expect(source).not.toContain("onClick={() => refundMutation.mutate()}");
  });

  it("keeps Russian feedback filters, actions, and detail labels localized", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain('templateId: isRu ? "ID шаблона" : "Template id"');
    expect(source).toContain('userId: isRu ? "ID пользователя" : "User id"');
    expect(source).toContain('from: isRu ? "С даты" : "From"');
    expect(source).toContain('to: isRu ? "По дату" : "To"');
    expect(source).toContain('refund: isRu ? "Вернуть кредиты" : "Refund credits"');
    expect(source).toContain('refunded: isRu ? "Кредиты возвращены" : "Refund issued"');
    expect(source).toContain('note: isRu ? "Заметка администратора" : "Admin note"');
    expect(source).toContain('input: isRu ? "Входные данные" : "Input"');
    expect(source).toContain('result: isRu ? "Результат" : "Result"');
    expect(source).toContain('planCredits: isRu ? "План / кредиты" : "Plan / credits"');
    expect(source).toContain('source: isRu ? "Источник" : "Source"');
    expect(source).toContain('app: isRu ? "Версия приложения" : "App"');
    expect(source).toContain('device: isRu ? "Устройство" : "Device"');
    expect(source).toContain('provider: isRu ? "Провайдер" : "Provider"');
    expect(source).toContain('errorCode: isRu ? "Код ошибки" : "Error"');
    expect(source).toContain('credits: isRu ? "кредитов" : "credits"');
    expect(source).toContain("label={text.planCredits}");
    expect(source).toContain("label={text.source}");
    expect(source).toContain("label={text.app}");
    expect(source).toContain("label={text.device}");
    expect(source).toContain("label={text.provider}");
    expect(source).toContain("label={text.errorCode}");
    expect(source).toContain("{text.credits}");
    expect(source).not.toContain('templateId: isRu ? "Template id" : "Template id"');
    expect(source).not.toContain('from: isRu ? "From" : "From"');
    expect(source).not.toContain('refund: isRu ? "Refund credits" : "Refund credits"');
    expect(source).not.toContain('note: isRu ? "Admin note" : "Admin note"');
    expect(source).not.toContain('input: isRu ? "Input" : "Input"');
    expect(source).not.toContain('label="Plan / credits"');
    expect(source).not.toContain('label="Provider"');
    expect(source).not.toContain('label="Error"');
    expect(source).not.toContain(" credits\n                </strong>");
  });

  it("keeps feedback detail form drafts synced with refreshed backend details", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("key={[\n            detailsQuery.data.id,");
    expect(source).toContain("detailsQuery.data.status,");
    expect(source).toContain("detailsQuery.data.priority,");
    expect(source).toContain("detailsQuery.data.reviewedAtUtc ?? \"\",");
    expect(source).toContain("detailsQuery.data.adminNote ?? \"\",");
    expect(source).toContain("].join(\":\")}");
    expect(source).not.toContain("setState synchronously within an effect");
    expect(source).toContain(
      "const [status, setStatus] = useState((details.status as FeedbackStatus) || \"New\");"
    );
    expect(source).toContain(
      "const [priority, setPriority] = useState((details.priority as FeedbackPriority) || \"Low\");"
    );
    expect(source).toContain("const [adminNote, setAdminNote] = useState(details.adminNote ?? \"\");");
  });

  it("keeps feedback action cache refreshes partial after successful backend mutations", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source.match(/await Promise\.allSettled\(\[/g) ?? []).toHaveLength(2);
    expect(source.match(/void Promise\.allSettled\(\[/g) ?? []).toHaveLength(1);
    expect(source).toContain(
      "queryClient.invalidateQueries({ queryKey: adminQueryKeys.feedbackDetails(details.id) })"
    );
    expect(source).toContain('queryClient.invalidateQueries({ queryKey: ["admin", "feedback"] })');
    expect(source).not.toContain(
      "await queryClient.invalidateQueries({ queryKey: adminQueryKeys.feedbackDetails(details.id) });\n      await queryClient.invalidateQueries({ queryKey: [\"admin\", \"feedback\"] });"
    );
  });

  it("does not show a free user plan before user context finishes loading", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("userQuery.isLoading");
    expect(source).toContain("userAnalyticsQuery.isLoading");
    expect(source).toContain("text.userContextLoading");
    expect(source).not.toContain('`${userQuery.data?.isPremium ? "premium" : "free"}');
  });

  it("keeps feedback user context failures local and retryable", () => {
    const source = readFileSync(feedbackPagePath, "utf8");
    const stylesSource = readFileSync(feedbackStylesPath, "utf8");

    expect(source).toContain("userContextErrorTitle:");
    expect(source).toContain("userContextErrorDescription:");
    expect(source).toContain(
      "const hasUserContextError = Boolean(details.userId) && (userQuery.isError || userAnalyticsQuery.isError);"
    );
    expect(source).toContain(
      "const isUserContextFetching = userQuery.isFetching || userAnalyticsQuery.isFetching;"
    );
    expect(source).toContain("title={text.userContextErrorTitle}");
    expect(source).toContain("userQuery.error ?? userAnalyticsQuery.error");
    expect(source).toContain("disabled={isUserContextFetching}");
    expect(source).toContain("void Promise.allSettled([");
    expect(source).toContain("userQuery.refetch()");
    expect(source).toContain("userAnalyticsQuery.refetch()");
    expect(source).not.toContain("void Promise.all([\n                      userQuery.refetch()");
    expect(source).toContain("className={styles.detailsMain}");
    expect(stylesSource).toContain(".detailsMain");
    expect(source).not.toContain("userQuery.isError ? (\n        <AdminStateCard title={text.detailsError}");
  });

  it("renders feedback media previews through the secure media component", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain(
      'import { TemplateSecureMedia } from "@/components/templates/template-secure-media";'
    );
    expect(source).not.toContain('import Image from "next/image";');
    expect(source).toContain("url={item.previewUrl}");
    expect(source).toContain('logContext={{ surface: "feedback-list-preview" }}');
    expect(source).toContain("url={details.generation.inputPreviewUrl}");
    expect(source).toContain('surface: "feedback-generation-input-preview"');
    expect(source).toContain("url={details.generation.resultPreviewUrl}");
    expect(source).toContain('surface: "feedback-generation-result-preview"');
    expect(source).not.toContain("src={item.previewUrl}");
    expect(source).not.toContain("src={details.generation.inputPreviewUrl}");
    expect(source).not.toContain("src={details.generation.resultPreviewUrl}");
  });

  it("keeps feedback detail and pagination layouts usable on narrow screens", () => {
    const stylesSource = readFileSync(feedbackStylesPath, "utf8");

    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain(".tableHeader,\n  .actions");
    expect(stylesSource).toContain("flex-direction: column;");
    expect(stylesSource).toContain(".actions .button:not(.pagerButton) {\n    width: 100%;");
    expect(stylesSource).toContain(".pagerButton {\n  min-width: 2.35rem;");
    expect(stylesSource).toContain(".pageIconPrevious {\n  transform: rotate(90deg);");
    expect(stylesSource).toContain(".pageIconNext {\n  transform: rotate(-90deg);");
    expect(stylesSource).toContain(".detailGrid,\n  .previewGrid");
    expect(stylesSource).toContain("grid-template-columns: 1fr;");
  });

  it("keeps local feedback form controls accessible in locked and keyboard states", () => {
    const stylesSource = readFileSync(feedbackStylesPath, "utf8");

    expect(stylesSource).toContain(".input:focus-visible,\n.select:focus-visible,\n.textarea:focus-visible,\n.button:focus-visible");
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain(".input:disabled,\n.select:disabled,\n.textarea:disabled");
    expect(stylesSource).toContain("cursor: not-allowed;");
    expect(stylesSource).toContain("opacity: 0.62;");
    expect(stylesSource).not.toContain("rgba(");
    expect(stylesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });
});
