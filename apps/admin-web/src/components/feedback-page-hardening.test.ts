import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readFeedbackPageLibrarySource } from "@/components/feedback-page.test-source";

const feedbackPageContentPath = fileURLToPath(
  new URL("./feedback-page.content.ts", import.meta.url)
);
const feedbackStylesPath = fileURLToPath(new URL("./feedback-page.module.css", import.meta.url));
const feedbackTypesPath = fileURLToPath(
  new URL("../lib/api-client.types.feedback.ts", import.meta.url)
);

describe("feedback page hardening", () => {
  it("uses the shared admin session guard for Admin and Moderator feedback access", () => {
    const source = readFeedbackPageLibrarySource();

    expect(source).toContain('import { useRouter } from "next/navigation";');
    expect(source).toContain(
      'import { ensureAdminSession } from "@/components/admin/admin-session";'
    );
    expect(source).toContain("ensureAdminSession(locale, router);");
    expect(source).toContain(
      'session?.user.roles.some((role) => role === "Admin" || role === "Moderator") ?? false'
    );
    expect(source).toContain(
      'const canViewUserProfile = session?.user.roles.includes("Admin") ?? false;'
    );
  });

  it("debounces and validates backend-aligned feedback filters, including generation ID lookup", () => {
    const source = readFeedbackPageLibrarySource();

    expect(source).toContain("ADMIN_FEEDBACK_LOOKUP_ID_MAX_LENGTH,");
    expect(source).toContain("ADMIN_FEEDBACK_CATEGORY_FILTER_MAX_LENGTH,");
    expect(source).toContain("ADMIN_FEEDBACK_PLATFORM_FILTER_MAX_LENGTH,");
    expect(source).toContain("isAdminFeedbackLookupId,");
    expect(source).toContain("function useDebouncedValue(value: string, delayMs: number)");
    expect(source).toContain("const debouncedCategory = useDebouncedValue(category, 350);");
    expect(source).toContain("const debouncedPlatform = useDebouncedValue(platform, 350);");
    expect(source).toContain("const debouncedLookupValue = useDebouncedValue(lookupValue, 350);");
    expect(source).toContain('type LookupField = "userId" | "templateId" | "generationId";');
    expect(source).toContain(
      'generationId: lookupField === "generationId" ? debouncedLookupValue : undefined,'
    );
    expect(source).toContain("maxLength={ADMIN_FEEDBACK_LOOKUP_ID_MAX_LENGTH}");
    expect(source).toContain("maxLength={ADMIN_FEEDBACK_CATEGORY_FILTER_MAX_LENGTH}");
    expect(source).toContain("maxLength={ADMIN_FEEDBACK_PLATFORM_FILTER_MAX_LENGTH}");
    expect(source).toContain("const isLookupValueInvalid =");
    expect(source).toContain("!isAdminFeedbackLookupId(lookupValue)");
    expect(source).toContain("enabled: canView && !filterValidationMessage");
    expect(source).toContain("aria-invalid={invalid || undefined}");
    expect(source).toContain("? event.target.value.slice(0, maxLength)");
    expect(source).toContain("category: debouncedCategory");
    expect(source).toContain("platform: debouncedPlatform");
  });

  it("converts local calendar-day boundaries to UTC before requesting the backend", () => {
    const source = readFeedbackPageLibrarySource();

    expect(source).toContain("function dateInputToUtcStart(value: string)");
    expect(source).toContain("function dateInputToUtcEnd(value: string)");
    expect(source).toContain("new Date(`${value}T00:00:00.000`)");
    expect(source).toContain("new Date(`${value}T23:59:59.999`)");
    expect(source).toContain(
      "Number.isNaN(localBoundary.valueOf()) ? undefined : localBoundary.toISOString()"
    );
    expect(source).toContain("fromUtc: dateInputToUtcStart(fromUtc)");
    expect(source).toContain("toUtc: dateInputToUtcEnd(toUtc)");
  });

  it("keeps the queue visible during a refresh and handles stale selection safely", () => {
    const source = readFeedbackPageLibrarySource();

    expect(source).toContain("const isFeedbackFetching = feedbackQuery.isFetching;");
    expect(source).toContain(
      "const isInitialFeedbackLoading = feedbackQuery.isFetching && !pageData;"
    );
    expect(source).toContain("const isFeedbackSelectionLocked =");
    expect(source).toContain("isInitialFeedbackLoading || feedbackQuery.isPlaceholderData;");
    expect(source).toContain("const areFeedbackFiltersLocked = isInitialFeedbackLoading;");
    expect(source).toContain(
      "const visiblePageData = filterValidationMessage ? undefined : pageData;"
    );
    expect(source).toContain(") : isInitialFeedbackLoading ? (");
    expect(source).toContain("feedbackQuery.isError && !visiblePageData");
    expect(source).toContain("{isFeedbackRefreshing ? (");
    expect(source).toContain("function requestFeedbackPageChange(nextPage: number)");
    expect(source).toContain("if (isFeedbackFetching || nextPage < 0)");
    expect(source).toContain("if (nextPage > page && !visiblePageData?.hasMore)");
    expect(source).toContain("function requestFeedbackRetry()");
    expect(source).toContain("void feedbackQuery.refetch().catch(() => undefined);");
    expect(source).toContain("disabled={isFeedbackSelectionLocked}");
    expect(source).toContain("aria-busy={isBusy || undefined}");
    expect(source).toContain("{queueRefreshLabel}");
    expect(source).toContain("text.queueRefreshError");
    expect(source).toContain("const visibleFeedbackIds = useMemo(");
    expect(source).toContain("feedbackQuery.isPlaceholderData ||");
    expect(source).toContain("visibleFeedbackIds.has(selectedId) ||");
    expect(source).toContain("queueMicrotask(() => {");
  });

  it("confirms filter changes before they discard an unsaved inspector draft", () => {
    const source = readFeedbackPageLibrarySource();

    expect(source).toContain("const resetFilters = useCallback(() => {");
    expect(source).toContain('setStatus("All");');
    expect(source).toContain('setPriority("All");');
    expect(source).toContain('setType("All");');
    expect(source).toContain('setLookupField("userId");');
    expect(source).toContain('setLookupValue("");');
    expect(source).toContain("setAreAdvancedFiltersOpen(false);");
    expect(source).toContain("const requestDiscardOrRun = useCallback(");
    expect(source).toContain("const applyFeedbackFilterChange = useCallback(");
    expect(source).toContain("clearFeedbackSelection();\n        change();");
    expect(source).toContain("const requestFeedbackSelection = useCallback(");
    expect(source).toContain("const requestCloseSelection = useCallback(");
    expect(source).toContain('window.addEventListener("beforeunload", handleBeforeUnload);');
    expect(source).toContain("onClick={requestResetFilters}");
    expect(source).toContain("applyFeedbackFilterChange(() => {");
    expect(source).toContain("applyFeedbackFilterChange(() => removeActiveFilter(filter.id))");
    expect(source).toContain("const resetFeedbackDraft = () => {");
  });

  it("uses the shared branded Select instead of native dropdowns", () => {
    const source = readFeedbackPageLibrarySource();

    expect(source).toContain('import { Select, type SelectOption } from "@/components/ui/select";');
    expect(source).toContain("export function FeedbackSelectField");
    expect(source).toContain("showSelectedDescription={false}");
    expect(source).toContain("ariaLabel={label}");
    expect(source).not.toContain("<select");
  });

  it("renders a selected work queue and a focused inspector instead of a raw wide table", () => {
    const source = readFeedbackPageLibrarySource();
    const stylesSource = readFileSync(feedbackStylesPath, "utf8");

    expect(source).toContain("export function FeedbackQueue");
    expect(source).toContain(
      "<ul className={styles.queue} aria-label={text.queue} aria-busy={isBusy || undefined}>"
    );
    expect(source).toContain("<li key={item.id}>");
    expect(source).toContain('aria-current={isSelected ? "true" : undefined}');
    expect(source).not.toContain("aria-pressed={isSelected}");
    expect(source).not.toContain('role="listitem"');
    expect(source).toContain("<DetailsPanel");
    expect(source).toContain("className={styles.inspectorSlot}");
    expect(source).not.toContain("<table");
    expect(stylesSource).toContain(".queueItemSelected");
    expect(stylesSource).toContain(".inspectorCard {");
    expect(stylesSource).toContain("position: sticky;");
    expect(stylesSource).toContain("top: calc(4.1rem + 0.75rem);");
    expect(stylesSource).toContain("max-height: calc(100dvh - 5.85rem);");
  });

  it("keeps one compact working flow instead of repeating page, queue, and inspector context", () => {
    const source = readFeedbackPageLibrarySource();
    const stylesSource = readFileSync(feedbackStylesPath, "utf8");

    expect(source).not.toContain("styles.workspaceHeader");
    expect(source).not.toContain("description={text.queueDescription}");
    expect(source).toContain("const activeAdvancedFilters = useMemo(");
    expect(source).toContain("{activeAdvancedFilters.length > 0 ? (");
    expect(source).toContain("className={styles.decisionPanel}");
    expect(source).toContain("{text.addNote}");
    expect(source).toContain("{isFeedbackDraftDirty ? (");
    expect(source).toContain("className={styles.draftActions}");
    expect(source).not.toContain('variant="primary"\n            size="md"');
    expect(stylesSource).toContain(".decisionPanel {");
    expect(stylesSource).toContain(".contextActions {");
    expect(stylesSource).not.toContain(".workspaceHeader {");
  });

  it("protects feedback mutations and requires an auditable refund confirmation", () => {
    const source = readFeedbackPageLibrarySource();
    const contentSource = readFileSync(feedbackPageContentPath, "utf8");

    expect(source).toContain("ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH,");
    expect(source).toContain("ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH,");
    expect(source).toContain("const isFeedbackActionLocked =");
    expect(source).toContain(
      "updateMutation.isPending || refundMutation.isPending || isDetailsFetching"
    );
    expect(source).toContain(
      "const isSaveFeedbackDisabled = !isFeedbackDraftDirty || isFeedbackActionLocked;"
    );
    expect(source).toContain('onNotify(getAdminErrorMessage(error, text.error), "error");');
    expect(source).toContain("const requestRefundFeedback = () => {");
    expect(source).toContain("setIsRefundDialogOpen(true);");
    expect(source).toContain("<ConfirmationDialog");
    expect(source).toContain("confirmDisabled={isRefundConfirmationDisabled}");
    expect(source).toContain(
      "const [refundAmountInput, setRefundAmountInput] = useState(String(refundableCredits));"
    );
    expect(source).toContain("const isRefundAmountValid =");
    expect(source).toContain(
      "refundMutation.mutate({ amount: refundAmount, reason: refundReason.trim() });"
    );
    expect(source).toContain('onNotify(getAdminErrorMessage(error, text.refundError), "error");');
    expect(source).toContain("{refundMutation.isError ? (");
    expect(source).toContain("max={refundableCredits}");
    expect(source).toContain("aria-invalid={!isRefundAmountValid}");
    expect(source).toContain(
      "aria-describedby={!isRefundAmountValid ? refundAmountErrorId : undefined}"
    );
    expect(source).toContain("text.refundReasonRequired");
    expect(source).not.toContain("Feedback refund {details.id}");
    expect(contentSource).toContain("refundTitle:");
    expect(contentSource).toContain("refundReasonRequired:");
  });

  it("keeps the review context available while navigating to related feedback", () => {
    const source = readFeedbackPageLibrarySource();
    const contentSource = readFileSync(feedbackPageContentPath, "utf8");

    expect(source).toContain("const applyRelatedFeedbackFilter = useCallback(");
    expect(source).toContain("const requestRelatedFeedbackFilter = useCallback(");
    expect(source).toContain("relatedFeedbackActions={relatedFeedbackActions}");
    expect(source).toContain("className={styles.contextActions}");
    expect(source).toContain("aria-label={text.relatedFeedback}");
    expect(contentSource).toContain("relatedUserFeedback:");
    expect(contentSource).toContain("relatedGenerationFeedback:");
    expect(contentSource).toContain("relatedTemplateFeedback:");
  });

  it("reflects backend refund eligibility and keeps cache invalidations complete", () => {
    const source = readFeedbackPageLibrarySource();
    const typesSource = readFileSync(feedbackTypesPath, "utf8");

    expect(typesSource).toContain("refundUnavailableReason?: string | null;");
    expect(source).toContain('details.refundUnavailableReason.includes("already_issued")');
    expect(source).toContain("details.generation?.refundedAtUtc");
    expect(source).toContain("queryClient.setQueryData<AdminFeedbackDetails>(");
    expect(source).toContain("adminQueryKeys.feedbackDetails(updatedDetails.id)");
    expect(source).toContain('refundUnavailableReason: "feedback.refund_already_issued"');
    expect(source).toContain("generation: currentDetails.generation");
    expect(source).toContain('queryClient.invalidateQueries({ queryKey: ["admin", "feedback"] })');
    expect(source).toContain(
      'queryClient.invalidateQueries({ queryKey: ["admin", "economy", "ledger"] })'
    );
    expect(source).toContain(
      "queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyDashboardMetrics })"
    );
    expect(source).toContain(
      "queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDetail(details.userId) })"
    );
  });

  it("keeps sensitive feedback context masked and media on the secure component", () => {
    const source = readFeedbackPageLibrarySource();

    expect(source).toContain("sanitizeSensitiveMultilineText,");
    expect(source).toContain("sanitizeSensitiveText,");
    expect(source).toContain("const userLabel = details.userEmail");
    expect(source).toContain("? maskEmail(details.userEmail)");
    expect(source).toContain(": userQuery.data?.email");
    expect(source).toContain(": shortId(details.userId);");
    expect(source).toContain(
      'import { TemplateSecureMedia } from "@/components/templates/template-secure-media";'
    );
    expect(source).toContain('logContext={{ surface: "feedback-list-preview" }}');
    expect(source).toContain('surface: "feedback-generation-input-preview"');
    expect(source).toContain('surface: "feedback-generation-result-preview"');
    expect(source).toContain("sanitizeSensitiveMultilineText(details.message, 2_000)");
    expect(source).toContain('menuMode="inline"');
    expect(source).not.toContain('import Image from "next/image";');
  });

  it("does not fetch user context already supplied by the feedback details response", () => {
    const source = readFeedbackPageLibrarySource();

    expect(source).toContain(
      "const canLoadUserContext = canViewUserProfile && Boolean(details.userId);"
    );
    expect(source).toMatch(
      /canLoadUserContext\s*&&\s*\(\s*!details\.userEmail\s*\|\|\s*details\.userPlan\s*===\s*null\s*\|\|\s*details\.userPlan\s*===\s*undefined\s*\);/
    );
    expect(source).toContain(
      "canLoadUserContext && (details.userCredits === null || details.userCredits === undefined);"
    );
    expect(source).toContain("enabled: shouldFetchUserProfile,");
    expect(source).toContain("enabled: shouldFetchUserAnalytics,");
    expect(source).toContain("const userLabel = details.userEmail");
    expect(source).toContain("const requestUserContextRetry = () => {");
    expect(source).toContain("if (shouldFetchUserProfile) {");
    expect(source).toContain("if (shouldFetchUserAnalytics) {");
    expect(source).toContain("onClick={requestUserContextRetry}");
  });

  it("localizes workflow copy and normalizes known raw category/source keys", () => {
    const source = readFeedbackPageLibrarySource();
    const contentSource = readFileSync(feedbackPageContentPath, "utf8");

    expect(source).toContain(
      'import { getFeedbackPageText, type FeedbackPageText } from "./feedback-page.content";'
    );
    expect(source).toContain(
      "function knownLabel(value: string | null | undefined, labels: Record<string, string>)"
    );
    expect(source).toContain('safe.replace(/[_-]+/g, " ")');
    expect(contentSource).toContain('title: "Отзывы"');
    expect(contentSource).toContain('title: "Feedback"');
    expect(contentSource).toContain("lookupOptions:");
    expect(contentSource).toContain("categoryLabels:");
    expect(contentSource).toContain("sourceLabels:");
    expect(contentSource).toContain('low_value: "Низкая ценность"');
    expect(contentSource).toContain('paywall_close: "Закрытие paywall"');
  });

  it("keeps filter, queue, inspector, and confirmation layouts usable on narrow screens", () => {
    const stylesSource = readFileSync(feedbackStylesPath, "utf8");

    expect(stylesSource).toContain("@media (max-width: 1280px)");
    expect(stylesSource).toContain(".workspace {\n    grid-template-columns: 1fr;");
    expect(stylesSource).toContain("@media (max-width: 960px)");
    expect(stylesSource).toContain("@media (max-width: 720px)");
    expect(stylesSource).toContain("@media (max-width: 560px)");
    expect(stylesSource).toContain(".filterBar,\n  .advancedFilterBar,");
    expect(stylesSource).toContain(".operationDetails,");
    expect(stylesSource).toContain(".decisionFields {");
    expect(stylesSource).toContain(":global(.ui-button)");
    expect(stylesSource).toContain("@media (prefers-reduced-motion: reduce)");
  });

  it("keeps local inputs keyboard-accessible and delegates dropdown keyboard behavior to the shared Select", () => {
    const stylesSource = readFileSync(feedbackStylesPath, "utf8");

    expect(stylesSource).toContain(".filterTab:focus-visible,");
    expect(stylesSource).toContain(".input:focus-visible,");
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain(".input:disabled,");
    expect(stylesSource).toContain("cursor: not-allowed;");
    expect(stylesSource).toContain("opacity: 0.62;");
    expect(stylesSource).toContain(".fieldHint {");
    expect(stylesSource).toContain("var(--warning-soft-fg)");
    expect(stylesSource).not.toContain("rgba(");
    expect(stylesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });
});
