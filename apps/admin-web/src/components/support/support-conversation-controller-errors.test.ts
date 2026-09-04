import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readSupportConversationControllerLibrarySource } from "./support-conversation-controller.test-source";
import { readSupportConversationPageLibrarySource } from "./support-conversation-page.test-source";
import { readSupportInfoPanelLibrarySource } from "./support-info-panel.test-source";

const controllerHelpersPath = fileURLToPath(
  new URL("./support-conversation-controller.helpers.ts", import.meta.url)
);
const supportContentPath = fileURLToPath(
  new URL("./support-conversation.content.ts", import.meta.url)
);
const supportInboxPagePath = fileURLToPath(new URL("./support-inbox-page.tsx", import.meta.url));
const supportStylesPath = fileURLToPath(new URL("./support-page.module.css", import.meta.url));
const selectPath = fileURLToPath(new URL("../ui/select.tsx", import.meta.url));
const adminQueryKeysPath = fileURLToPath(new URL("../../lib/admin-query-keys.ts", import.meta.url));
const supportChatContentPath = fileURLToPath(
  new URL("./support-conversation-chat-content.tsx", import.meta.url)
);
const supportAssignmentControlPath = fileURLToPath(
  new URL("./support-assignment-control.tsx", import.meta.url)
);

describe("support conversation controller errors", () => {
  it("uses sanitized backend messages for support mutation failures", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const helpersSource = readFileSync(controllerHelpersPath, "utf8");
    const assignmentControlSource = readFileSync(supportAssignmentControlPath, "utf8");

    expect(controllerSource).toContain("import { getAdminErrorMessage }");
    expect(controllerSource).toContain("const pushSupportError = useCallback(");
    expect(controllerSource).toContain("getAdminErrorMessage(error, text.supportLoadError)");
    expect(controllerSource).toContain('clientLogger.warn("support.action_failed", {');
    expect(controllerSource).toContain("action: formatSupportControllerLogText(action, 40)");
    expect(controllerSource).toContain('pushSupportError(error, "send_reply")');
    expect(controllerSource).toContain('pushSupportError(error, "update_status")');
    expect(assignmentControlSource).toContain(
      "setErrorMessage(getAdminErrorMessage(error, copy.failed))"
    );
    expect(controllerSource).toContain('pushSupportError(error, "update_metadata")');
    expect(controllerSource).toContain(
      "conversationId: formatSupportControllerLogText(conversationId)"
    );
    expect(controllerSource).toContain("...getSupportControllerErrorDetails(error)");
    expect(helpersSource).toContain(
      "export function getSupportControllerErrorDetails(error: unknown)"
    );
    expect(helpersSource).toContain(
      'errorName: error instanceof Error ? error.name : "UnknownError"'
    );
    expect(helpersSource).toContain("export function formatSupportControllerLogText(");
    expect(controllerSource).not.toContain(
      'setToast({ type: "error", message: text.supportLoadError });'
    );
    expect(controllerSource).not.toContain(
      'pushSupportNotification("error", text.supportLoadError);'
    );
    expect(controllerSource).not.toContain('clientLogger.warn("support.action_failed", { error');
    expect(controllerSource).not.toContain("conversationId,\n            error");
    expect(controllerSource).not.toContain("conversationId,\n          error");
  });

  it("keeps support workspace fetches and actions role-guarded at the controller layer", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const helpersSource = readFileSync(controllerHelpersPath, "utf8");
    const contentSource = readFileSync(supportContentPath, "utf8");
    const pageSource = readSupportConversationPageLibrarySource();
    const infoPanelSource = readSupportInfoPanelLibrarySource();
    const selectSource = readFileSync(selectPath, "utf8");

    expect(controllerSource).toContain("const sessionUserRoles = session?.user.roles ?? [];");
    expect(controllerSource).toContain(
      'const canManageSupportWorkspace =\n    sessionUserRoles.includes("Admin") || sessionUserRoles.includes("Moderator");'
    );
    expect(controllerSource).toContain("const supportActionsForbidden =");
    expect(contentSource).toContain(
      'actionsForbidden: "Действия поддержки доступны только администраторам или модераторам."'
    );
    expect(contentSource.slice(0, contentSource.indexOf("  en: {"))).not.toContain(
      "Admin или Moderator"
    );
    expect(controllerSource).toContain(
      "const assertCanManageSupportWorkspace = useCallback(() => {"
    );
    expect(controllerSource).toContain(
      'setToast({ type: "error", message: supportActionsForbidden });'
    );
    expect(controllerSource).toContain("enabled: Boolean(session && canManageSupportWorkspace)");
    expect(helpersSource).toContain(
      "export const supportInboxStaleTimeMs = supportPollingIntervalMs;"
    );
    expect(helpersSource).toContain(
      "export const supportRealtimeHealthyPollingIntervalMs = 60_000;"
    );
    expect(helpersSource).toContain("export const supportSubjectContextStaleTimeMs = 30_000;");
    expect(controllerSource).toContain("staleTime: supportInboxStaleTimeMs");
    expect(controllerSource).toContain("staleTime: supportSubjectContextStaleTimeMs");
    expect(controllerSource).toContain(
      'supportRealtimeStatus === "connected"\n      ? supportRealtimeHealthyPollingIntervalMs\n      : supportPollingIntervalMs'
    );
    expect(controllerSource).toContain(
      "refetchInterval: supportPollingEnabled ? supportRealtimeAwarePollingInterval : false"
    );
    expect(controllerSource).toContain("const supportRealtimeStatus = useSupportRealtime(");
    expect(controllerSource).toContain(
      "!canManageSupportWorkspace ||\n      !conversationQuery.data"
    );
    expect(controllerSource).toContain(
      "if (!canManageSupportWorkspace || loadOlderAbortControllerRef.current) {\n      return;\n    }\n\n    const currentConversation"
    );
    expect(controllerSource).toContain("if (!assertCanManageSupportWorkspace())");
    expect(controllerSource).toContain(
      "if (!isReplyActorCurrent(variables.actor) || !canMutateConversation) {\n        return {};"
    );
    expect(controllerSource).toContain(
      "if (!canMutateConversation) {\n        throw new Error(supportOwnershipRequired);"
    );
    expect(controllerSource).toContain("canManageSupportWorkspace,");
    expect(controllerSource).toContain("canMutateConversation,\n    supportActionsForbidden,");
    expect(controllerSource).toContain("const [isSendReplyInFlight, setIsSendReplyInFlight]");
    expect(controllerSource).toContain("const sendReplyInFlightRef = useRef(false);");
    expect(controllerSource).toContain("const isReplyInFlightForActor = Boolean(");
    expect(controllerSource).toContain("sendReplyActorIdRef.current === actor.userId &&");
    expect(controllerSource).toContain("(sendReplyInFlightRef.current || sendMutation.isPending)");
    expect(controllerSource).toContain("isSendReplySubmitting: Boolean(");
    expect(controllerSource).toContain("const requestSendReply = useCallback(() => {");
    expect(controllerSource).toContain("sendReplyInFlightRef.current = true;");
    expect(controllerSource).toContain("setIsSendReplyInFlight(true);");
    expect(controllerSource).toContain("sendReplyInFlightRef.current = false;");
    expect(controllerSource).toContain("setIsSendReplyInFlight(false);");
    expect(controllerSource).toContain("requestSendReply,");
    expect(controllerSource).toContain("isSendReplySubmitting,");
    expect(pageSource).toContain("const isComposerBusy = isSendReplySubmitting;");
    expect(pageSource).toContain(
      "const isComposerDisabled = isConversationReadOnly || !canManageSupportWorkspace || isComposerBusy;"
    );
    expect(pageSource).toContain("const revealOwnershipComposerNotice = () => {");
    expect(infoPanelSource).toContain("disabled={!canMutateConversation}");
    expect(infoPanelSource).toContain(
      "disabled={!canMutateConversation || statusMutation.isPending}"
    );
    expect(infoPanelSource).toContain(
      "if (!canMutateConversation || statusMutation.isPending || conversation.status === status)"
    );
    expect(infoPanelSource).toContain(
      "if (!canManageSupportWorkspace || pendingAttachmentOpenKey !== null)"
    );
    expect(selectSource).toContain("disabled?: boolean;");
    expect(selectSource).toContain("const isSelectDisabled = disabled || !hasOptions;");
    expect(selectSource).toContain("disabled={isSelectDisabled}");
  });

  it("keeps support queue pagination on backend query params instead of a fixed first page", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const pageSource = readSupportConversationPageLibrarySource();
    const supportContentSource = readFileSync(supportContentPath, "utf8");
    const inboxPageSource = readFileSync(supportInboxPagePath, "utf8");
    const infoPanelSource = readSupportInfoPanelLibrarySource();

    expect(controllerSource).toContain(
      "const [queuePage, setQueuePage] = useState(initialQueueState.page);"
    );
    expect(controllerSource).toContain("setQueuePage(1);");
    expect(controllerSource).toContain("page: queuePage");
    expect(controllerSource).toContain("canGoToNextQueuePage");
    expect(controllerSource).toContain("useQuery<AdminSupportInboxPage>");
    expect(controllerSource).toContain("sortSupportQueueItems(inboxQuery.data?.items ?? [])");
    expect(controllerSource).toContain(
      "const canGoToNextQueuePage = Boolean(inboxQuery.data?.hasMore);"
    );
    expect(controllerSource).not.toContain(
      "(inboxQuery.data?.length ?? 0) >= SUPPORT_INBOX_PAGE_SIZE"
    );
    expect(pageSource).toContain("setQueuePage((currentPage) => Math.max(1, currentPage - 1))");
    expect(pageSource).toContain("setQueuePage((currentPage) => currentPage + 1)");
    expect(pageSource).toContain("disabled={!canGoToNextQueuePage || isQueueControlsLocked}");
    expect(pageSource).toContain("disabled={isQueueControlsLocked}");
    expect(pageSource).toMatch(/if \(isQueueControlsLocked\) {\s+return;\s+}/);
    expect(pageSource).toContain('data-disabled={isQueueControlsLocked ? "true" : undefined}');
    expect(pageSource).toContain("tabIndex={isQueueControlsLocked ? -1 : undefined}");
    expect(pageSource).toMatch(/if \(isQueueControlsLocked\) {\s+event\.preventDefault\(\);\s+}/);
    expect(pageSource).toContain("const queueLabels = copy.page.queue;");
    expect(supportContentSource).toContain('previousPage: "Предыдущая страница очереди"');
    expect(supportContentSource).toContain('previousPage: "Previous queue page"');
    expect(supportContentSource).toContain('nextPage: "Следующая страница очереди"');
    expect(supportContentSource).toContain('nextPage: "Next queue page"');
    expect(pageSource).toContain("aria-label={queueLabels.previousPage}");
    expect(pageSource).toContain("aria-label={queueLabels.nextPage}");
    expect(pageSource).toContain("title={queueLabels.previousPage}");
    expect(pageSource).toContain("title={queueLabels.nextPage}");
    expect(pageSource).toContain("{queueLabels.title}");
    expect(pageSource).toContain("{queueLabels.unassigned} {unassignedCount}");
    expect(pageSource).toContain('{ value: "all", label: queueLabels.all }');
    expect(pageSource).toContain("queueLabels.filtersActive(activeAdvancedFilterCount)");
    expect(pageSource).toContain("open={activeAdvancedFilterCount > 0 ? true : undefined}");
    expect(infoPanelSource).toContain('role="tabpanel"');
    expect([...infoPanelSource.matchAll(/role="tabpanel"/g)]).toHaveLength(1);
    expect(infoPanelSource).toContain("aria-controls={`support-panel-tabpanel-${tab.value}`}");
    expect(infoPanelSource).toContain('event.key === "ArrowRight"');
    expect(infoPanelSource).toContain('event.key === "ArrowLeft"');
    expect(pageSource).toContain("title={queueLabels.newMessagesTitle(incomingMessagesCount)}");
    expect(pageSource).toContain("queueLabels.pageCount(");
    expect(pageSource).not.toContain(
      'aria-label={locale === "ru" ? "Предыдущая страница очереди" : "Previous queue page"}'
    );
    expect(pageSource).not.toContain(
      'aria-label={locale === "ru" ? "Следующая страница очереди" : "Next queue page"}'
    );
    expect(pageSource).toContain(
      "className={`${styles.queuePagerIcon} ${styles.queuePagerIconPrevious}`}"
    );
    expect(pageSource).toContain(
      "className={`${styles.queuePagerIcon} ${styles.queuePagerIconNext}`}"
    );
    expect(pageSource).not.toContain('{locale === "ru" ? "Назад" : "Previous"}');
    expect(pageSource).not.toContain('{locale === "ru" ? "Вперёд" : "Next"}');
    expect(inboxPageSource).toContain("selectedConversationId &&");
    expect(inboxPageSource).toContain("sortedConversations.some(");
    expect(inboxPageSource).toContain(
      "(conversation) => conversation.conversationId === selectedConversationId"
    );
  });

  it("bounds support queue search and reply composer values before storing them", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const helpersSource = readFileSync(controllerHelpersPath, "utf8");
    const pageSource = readSupportConversationPageLibrarySource();

    expect(helpersSource).toContain("SUPPORT_INBOX_SEARCH_MAX_LENGTH,");
    expect(helpersSource).toContain("SUPPORT_MESSAGE_BODY_MAX_LENGTH,");
    expect(helpersSource).toContain(
      "export const SUPPORT_SEARCH_MAX_LENGTH = SUPPORT_INBOX_SEARCH_MAX_LENGTH;"
    );
    expect(helpersSource).toContain(
      "export const SUPPORT_REPLY_MAX_LENGTH = SUPPORT_MESSAGE_BODY_MAX_LENGTH;"
    );
    expect(controllerSource).toContain("export {");
    expect(controllerSource).toContain("SUPPORT_REPLY_MAX_LENGTH,");
    expect(controllerSource).toContain("SUPPORT_SEARCH_MAX_LENGTH,");
    expect(controllerSource).toContain("statusOptions,");
    expect(controllerSource).toContain(
      '} from "@/components/support/support-conversation-controller.helpers";'
    );
    expect(controllerSource).toContain(
      "setRawSearchQuery(value.slice(0, SUPPORT_SEARCH_MAX_LENGTH));"
    );
    expect(controllerSource).toContain("const setSupportReply = useCallback((value: string) => {");
    expect(controllerSource).toContain("setReply(value.slice(0, SUPPORT_REPLY_MAX_LENGTH));");
    expect(controllerSource).toContain("setReply: setSupportReply,");
    expect(pageSource).toContain("maxLength={SUPPORT_SEARCH_MAX_LENGTH}");
    expect(pageSource).toContain("<label className={styles.queueSearchField}>");
    expect(pageSource).not.toContain("supportPageHeroSearch");
    expect(pageSource).toContain("maxLength={SUPPORT_REPLY_MAX_LENGTH}");
    expect(pageSource).toContain(
      "setSearchQuery={(value) => setSearchQuery(value.slice(0, SUPPORT_SEARCH_MAX_LENGTH))}"
    );
    expect(pageSource).toContain("setReply(event.target.value.slice(0, SUPPORT_REPLY_MAX_LENGTH))");
    expect(pageSource).toContain("onChange={(event) => setSearchQuery(event.target.value)}");
    expect(pageSource).not.toContain("onChange={(event) => setReply(event.target.value)}");
  });

  it("keeps route-level conversation load failures retryable", () => {
    const pageSource = readSupportConversationPageLibrarySource();
    const stylesSource = readFileSync(supportStylesPath, "utf8");

    expect(pageSource).toContain("conversationQuery.isError || !conversation");
    expect(pageSource).toContain("const requestConversationRetry = () => {");
    expect(pageSource).toContain(
      "if (!canManageSupportWorkspace || conversationQuery.isFetching) {\n      return;\n    }"
    );
    expect(pageSource).toContain("void conversationQuery.refetch().catch(() => undefined)");
    expect(pageSource).toContain("onClick={requestConversationRetry}");
    expect(pageSource).toContain(
      "disabled={!canManageSupportWorkspace || conversationQuery.isFetching}"
    );
    expect(pageSource).toContain("{text.supportRetryAction}");
    expect(pageSource).toContain("{text.supportBackToInbox}");
    expect(pageSource).toContain("className={styles.errorActions}");
    expect(pageSource).not.toContain(
      "onClick={() => {\n                  if (!canManageSupportWorkspace)"
    );
    expect(pageSource).not.toContain('style={{ display: "flex"');
    expect(stylesSource).toContain(".errorActions");
    expect(stylesSource).toContain("@media (max-width: 520px)");
  });

  it("sends exact support status filters through backend query params", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const helpersSource = readFileSync(controllerHelpersPath, "utf8");
    const pageSource = readSupportConversationPageLibrarySource();

    expect(pageSource).toContain("queueStatusFilter,");
    expect(pageSource).toContain(
      "const isQueueControlsLocked = !canManageSupportWorkspace || inboxQuery.isFetching;"
    );
    expect(pageSource).toContain(
      'const setExactQueueStatusFilter = (value: "all" | SupportConversationStatus) => {'
    );
    expect(pageSource).toContain("if (isQueueControlsLocked) {\n      return;\n    }");
    expect(pageSource).toContain('setSubFilter("all");');
    expect(pageSource).toContain('setQueueFilter("all");');
    expect(pageSource).toContain("setQueueStatusFilter(value);");
    expect(pageSource).toContain("setQueuePage(1);");
    expect(pageSource).toContain(
      'setExactQueueStatusFilter(value as "all" | SupportConversationStatus);'
    );
    expect(pageSource).toContain("disabled={isQueueControlsLocked}");
    expect(helpersSource).toContain('queueStatusFilter?: "all" | SupportConversationStatus;');
    expect(controllerSource).toContain(
      'const effectiveQueueStatus =\n    queueStatusFilter === "all" ? resolvedQueueFilter.status : queueStatusFilter;'
    );
    expect(controllerSource).toContain(
      "fetchSupportInbox(effectiveQueueStatus, resolvedQueueFilter.assignment"
    );
    expect(pageSource).not.toContain(
      '.filter((item) => (queueStatusFilter === "all" ? true : item.status === queueStatusFilter))'
    );
  });

  it("routes the minimal support quick filters through backend query params", () => {
    const pageSource = readSupportConversationPageLibrarySource();

    expect(pageSource).toContain("setQueueFilter,");
    expect(pageSource).toContain("const setQueueSubFilter = (value: SupportQueueSubFilter) => {");
    expect(pageSource).toContain("if (isQueueControlsLocked) {\n      return;\n    }");
    expect(pageSource).toContain('setQueueStatusFilter("all");');
    expect(pageSource).toContain("setQueueFilter(value);");
    expect(pageSource).toContain('setQueueFilter("all");');
    expect(pageSource).toContain('aria-pressed={subFilter === "unread"}');
    expect(pageSource).toContain(
      'onClick={() => setQueueSubFilter(subFilter === "unread" ? "all" : "unread")}'
    );
    expect(pageSource).toContain('aria-pressed={subFilter === "unassigned"}');
    expect(pageSource).toContain(
      'onClick={() => setQueueSubFilter(subFilter === "unassigned" ? "all" : "unassigned")}'
    );
    expect(pageSource).toContain("disabled={isQueueControlsLocked}");
    expect(pageSource).toContain("const displayedInboxItems = filteredInboxItems;");
    expect(pageSource).not.toContain('setQueueSubFilter("archive")');
    expect(pageSource).not.toContain('setQueueSubFilter("waiting")');
    expect(pageSource).not.toContain('setQueueFilter("Closed")');
    expect(pageSource).not.toContain('onClick={() => setSubFilter("unassigned")}');
    expect(pageSource).not.toContain('const isArchived = item.status === "Closed";');
    expect(pageSource).not.toContain("return !item.assignedAdminId;");
  });

  it("locks support queue controls while inbox data is refreshing", () => {
    const pageSource = readSupportConversationPageLibrarySource();

    expect(pageSource).toContain(
      "const isQueueControlsLocked = !canManageSupportWorkspace || inboxQuery.isFetching;"
    );
    expect(pageSource).toContain("const requestPreviousQueuePage = () => {");
    expect(pageSource).toContain(
      "if (isQueueControlsLocked || !canGoToPreviousQueuePage) {\n      return;\n    }"
    );
    expect(pageSource).toContain("const requestNextQueuePage = () => {");
    expect(pageSource).toContain(
      "if (isQueueControlsLocked || !canGoToNextQueuePage) {\n      return;\n    }"
    );
    expect(pageSource).toContain("disabled={isQueueControlsLocked}");
    expect(pageSource).toContain("disabled={isQueueControlsLocked}");
    expect(pageSource).toContain("disabled={isQueueControlsLocked}");
    expect(pageSource).toContain("disabled={isQueueControlsLocked}");
    expect(pageSource).toContain("disabled={isQueueControlsLocked}");
    expect(pageSource).toContain("disabled={!canGoToPreviousQueuePage || isQueueControlsLocked}");
    expect(pageSource).toContain("disabled={!canGoToNextQueuePage || isQueueControlsLocked}");
    expect(pageSource).toContain("onClick={requestPreviousQueuePage}");
    expect(pageSource).toContain("onClick={requestNextQueuePage}");
    expect(pageSource).toContain('data-disabled={isQueueControlsLocked ? "true" : undefined}');
    expect(pageSource).toContain("tabIndex={isQueueControlsLocked ? -1 : undefined}");
    expect(pageSource).toMatch(/if \(isQueueControlsLocked\) {\s+return;/);
    expect(pageSource).toMatch(/if \(isQueueControlsLocked\) {\s+event\.preventDefault\(\);/);
    expect(pageSource).not.toContain("disabled={inboxQuery.isFetching}");
    expect(pageSource).not.toContain('data-disabled={inboxQuery.isFetching ? "true" : undefined}');
    expect(pageSource).not.toContain("tabIndex={inboxQuery.isFetching ? -1 : undefined}");
    expect(pageSource).not.toContain(
      "onClick={() => setQueuePage((currentPage) => Math.max(1, currentPage - 1))}"
    );
    expect(pageSource).not.toContain(
      "onClick={() => setQueuePage((currentPage) => currentPage + 1)}"
    );
  });

  it("sources support queue counters from backend aggregate metrics", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const pageSource = readSupportConversationPageLibrarySource();

    expect(controllerSource).toContain("fetchSupportInboxMetrics,");
    expect(controllerSource).toContain("queryKey: adminQueryKeys.supportInboxMetrics");
    expect(controllerSource).toContain("queryFn: ({ signal }) => fetchSupportInboxMetrics(signal)");
    expect(controllerSource).toContain("inboxMetrics: inboxMetricsQuery.data ?? null");
    expect(pageSource).toContain("const queueCount = inboxMetrics?.openConversations ?? 0;");
    expect(pageSource).toContain(
      "const incomingMessagesCount = inboxMetrics?.unreadForAdminConversations ?? 0;"
    );
    expect(pageSource).toContain(
      "const unassignedCount = inboxMetrics?.unassignedConversations ?? 0;"
    );
    expect(pageSource).not.toContain(
      'filteredInboxItems.filter((item) => item.status === "Closed").length'
    );
    expect(pageSource).not.toContain(
      "filteredInboxItems.filter((item) => item.unreadForAdmin).length"
    );
    expect(pageSource).not.toContain(
      "filteredInboxItems.filter((item) => !item.assignedAdminId).length"
    );
  });

  it("uses backend totalCount for support queue pagination footer", () => {
    const pageSource = readSupportConversationPageLibrarySource();
    const supportContentSource = readFileSync(supportContentPath, "utf8");

    expect(pageSource).toContain(
      "const inboxTotalCount = inboxQuery.data?.totalCount ?? filteredInboxItems.length;"
    );
    expect(pageSource).toContain(
      "const inboxPageSize = inboxQuery.data?.pageSize ?? displayedInboxItems.length;"
    );
    expect(pageSource).toContain("const inboxCurrentPage = inboxQuery.data?.page ?? queuePage;");
    expect(supportContentSource).toContain(
      "pageCount: (page: number, start: number, end: number, total: number) =>"
    );
    expect(supportContentSource).toContain(
      "`Страница ${page}: показано ${start}-${end} из ${total}`"
    );
    expect(supportContentSource).toContain("`Page ${page}: showing ${start}-${end} of ${total}`");
    expect(pageSource).toContain("queueLabels.pageCount(");
    expect(pageSource).toMatch(/inboxCurrentPage,\s+queueShownStart,/);
    expect(pageSource).not.toContain(
      "`Page ${queuePage}: showing ${displayedInboxItems.length} of ${filteredInboxItems.length}`"
    );
    expect(pageSource).not.toContain(
      "`Страница ${queuePage}: показано ${displayedInboxItems.length} из ${filteredInboxItems.length}`"
    );
  });

  it("routes support queue, priority, and sort controls through backend query params", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const pageSource = readSupportConversationPageLibrarySource();
    const adminQueryKeysSource = readFileSync(adminQueryKeysPath, "utf8");
    expect(pageSource).toContain("SupportQueueSubFilter");
    expect(pageSource).not.toContain('setQueueSubFilter("waiting")');
    expect(pageSource).not.toContain('setQueueFilter("waiting")');
    expect(pageSource).not.toContain('item.status === "New" || item.status === "WaitingForUser"');
    expect(pageSource).not.toContain('item.status === "New" || item.status === "InProgress"');
    expect(controllerSource).toContain(
      "const [queuePriorityFilter, setQueuePriorityFilter] = useState<"
    );
    expect(controllerSource).toContain(
      "const [queueSort, setQueueSort] = useState<SupportInboxSort>(initialQueueState.sort);"
    );
    expect(controllerSource).toContain(
      'const effectiveQueuePriority = queuePriorityFilter === "all" ? undefined : queuePriorityFilter;'
    );
    expect(controllerSource).toContain("priority: effectiveQueuePriority");
    expect(controllerSource).toContain("sort: queueSort");
    expect(controllerSource).toContain("queue: resolvedQueueFilter.queue");
    expect(controllerSource).toContain("setQueuePriorityFilter: setSupportQueuePriorityFilter");
    expect(controllerSource).toContain("setQueueSort: setSupportQueueSort");
    expect(pageSource).toContain("label: queueLabels.sortWaiting");
    expect(pageSource).toContain("queuePriorityFilter");
    expect(pageSource).toContain("setExactQueuePriorityFilter");
    expect(pageSource).toContain("queueSort");
    expect(pageSource).toContain("setExactQueueSort");
    expect(pageSource).toContain('{ value: "High", label: queueLabels.priorityHigh }');
    expect(pageSource).toContain('{ value: "waiting", label: queueLabels.sortWaiting }');
    expect(adminQueryKeysSource).toContain('options?.priority?.trim() || "all"');
    expect(adminQueryKeysSource).toContain('options?.sort?.trim() || "default"');
    expect(adminQueryKeysSource).toContain('options?.queue?.trim() || "all"');
    expect(pageSource).not.toContain(".filter((item) => item.priority");
    expect(pageSource).not.toContain(".filter((item) => item.status");
    expect(pageSource).not.toContain("queueSortBy");
    expect(pageSource).not.toContain("setQueueSortBy");
    expect(pageSource).not.toContain("left.priority");
    expect(pageSource).not.toContain("right.priority");
  });

  it("does not expose removed support-side user mutations without a live UI consumer", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();

    expect(controllerSource).not.toContain("setUserActiveMutation");
    expect(controllerSource).not.toContain("setUserPremiumMutation");
    expect(controllerSource).not.toContain("await setActive(subjectUserId, isActive);");
    expect(controllerSource).not.toContain("await setPremium(subjectUserId, isPremium);");
  });

  it("does not fetch or link admin-only user and economy context for support moderators", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const infoPanelSource = readSupportInfoPanelLibrarySource();

    expect(controllerSource).toContain(
      "enabled: Boolean(hasSession && subjectUserId && canViewSubjectUserContext),"
    );
    expect(controllerSource).toContain(
      "hasSession && subjectUserId && canViewSubjectUserContext && !isSubjectUserDeleted"
    );
    expect(infoPanelSource).toContain(
      "{canViewSubjectUserContext && recentUserPurchases.length > 0 ? ("
    );
    expect(infoPanelSource).toContain("{canViewSubjectUserContext ? (");
  });

  it("encodes support route ids before building notification and queue hrefs", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const pageSource = readSupportConversationPageLibrarySource();

    expect(controllerSource).toContain(
      "const supportConversationPathId = encodeURIComponent(conversationId);"
    );
    expect(controllerSource).toContain("href: `/${locale}/support/${supportConversationPathId}`");
    expect(pageSource).toContain(
      "const supportConversationPathId = encodeURIComponent(item.conversationId);"
    );
    expect(pageSource).toContain(
      "href={`/${locale}/support/${supportConversationPathId}${supportConversationSearchSuffix}`}"
    );
    expect(controllerSource).not.toContain("href: `/${locale}/support/${conversationId}`");
    expect(pageSource).not.toContain("href={`/${locale}/support/${item.conversationId}`}");
  });

  it("encodes support message ids before using them as DOM jump targets", () => {
    const pageSource = readSupportConversationPageLibrarySource();

    expect(pageSource).toContain("function getSupportMessageElementId(messageId: string)");
    expect(pageSource).toContain("return `message-${encodeURIComponent(messageId)}`;");
    expect(pageSource).toContain(
      "const target = document.getElementById(getSupportMessageElementId(messageId));"
    );
    expect(pageSource).toContain("id={getSupportMessageElementId(message.messageId)}");
    expect(pageSource).not.toContain("document.getElementById(`message-${messageId}`)");
    expect(pageSource).not.toContain("id={`message-${message.messageId}`}");
  });

  it("keeps close-conversation confirmations open until status mutations succeed", () => {
    const infoPanelSource = readSupportInfoPanelLibrarySource();

    expect(infoPanelSource).toContain("const confirmPendingStatusChange = async () =>");
    expect(infoPanelSource).toContain("await statusMutation.mutateAsync(pendingStatusConfirm)");
    expect(infoPanelSource).toContain("setPendingStatusConfirm(null);");
    expect(infoPanelSource).toContain(
      "if (!canMutateConversation || !pendingStatusConfirm || statusMutation.isPending)"
    );
    expect(infoPanelSource).toContain("disabled={statusMutation.isPending}");
    expect(infoPanelSource).toContain(
      "const requestStatusChange = (status: SupportConversationStatus) =>"
    );
    expect(infoPanelSource).toContain(
      "if (!canMutateConversation || statusMutation.isPending || conversation.status === status)"
    );
    expect(infoPanelSource).toContain(
      "onClick={() => requestStatusChange(primaryStatusAction.status)}"
    );
    expect(infoPanelSource).toContain("onClick={() => requestStatusChange(action.status)}");
    expect(infoPanelSource).toContain(
      "onClick={() => requestStatusChange(destructiveStatusAction.status)}"
    );
    expect(infoPanelSource).not.toContain(
      "const nextStatus = pendingStatusConfirm;\n                          setPendingStatusConfirm(null);"
    );
    expect(infoPanelSource).not.toContain("statusMutation.mutate(primaryStatusAction.status);");
    expect(infoPanelSource).not.toContain("statusMutation.mutate(action.status);");
  });

  it("clears stale close-conversation confirmations after ticket changes or status refreshes", () => {
    const infoPanelSource = readSupportInfoPanelLibrarySource();

    expect(infoPanelSource).toContain(
      "const previousConversationIdRef = useRef<string | null>(null);"
    );
    expect(infoPanelSource).toContain(
      "const previousConversationId = previousConversationIdRef.current;\n    previousConversationIdRef.current = conversation?.conversationId ?? null;"
    );
    expect(infoPanelSource).toContain("if (!pendingStatusConfirm || statusMutation.isPending)");
    expect(infoPanelSource).toContain(
      "!conversation ||\n      conversation.status === pendingStatusConfirm ||\n      (previousConversationId !== null && previousConversationId !== conversation.conversationId)"
    );
    expect(infoPanelSource).toContain("let isActive = true;");
    expect(infoPanelSource).toContain("queueMicrotask(() => {");
    expect(infoPanelSource).toContain("if (isActive) {\n          setPendingStatusConfirm(null);");
    expect(infoPanelSource).toContain("return () => {\n      isActive = false;\n    };");
  });

  it("guards support reopen status actions in handlers, not only disabled UI", () => {
    const pageSource = readSupportConversationPageLibrarySource();

    expect(pageSource).toContain("const requestReopenConversation = () =>");
    expect(pageSource).toContain(
      "!canManageSupportWorkspace ||\n      !reopenStatusAction ||\n      statusMutation.isPending ||\n      conversation?.status === reopenStatusAction.status"
    );
    expect(pageSource).toContain("statusMutation.mutate(reopenStatusAction.status);");
    expect(pageSource).toContain("onClick={requestReopenConversation}");
    expect(pageSource).not.toContain(
      "onClick={() => statusMutation.mutate(reopenStatusAction.status)}"
    );
  });

  it("guards support reply submits against read-only, pending, and empty composer states", () => {
    const pageSource = readSupportConversationPageLibrarySource();
    const supportContentSource = readFileSync(supportContentPath, "utf8");

    expect(pageSource).toContain("const submitReply = () => {");
    expect(pageSource).toContain("const isComposerBusy = isSendReplySubmitting;");
    expect(pageSource).toContain(
      "const isComposerDisabled = isConversationReadOnly || !canManageSupportWorkspace || isComposerBusy;"
    );
    expect(pageSource).toContain("if (isComposerDisabled ||");
    expect(pageSource).toContain("(!reply.trim() && !hasComposerAttachment)");
    expect(pageSource).toContain("if (!canMutateConversation) {");
    expect(pageSource).toContain("revealOwnershipComposerNotice();");
    expect(pageSource).toContain("disabled={isComposerDisabled}");
    expect(pageSource).toContain(
      'selectReplyToMessage(null);\n    setReply("");\n    resetSelectedAttachment();'
    );
    expect(pageSource).toContain("setFullscreenImage(null);");
    expect(pageSource).toContain("setPendingFullscreenAction(null);");
    expect(pageSource).toContain("setPendingAttachmentActionKey(null);");
    expect(pageSource).toContain("setHighlightedMessageId(null);");
    expect(pageSource).toContain("setIsDragging(false);");
    expect(pageSource).toContain("let isActive = true;");
    expect(pageSource).toContain("if (!isActive) {\n        return;\n      }");
    expect(pageSource).toContain("return () => {\n      isActive = false;\n    };");
    expect(pageSource).toContain(
      "[conversationId, resetSelectedAttachment, selectReplyToMessage, setReply]"
    );
    expect(pageSource).toContain(
      "className={styles.composerReplyClose}\n                              onClick={() => selectReplyToMessage(null)}\n                              disabled={isComposerDisabled}"
    );
    expect(pageSource).toContain("const messageLabels = copy.page.message;");
    expect(supportContentSource).toContain('openPhoto: "Открыть фото"');
    expect(supportContentSource).toContain('openPhoto: "Open photo"');
    expect(supportContentSource).toContain('openVideo: "Открыть видео"');
    expect(supportContentSource).toContain('openVideo: "Open video"');
    expect(supportContentSource).toContain('reply: "Ответить"');
    expect(supportContentSource).toContain('reply: "Reply"');
    expect(supportContentSource).toContain('replyTo: "Ответ на"');
    expect(supportContentSource).toContain('replyTo: "Reply to"');
    expect(supportContentSource).toContain('cancelReply: "Отменить ответ"');
    expect(supportContentSource).toContain('cancelReply: "Cancel reply"');
    expect(supportContentSource).toContain('attachFile: "Прикрепить файл"');
    expect(supportContentSource).toContain('attachFile: "Attach file"');
    expect(supportContentSource).toContain(
      'dragAndDropAttachment: "Перетащите фото или видео сюда"'
    );
    expect(supportContentSource).toContain('dragAndDropAttachment: "Drop a photo or video here"');
    expect(pageSource).toContain("SUPPORT_ATTACHMENT_ACCEPT,");
    expect(pageSource).toContain("accept={SUPPORT_ATTACHMENT_ACCEPT}");
    expect(pageSource).toContain(
      "const selectedAttachmentMediaType = selectedAttachment?.type.startsWith"
    );
    expect(pageSource).toContain('kind="video"');
    expect(pageSource).toContain("aria-label={messageLabels.openPhoto}");
    expect(pageSource).toContain("aria-label={messageLabels.openVideo}");
    expect(pageSource).toContain("title={messageLabels.reply}");
    expect(pageSource).toContain("aria-label={messageLabels.reply}");
    expect(pageSource).toContain("{messageLabels.replyTo}");
    expect(pageSource).toMatch(
      /aria-label=\{\s*message\.isRead \? messageLabels\.read : messageLabels\.sent\s*\}/
    );
    expect(pageSource).toMatch(
      /title=\{\s*message\.isRead \? messageLabels\.read : messageLabels\.sent\s*\}/
    );
    expect(pageSource).toContain("{messageLabels.jump}");
    expect(pageSource).toContain("aria-label={messageLabels.cancelReply}");
    expect(pageSource).toContain("aria-label={messageLabels.attachFile}");
    expect(pageSource).toContain(
      "<span className={styles.composerAttachLabel}>{messageLabels.attachFile}</span>"
    );
    expect(pageSource).not.toContain(
      'aria-label={locale === "ru" ? "Открыть фото" : "Open photo"}'
    );
    expect(pageSource).not.toContain('title={locale === "ru" ? "Ответить" : "Reply"}');
    expect(pageSource).not.toContain(
      'aria-label={locale === "ru" ? "Прикрепить файл" : "Attach file"}'
    );
    expect(pageSource).toContain("requestSendReply();");
    expect(pageSource).not.toContain("sendMutation.mutate();");
    expect(pageSource).not.toContain(
      "const submitReply = () => {\n    sendMutation.mutate();\n  };"
    );
  });

  it("keeps failed attachment uploads visible and retryable instead of reporting a false success", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const pageSource = readSupportConversationPageLibrarySource();

    expect(controllerSource).toContain("retrySupportAttachment,");
    expect(controllerSource).toContain("const retryAttachmentMutation = useMutation({");
    expect(controllerSource).toContain('pushSupportError(error, "retry_attachment")');
    expect(controllerSource).toContain(
      'attachmentUploadStatus?.trim().toLowerCase() !== "uploaded"'
    );
    expect(controllerSource).toContain("supportAttachmentRetryRequired");
    expect(controllerSource).toContain("const requestAttachmentRetry = useCallback(");
    expect(controllerSource).toContain("isSupportedSupportAttachmentMimeType(file.type)");
    expect(pageSource).toContain("retryAttachmentInputRef");
    expect(pageSource).toContain("retryAttachmentMessageIdRef");
    expect(pageSource).toContain("requestAttachmentRetry(messageId, file)");
    expect(pageSource).toContain("canRetryAttachment={canMutateConversation}");
    expect(pageSource).toContain("isAttachmentRetrySubmitting={isAttachmentRetrySubmitting}");
  });

  it("does not keep stale support-side subject-user mutation errors", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();

    expect(controllerSource).not.toContain("supportSubjectUserMissing");
    expect(controllerSource).not.toContain("Карточка пользователя недоступна для этого обращения.");
    expect(controllerSource).not.toContain("User context is unavailable for this conversation.");
    expect(controllerSource).not.toContain('throw new Error("support.subject_user_missing")');
  });

  it("guards older-message loads and handles their failures without an unhandled rejection", () => {
    const controllerSource = readSupportConversationControllerLibrarySource();
    const pageSource = readSupportConversationPageLibrarySource();
    const chatContentSource = readFileSync(supportChatContentPath, "utf8");
    const loadOlderStart = controllerSource.indexOf(
      "const loadOlderMessages = useCallback(async () => {"
    );
    const loadOlderEnd = controllerSource.indexOf("  useEffect(() => {", loadOlderStart);
    const loadOlderSource = controllerSource.slice(loadOlderStart, loadOlderEnd);

    expect(controllerSource).toContain(
      "const [attachmentPreview, setAttachmentPreview] = useState<"
    );
    expect(controllerSource).toContain(
      "attachmentPreview?.file === selectedAttachment ? attachmentPreview.url : null"
    );
    expect(controllerSource).toContain(
      "const attachmentPreviewUrlRef = useRef<string | null>(null);"
    );
    expect(controllerSource).toContain("const setSupportSelectedAttachment = useCallback(");
    expect(controllerSource).toContain(
      'file?.type.startsWith("image/") && !file?.type.startsWith("video/")'
    );
    expect(controllerSource).toContain("const previewUrl = URL.createObjectURL(file);");
    expect(controllerSource).toContain("attachmentPreviewUrlRef.current = previewUrl;");
    expect(controllerSource).toContain("setAttachmentPreview({ file, url: previewUrl });");
    expect(controllerSource).toContain(
      "} catch (error) {\n        if (attachmentPreviewUrlRef.current === previewUrl)"
    );
    expect(controllerSource).toContain("URL.revokeObjectURL(previewUrl);");
    expect(controllerSource).toContain("throw error;");
    expect(controllerSource).toContain("URL.revokeObjectURL(attachmentPreviewUrlRef.current);");
    expect(controllerSource).toContain("revokeAttachmentPreviewUrl();");
    expect(controllerSource).toContain("setSelectedAttachment: setSupportSelectedAttachment,");
    expect(controllerSource).not.toContain(
      "const attachmentPreviewUrl = useMemo(() => {\n    if (!selectedAttachment"
    );
    expect(controllerSource).toContain("const loadOlderMessages = useCallback(async () => {");
    expect(controllerSource).toContain(
      "const [isLoadingOlderMessages, setIsLoadingOlderMessages] = useState(false);"
    );
    expect(controllerSource).toContain(
      "if (!canManageSupportWorkspace || loadOlderAbortControllerRef.current) {\n      return;\n    }"
    );
    expect(loadOlderSource).toContain('pushSupportError(error, "support_load_older_messages");');
    expect(loadOlderSource).not.toContain("throw error;");
    expect(loadOlderSource).toContain("setIsLoadingOlderMessages(true);");
    expect(loadOlderSource).toContain("setIsLoadingOlderMessages(false);");
    expect(controllerSource).toContain("}, [conversationId]);");
    expect(pageSource).toContain("const requestOlderMessagesLoad = () => {");
    expect(pageSource).toContain(
      "if (!canManageSupportWorkspace || conversationQuery.isFetching || isLoadingOlderMessages) {\n      return;\n    }"
    );
    expect(pageSource).toContain("isLoadingOlderMessages={isLoadingOlderMessages}");
    expect(pageSource).toContain("onClick={requestOlderMessagesLoad}");
    expect(chatContentSource).toContain("isLoadingOlderMessages: boolean;");
    expect(chatContentSource).toContain("aria-busy={isLoadingOlderMessages || undefined}");
    expect(chatContentSource).toContain(
      "isLoadingOlderMessages ? text.loading : copy.page.loadPreviousMessages"
    );
    expect(controllerSource).toContain("if (markReadDebounceRef.current) {");
    expect(controllerSource).toContain("clearTimeout(markReadDebounceRef.current);");
    expect(controllerSource).toContain("markReadDebounceRef.current = null;");
    expect(controllerSource).toContain("loadOlderAbortControllerRef.current?.abort();");
    expect(controllerSource).toContain("signal: abortController.signal");
    expect(controllerSource).toContain(
      "if (abortController.signal.aborted) {\n      return;\n    }"
    );
    expect(controllerSource).toContain("optimisticAttachmentObjectUrlsRef.current.clear();");
    expect(controllerSource).toContain("const optimisticAttachmentObjectUrl = selectedAttachment");
    expect(controllerSource).toContain("optimisticAttachmentObjectUrlsRef.current.set(");
    expect(controllerSource).toContain(
      "} catch (error) {\n        if (optimisticAttachmentObjectUrl)"
    );
    expect(controllerSource).toContain(
      "optimisticAttachmentObjectUrlsRef.current.delete(optimisticMessageId);"
    );
    expect(controllerSource).toContain("URL.revokeObjectURL(optimisticAttachmentObjectUrl);");
    expect(controllerSource).toContain("},\n    []\n  );");
    expect(controllerSource).not.toContain(
      "loadOlderAbortControllerRef.current?.abort();\n      if (attachmentPreviewUrl)"
    );
    expect(controllerSource).not.toContain(
      "optimisticAttachmentObjectUrlsRef.current.clear();\n    },\n    [attachmentPreviewUrl]"
    );
  });
});
