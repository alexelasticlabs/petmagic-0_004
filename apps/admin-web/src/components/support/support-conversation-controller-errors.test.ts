import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const controllerPath = fileURLToPath(
  new URL("./use-support-conversation-controller.ts", import.meta.url)
);
const supportPagePath = fileURLToPath(new URL("./support-conversation-page.tsx", import.meta.url));
const supportInboxPagePath = fileURLToPath(new URL("./support-inbox-page.tsx", import.meta.url));
const supportInfoPanelPath = fileURLToPath(new URL("./support-info-panel.tsx", import.meta.url));
const supportStylesPath = fileURLToPath(new URL("./support-page.module.css", import.meta.url));
const selectPath = fileURLToPath(new URL("../ui/select.tsx", import.meta.url));
const adminFollowupsPath = fileURLToPath(
  new URL("../../../../../docs/admin-web-production-followups.md", import.meta.url)
);

describe("support conversation controller errors", () => {
  it("uses sanitized backend messages for support mutation failures", () => {
    const source = readFileSync(controllerPath, "utf8");

    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain("const pushSupportError = useCallback(");
    expect(source).toContain("getAdminErrorMessage(error, text.supportLoadError)");
    expect(source).toContain("pushSupportError(error)");
    expect(source).not.toContain('setToast({ type: "error", message: text.supportLoadError });');
    expect(source).not.toContain('pushSupportNotification("error", text.supportLoadError);');
  });

  it("keeps support workspace fetches and actions role-guarded at the controller layer", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const pageSource = readFileSync(supportPagePath, "utf8");
    const infoPanelSource = readFileSync(supportInfoPanelPath, "utf8");
    const selectSource = readFileSync(selectPath, "utf8");

    expect(controllerSource).toContain("const sessionUserRoles = session?.user.roles ?? [];");
    expect(controllerSource).toContain(
      'const canManageSupportWorkspace =\n    sessionUserRoles.includes("Admin") || sessionUserRoles.includes("Moderator");'
    );
    expect(controllerSource).toContain("const supportActionsForbidden =");
    expect(controllerSource).toContain(
      "const assertCanManageSupportWorkspace = useCallback(() => {"
    );
    expect(controllerSource).toContain(
      'setToast({ type: "error", message: supportActionsForbidden });'
    );
    expect(controllerSource).toContain("enabled: Boolean(session && canManageSupportWorkspace)");
    expect(controllerSource).toContain(
      "refetchInterval: session && canManageSupportWorkspace ? supportPollingIntervalMs : false"
    );
    expect(controllerSource).toContain(
      "useSupportRealtime(canManageSupportWorkspace ? session?.accessToken : undefined"
    );
    expect(controllerSource).toContain(
      "!canManageSupportWorkspace ||\n      !conversationQuery.data"
    );
    expect(controllerSource).toContain(
      "if (!canManageSupportWorkspace) {\n      return;\n    }\n\n    const currentConversation"
    );
    expect(controllerSource).toContain("if (!assertCanManageSupportWorkspace())");
    expect(controllerSource).toContain("if (!canManageSupportWorkspace) {\n        return {};");
    expect(controllerSource).toContain("canManageSupportWorkspace,");
    expect(controllerSource).toContain("sessionUserRoles,");
    expect(controllerSource).toContain("const [isSendReplyInFlight, setIsSendReplyInFlight]");
    expect(controllerSource).toContain("const sendReplyInFlightRef = useRef(false);");
    expect(controllerSource).toContain("const isSendReplySubmitting = isSendReplyInFlight || sendMutation.isPending;");
    expect(controllerSource).toContain("const requestSendReply = useCallback(() => {");
    expect(controllerSource).toContain("sendReplyInFlightRef.current ||");
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
    expect(pageSource).toContain("if (isComposerDisabled) return;");
    expect(infoPanelSource).toContain("disabled={!canManageSupportWorkspace}");
    expect(infoPanelSource).toContain(
      "disabled={!canManageSupportWorkspace || statusMutation.isPending}"
    );
    expect(infoPanelSource).toContain(
      "!canManageSupportWorkspace ||\n      statusMutation.isPending ||\n      conversation.status === status"
    );
    expect(infoPanelSource).toContain(
      "if (!canManageSupportWorkspace || pendingAttachmentOpenKey !== null)"
    );
    expect(selectSource).toContain("disabled?: boolean;");
    expect(selectSource).toContain("const isSelectDisabled = disabled || !hasOptions;");
    expect(selectSource).toContain("disabled={isSelectDisabled}");
  });

  it("keeps support queue pagination on backend query params instead of a fixed first page", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const pageSource = readFileSync(supportPagePath, "utf8");
    const inboxPageSource = readFileSync(supportInboxPagePath, "utf8");

    expect(controllerSource).toContain("const [queuePage, setQueuePage] = useState(1);");
    expect(controllerSource).toContain("setQueuePage(1);");
    expect(controllerSource).toContain("page: queuePage");
    expect(controllerSource).toContain("canGoToNextQueuePage");
    expect(controllerSource).toContain("useQuery<AdminSupportInboxPage>");
    expect(controllerSource).toContain("sortSupportQueueItems(inboxQuery.data?.items ?? [])");
    expect(controllerSource).toContain("const canGoToNextQueuePage = Boolean(inboxQuery.data?.hasMore);");
    expect(controllerSource).not.toContain("(inboxQuery.data?.length ?? 0) >= SUPPORT_INBOX_PAGE_SIZE");
    expect(pageSource).toContain("setQueuePage((currentPage) => Math.max(1, currentPage - 1))");
    expect(pageSource).toContain("setQueuePage((currentPage) => currentPage + 1)");
    expect(pageSource).toContain("disabled={!canGoToNextQueuePage || inboxQuery.isFetching}");
    expect(pageSource).toContain(
      'aria-label={locale === "ru" ? "Предыдущая страница очереди" : "Previous queue page"}'
    );
    expect(pageSource).toContain(
      'aria-label={locale === "ru" ? "Следующая страница очереди" : "Next queue page"}'
    );
    expect(pageSource).toContain(
      'title={locale === "ru" ? "Предыдущая страница очереди" : "Previous queue page"}'
    );
    expect(pageSource).toContain(
      'title={locale === "ru" ? "Следующая страница очереди" : "Next queue page"}'
    );
    expect(pageSource).toContain(
      '<CaretDownIcon\n                        className={`${styles.queuePagerIcon} ${styles.queuePagerIconPrevious}`}'
    );
    expect(pageSource).toContain(
      '<CaretDownIcon\n                        className={`${styles.queuePagerIcon} ${styles.queuePagerIconNext}`}'
    );
    expect(pageSource).not.toContain('{locale === "ru" ? "Назад" : "Previous"}');
    expect(pageSource).not.toContain('{locale === "ru" ? "Вперёд" : "Next"}');
    expect(inboxPageSource).toContain("if (selectedConversationId) {");
  });

  it("bounds support queue search and reply composer values before storing them", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(controllerSource).toContain("SUPPORT_INBOX_SEARCH_MAX_LENGTH,");
    expect(controllerSource).toContain("SUPPORT_MESSAGE_BODY_MAX_LENGTH,");
    expect(controllerSource).toContain(
      "export const SUPPORT_SEARCH_MAX_LENGTH = SUPPORT_INBOX_SEARCH_MAX_LENGTH;"
    );
    expect(controllerSource).toContain(
      "export const SUPPORT_REPLY_MAX_LENGTH = SUPPORT_MESSAGE_BODY_MAX_LENGTH;"
    );
    expect(controllerSource).toContain(
      "setRawSearchQuery(value.slice(0, SUPPORT_SEARCH_MAX_LENGTH));"
    );
    expect(controllerSource).toContain("const setSupportReply = useCallback((value: string) => {");
    expect(controllerSource).toContain("setReply(value.slice(0, SUPPORT_REPLY_MAX_LENGTH));");
    expect(controllerSource).toContain("setReply: setSupportReply,");
    expect(pageSource).toContain("maxLength={SUPPORT_SEARCH_MAX_LENGTH}");
    expect(pageSource).toContain("maxLength={SUPPORT_REPLY_MAX_LENGTH}");
    expect(pageSource).toContain(
      "setSearchQuery(event.target.value.slice(0, SUPPORT_SEARCH_MAX_LENGTH))"
    );
    expect(pageSource).toContain("setReply(event.target.value.slice(0, SUPPORT_REPLY_MAX_LENGTH))");
    expect(pageSource).not.toContain("onChange={(event) => setSearchQuery(event.target.value)}");
    expect(pageSource).not.toContain("onChange={(event) => setReply(event.target.value)}");
  });

  it("keeps route-level conversation load failures retryable", () => {
    const pageSource = readFileSync(supportPagePath, "utf8");
    const stylesSource = readFileSync(supportStylesPath, "utf8");

    expect(pageSource).toContain("conversationQuery.isError || !conversation");
    expect(pageSource).toContain(
      "if (!canManageSupportWorkspace) {\n                    return;\n                  }\n\n                  void conversationQuery.refetch().catch(() => undefined);"
    );
    expect(pageSource).toContain("void conversationQuery.refetch().catch(() => undefined)");
    expect(pageSource).toContain("disabled={!canManageSupportWorkspace || conversationQuery.isFetching}");
    expect(pageSource).toContain("{text.supportRetryAction}");
    expect(pageSource).toContain("{text.supportBackToInbox}");
    expect(pageSource).toContain("className={styles.errorActions}");
    expect(pageSource).not.toContain('style={{ display: "flex"');
    expect(stylesSource).toContain(".errorActions");
    expect(stylesSource).toContain("@media (max-width: 520px)");
  });

  it("sends exact support status filters through backend query params", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(pageSource).toContain("queueStatusFilter,");
    expect(pageSource).toContain(
      'const setExactQueueStatusFilter = (value: "all" | SupportConversationStatus) => {'
    );
    expect(pageSource).toContain('setSubFilter("all");');
    expect(pageSource).toContain('setQueueFilter("all");');
    expect(pageSource).toContain("setQueueStatusFilter(value);");
    expect(pageSource).toContain("setQueuePage(1);");
    expect(pageSource).toContain(
      'setExactQueueStatusFilter(value as "all" | SupportConversationStatus);'
    );
    expect(controllerSource).toContain('queueStatusFilter?: "all" | SupportConversationStatus;');
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

  it("routes support archive and unassigned subfilters through backend query params", () => {
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(pageSource).toContain("setQueueFilter,");
    expect(pageSource).toContain(
      'const setQueueSubFilter = (value: "all" | "unassigned" | "archive") => {'
    );
    expect(pageSource).toContain('setQueueStatusFilter("all");');
    expect(pageSource).toContain('setQueueFilter("Closed");');
    expect(pageSource).toContain('setQueueFilter("unassigned");');
    expect(pageSource).toContain('setQueueFilter("all");');
    expect(pageSource).toContain('onClick={() => setQueueSubFilter("archive")}');
    expect(pageSource).toContain('onClick={() => setQueueSubFilter("unassigned")}');
    expect(pageSource).toContain("const displayedInboxItems = filteredInboxItems;");
    expect(pageSource).not.toContain('onClick={() => setSubFilter("archive")}');
    expect(pageSource).not.toContain('onClick={() => setSubFilter("unassigned")}');
    expect(pageSource).not.toContain('const isArchived = item.status === "Closed";');
    expect(pageSource).not.toContain("return !item.assignedAdminId;");
  });

  it("sources support queue counters from backend aggregate metrics", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(controllerSource).toContain("fetchSupportInboxMetrics,");
    expect(controllerSource).toContain("queryKey: adminQueryKeys.supportInboxMetrics");
    expect(controllerSource).toContain("queryFn: ({ signal }) => fetchSupportInboxMetrics(signal)");
    expect(controllerSource).toContain("inboxMetrics: inboxMetricsQuery.data ?? null");
    expect(pageSource).toContain("const archiveCount = inboxMetrics?.closedConversations ?? 0;");
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
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(pageSource).toContain(
      "const inboxTotalCount = inboxQuery.data?.totalCount ?? filteredInboxItems.length;"
    );
    expect(pageSource).toContain("const inboxPageSize = inboxQuery.data?.pageSize ?? displayedInboxItems.length;");
    expect(pageSource).toContain("const inboxCurrentPage = inboxQuery.data?.page ?? queuePage;");
    expect(pageSource).toContain(
      "? `Страница ${inboxCurrentPage}: показано ${queueShownStart}-${queueShownEnd} из ${inboxTotalCount}`"
    );
    expect(pageSource).toContain(
      ": `Page ${inboxCurrentPage}: showing ${queueShownStart}-${queueShownEnd} of ${inboxTotalCount}`"
    );
    expect(pageSource).not.toContain(
      "`Page ${queuePage}: showing ${displayedInboxItems.length} of ${filteredInboxItems.length}`"
    );
    expect(pageSource).not.toContain(
      "`Страница ${queuePage}: показано ${displayedInboxItems.length} из ${filteredInboxItems.length}`"
    );
  });

  it("does not expose support priority and sort controls as local current-page filters", () => {
    const pageSource = readFileSync(supportPagePath, "utf8");
    const followups = readFileSync(adminFollowupsPath, "utf8");

    expect(pageSource).not.toContain('"waiting" | "unassigned"');
    expect(pageSource).not.toContain('setQueueSubFilter("waiting")');
    expect(pageSource).not.toContain('subFilter === "waiting"');
    expect(pageSource).not.toContain('item.status === "New" || item.status === "WaitingForUser"');
    expect(pageSource).not.toContain("queuePriorityFilter");
    expect(pageSource).not.toContain("setQueuePriorityFilter");
    expect(pageSource).not.toContain("queueSortBy");
    expect(pageSource).not.toContain("setQueueSortBy");
    expect(pageSource).not.toContain("left.priority");
    expect(pageSource).not.toContain("right.priority");
    expect(followups).toContain("## Support queue priority, sort, and waiting filters");
    expect(followups).toContain(
      "The backend support inbox endpoint accepts `priority`, `sort`, and repeated"
    );
    expect(followups).toContain(
      "Re-enable priority and sort controls by passing backend query params"
    );
  });

  it("does not expose removed support-side user mutations without a live UI consumer", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");

    expect(controllerSource).not.toContain("setUserActiveMutation");
    expect(controllerSource).not.toContain("setUserPremiumMutation");
    expect(controllerSource).not.toContain("await setActive(subjectUserId, isActive);");
    expect(controllerSource).not.toContain("await setPremium(subjectUserId, isPremium);");
  });

  it("does not fetch or link admin-only user and economy context for support moderators", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const infoPanelSource = readFileSync(supportInfoPanelPath, "utf8");

    expect(controllerSource).toContain(
      "enabled: Boolean(session && subjectUserId && canViewSubjectUserContext),"
    );
    expect(controllerSource).toContain(
      "session && subjectUserId && canViewSubjectUserContext && !isSubjectUserDeleted"
    );
    expect(infoPanelSource).toContain(
      "{canViewSubjectUserContext && recentUserPurchases.length > 0 ? ("
    );
    expect(infoPanelSource).toContain("{canViewSubjectUserContext ? (");
  });

  it("encodes support route ids before building notification and queue hrefs", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(controllerSource).toContain(
      "const supportConversationPathId = encodeURIComponent(conversationId);"
    );
    expect(controllerSource).toContain("href: `/${locale}/support/${supportConversationPathId}`");
    expect(pageSource).toContain(
      "const supportConversationPathId = encodeURIComponent(item.conversationId);"
    );
    expect(pageSource).toContain("href={`/${locale}/support/${supportConversationPathId}`}");
    expect(controllerSource).not.toContain("href: `/${locale}/support/${conversationId}`");
    expect(pageSource).not.toContain("href={`/${locale}/support/${item.conversationId}`}");
  });

  it("encodes support message ids before using them as DOM jump targets", () => {
    const pageSource = readFileSync(supportPagePath, "utf8");

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
    const infoPanelSource = readFileSync(supportInfoPanelPath, "utf8");

    expect(infoPanelSource).toContain("const confirmPendingStatusChange = async () =>");
    expect(infoPanelSource).toContain("await statusMutation.mutateAsync(pendingStatusConfirm)");
    expect(infoPanelSource).toContain("setPendingStatusConfirm(null);");
    expect(infoPanelSource).toContain(
      "if (!canManageSupportWorkspace || !pendingStatusConfirm || statusMutation.isPending)"
    );
    expect(infoPanelSource).toContain("const requestStatusChange = (status: SupportConversationStatus) =>");
    expect(infoPanelSource).toContain(
      "!canManageSupportWorkspace ||\n      statusMutation.isPending ||\n      conversation.status === status"
    );
    expect(infoPanelSource).toContain("onClick={() => requestStatusChange(primaryStatusAction.status)}");
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

  it("guards support reopen status actions in handlers, not only disabled UI", () => {
    const pageSource = readFileSync(supportPagePath, "utf8");

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
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(pageSource).toContain("const submitReply = () => {");
    expect(pageSource).toContain("const isComposerBusy = isSendReplySubmitting;");
    expect(pageSource).toContain(
      "const isComposerDisabled = isConversationReadOnly || !canManageSupportWorkspace || isComposerBusy;"
    );
    expect(pageSource).toContain("if (isComposerDisabled ||");
    expect(pageSource).toContain("(!reply.trim() && !hasComposerAttachment)");
    expect(pageSource).toContain("disabled={isComposerDisabled}");
    expect(pageSource).toContain(
      "className={styles.composerReplyClose}\n                              onClick={() => selectReplyToMessage(null)}\n                              disabled={isComposerDisabled}"
    );
    expect(pageSource).toContain("requestSendReply();");
    expect(pageSource).not.toContain("sendMutation.mutate();");
    expect(pageSource).not.toContain(
      "const submitReply = () => {\n    sendMutation.mutate();\n  };"
    );
  });

  it("does not keep stale support-side subject-user mutation errors", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");

    expect(controllerSource).not.toContain("supportSubjectUserMissing");
    expect(controllerSource).not.toContain("Карточка пользователя недоступна для этого обращения.");
    expect(controllerSource).not.toContain("User context is unavailable for this conversation.");
    expect(controllerSource).not.toContain('throw new Error("support.subject_user_missing")');
  });

  it("does not abort older-message loads or clear optimistic attachment URLs on preview changes", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(controllerSource).toContain("}, [attachmentPreviewUrl]);");
    expect(controllerSource).toContain("const loadOlderMessages = useCallback(async () => {");
    expect(controllerSource).toContain("if (!canManageSupportWorkspace) {\n      return;\n    }");
    expect(pageSource).toContain(
      "if (!canManageSupportWorkspace) {\n                                return;\n                              }\n\n                              void loadOlderMessages();"
    );
    expect(pageSource).toContain(
      "disabled={!canManageSupportWorkspace || conversationQuery.isFetching}"
    );
    expect(controllerSource).toContain("if (markReadDebounceRef.current) {");
    expect(controllerSource).toContain("clearTimeout(markReadDebounceRef.current);");
    expect(controllerSource).toContain("markReadDebounceRef.current = null;");
    expect(controllerSource).toContain("loadOlderAbortControllerRef.current?.abort();");
    expect(controllerSource).toContain("optimisticAttachmentObjectUrlsRef.current.clear();");
    expect(controllerSource).toContain("},\n    []\n  );");
    expect(controllerSource).not.toContain(
      "loadOlderAbortControllerRef.current?.abort();\n      if (attachmentPreviewUrl)"
    );
    expect(controllerSource).not.toContain(
      "optimisticAttachmentObjectUrlsRef.current.clear();\n    },\n    [attachmentPreviewUrl]"
    );
  });
});
