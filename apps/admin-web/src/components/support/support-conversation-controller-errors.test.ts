import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const controllerPath = fileURLToPath(
  new URL("./use-support-conversation-controller.ts", import.meta.url)
);
const supportPagePath = fileURLToPath(new URL("./support-conversation-page.tsx", import.meta.url));
const supportInboxPagePath = fileURLToPath(new URL("./support-inbox-page.tsx", import.meta.url));
const supportSidePanelPath = fileURLToPath(
  new URL("./support-conversation-side-panel.tsx", import.meta.url)
);
const supportInfoPanelPath = fileURLToPath(new URL("./support-info-panel.tsx", import.meta.url));
const supportUiPrimitivesPath = fileURLToPath(
  new URL("./support-conversation-ui-primitives.tsx", import.meta.url)
);
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
    const sidePanelSource = readFileSync(supportSidePanelPath, "utf8");
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
    expect(pageSource).toContain(
      "const isComposerDisabled = isConversationReadOnly || !canManageSupportWorkspace;"
    );
    expect(pageSource).toContain("!canManageSupportWorkspace ||\n      sendMutation.isPending");
    expect(pageSource).toContain("if (isComposerDisabled) return;");
    expect(sidePanelSource).toContain("if (!canManageSupportWorkspace) {\n      return;");
    expect(sidePanelSource).toContain(
      "disabled={!canManageSupportWorkspace || statusMutation.isPending}"
    );
    expect(infoPanelSource).toContain("disabled={!canManageSupportWorkspace}");
    expect(infoPanelSource).toContain(
      "disabled={!canManageSupportWorkspace || statusMutation.isPending}"
    );
    expect(selectSource).toContain("disabled?: boolean;");
    expect(selectSource).toContain("disabled={disabled}");
  });

  it("keeps support queue pagination on backend query params instead of a fixed first page", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const pageSource = readFileSync(supportPagePath, "utf8");
    const inboxPageSource = readFileSync(supportInboxPagePath, "utf8");

    expect(controllerSource).toContain("const [queuePage, setQueuePage] = useState(1);");
    expect(controllerSource).toContain("setQueuePage(1);");
    expect(controllerSource).toContain("page: queuePage");
    expect(controllerSource).toContain("canGoToNextQueuePage");
    expect(pageSource).toContain("setQueuePage((currentPage) => Math.max(1, currentPage - 1))");
    expect(pageSource).toContain("setQueuePage((currentPage) => currentPage + 1)");
    expect(pageSource).toContain("disabled={!canGoToNextQueuePage || inboxQuery.isFetching}");
    expect(inboxPageSource).toContain("if (selectedConversationId) {");
  });

  it("keeps route-level conversation load failures retryable", () => {
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(pageSource).toContain("conversationQuery.isError || !conversation");
    expect(pageSource).toContain("void conversationQuery.refetch().catch(() => undefined)");
    expect(pageSource).toContain("disabled={conversationQuery.isFetching}");
    expect(pageSource).toContain("{text.supportRetryAction}");
    expect(pageSource).toContain("{text.supportBackToInbox}");
  });

  it("sends exact support status filters through backend query params", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(pageSource).toContain("queueStatusFilter,");
    expect(pageSource).toContain(
      'setQueueStatusFilter(value as "all" | SupportConversationStatus);'
    );
    expect(pageSource).toContain("setQueuePage(1);");
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
      'const setQueueSubFilter = (value: "all" | "waiting" | "unassigned" | "archive") => {'
    );
    expect(pageSource).toContain('setQueueStatusFilter("all");');
    expect(pageSource).toContain('setQueueFilter("Closed");');
    expect(pageSource).toContain('setQueueFilter("unassigned");');
    expect(pageSource).toContain('setQueueFilter("all");');
    expect(pageSource).toContain('onClick={() => setQueueSubFilter("archive")}');
    expect(pageSource).toContain('onClick={() => setQueueSubFilter("unassigned")}');
    expect(pageSource).not.toContain('onClick={() => setSubFilter("archive")}');
    expect(pageSource).not.toContain('onClick={() => setSubFilter("unassigned")}');
  });

  it("does not expose backend-unsupported support priority and sort controls as local queue filters", () => {
    const pageSource = readFileSync(supportPagePath, "utf8");
    const followups = readFileSync(adminFollowupsPath, "utf8");

    expect(pageSource).not.toContain("queuePriorityFilter");
    expect(pageSource).not.toContain("setQueuePriorityFilter");
    expect(pageSource).not.toContain("queueSortBy");
    expect(pageSource).not.toContain("setQueueSortBy");
    expect(pageSource).not.toContain("left.priority");
    expect(pageSource).not.toContain("right.priority");
    expect(followups).toContain("## Support queue priority, sort, and waiting filters");
    expect(followups).toContain("Add `priority`, `sort`, and multi-status support");
    expect(followups).toContain(
      "Re-enable priority and sort controls by passing backend query params"
    );
  });

  it("keeps support user action confirmations open until backend mutations succeed", () => {
    const source = readFileSync(supportSidePanelPath, "utf8");

    expect(source).toContain("const confirmPendingUserAction = async () =>");
    expect(source).toContain("await setUserActiveMutation.mutateAsync");
    expect(source).toContain("await setUserPremiumMutation.mutateAsync");
    expect(source).toContain("setPendingUserAction(null);");
    expect(source).not.toContain(
      "const action = pendingUserAction;\n    setPendingUserAction(null);"
    );
  });

  it("hides support user-management dangerous actions from non-admin roles", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const sidePanelSource = readFileSync(supportSidePanelPath, "utf8");

    expect(controllerSource).toContain("sessionUserRoles,");
    expect(controllerSource).toContain(
      'const canViewSubjectUserContext = sessionUserRoles.includes("Admin");'
    );
    expect(controllerSource).toContain("canViewSubjectUserContext,");
    expect(sidePanelSource).toContain(
      'const canManageSubjectUser = canViewSubjectUserContext && sessionUserRoles.includes("Admin");'
    );
    expect(sidePanelSource).toContain("{canManageSubjectUser ? (");
    expect(sidePanelSource).not.toContain('roles.includes("Moderator")');
  });

  it("invalidates shared users cache after support-side user mutations", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const matches =
      controllerSource.match(
        /queryClient\.invalidateQueries\({ queryKey: adminQueryKeys\.usersRoot }\)/g
      ) ?? [];

    expect(matches.length).toBeGreaterThanOrEqual(2);
    expect(controllerSource).toContain("await setActive(subjectUserId, isActive);");
    expect(controllerSource).toContain("await setPremium(subjectUserId, isPremium);");
  });

  it("does not fetch or link admin-only user and economy context for support moderators", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");
    const sidePanelSource = readFileSync(supportSidePanelPath, "utf8");
    const infoPanelSource = readFileSync(supportInfoPanelPath, "utf8");

    expect(controllerSource).toContain(
      "enabled: Boolean(session && subjectUserId && canViewSubjectUserContext),"
    );
    expect(controllerSource).toContain(
      "session && subjectUserId && canViewSubjectUserContext && !isSubjectUserDeleted"
    );
    expect(sidePanelSource).toContain("{canViewSubjectUserContext ? (");
    expect(sidePanelSource).toContain(
      "<Link href={`/${locale}/economy`} className={styles.spLinkBtn}>"
    );
    expect(sidePanelSource).toContain(': "Profile unavailable"');
    expect(infoPanelSource).toContain(
      "{canViewSubjectUserContext && recentUserPurchases.length > 0 ? ("
    );
    expect(infoPanelSource).toContain("{canViewSubjectUserContext ? (");
  });

  it("keeps close-conversation confirmations open until status mutations succeed", () => {
    const sidePanelSource = readFileSync(supportSidePanelPath, "utf8");
    const infoPanelSource = readFileSync(supportInfoPanelPath, "utf8");

    expect(sidePanelSource).toContain("const confirmResolveConversation = async () =>");
    expect(sidePanelSource).toContain(
      "await statusMutation.mutateAsync(primaryStatusAction.status)"
    );
    expect(sidePanelSource).toContain("setShowResolveConfirm(false);");
    expect(sidePanelSource).toContain(
      "if (!canManageSupportWorkspace || !primaryStatusAction || statusMutation.isPending)"
    );
    expect(sidePanelSource).not.toContain(
      "setShowResolveConfirm(false);\n                    if (primaryStatusAction) statusMutation.mutate(primaryStatusAction.status);"
    );

    expect(infoPanelSource).toContain("const confirmPendingStatusChange = async () =>");
    expect(infoPanelSource).toContain("await statusMutation.mutateAsync(pendingStatusConfirm)");
    expect(infoPanelSource).toContain("setPendingStatusConfirm(null);");
    expect(infoPanelSource).toContain(
      "if (!canManageSupportWorkspace || !pendingStatusConfirm || statusMutation.isPending)"
    );
    expect(infoPanelSource).not.toContain(
      "const nextStatus = pendingStatusConfirm;\n                          setPendingStatusConfirm(null);"
    );
  });

  it("disables support context retries while refetching and swallows manual retry failures", () => {
    const sidePanelSource = readFileSync(supportSidePanelPath, "utf8");
    const primitivesSource = readFileSync(supportUiPrimitivesPath, "utf8");

    expect(primitivesSource).toContain("isRetrying?: boolean;");
    expect(primitivesSource).toContain("isRetrying = false");
    expect(primitivesSource).toContain("disabled={isRetrying}");
    expect(sidePanelSource).toContain("analyticsQuery.isFetching ||");
    expect(sidePanelSource).toContain("purchasesQuery.isFetching ||");
    expect(sidePanelSource).toContain("subscriptionQuery.isFetching");
    expect(sidePanelSource).toContain("]).catch(() => undefined);");
  });

  it("guards support reply submits against read-only, pending, and empty composer states", () => {
    const pageSource = readFileSync(supportPagePath, "utf8");

    expect(pageSource).toContain("const submitReply = () => {");
    expect(pageSource).toContain("isConversationReadOnly ||\n      !canManageSupportWorkspace ||");
    expect(pageSource).toContain(
      "const isComposerDisabled = isConversationReadOnly || !canManageSupportWorkspace;"
    );
    expect(pageSource).toContain("(!reply.trim() && !hasComposerAttachment)");
    expect(pageSource).toContain("sendMutation.mutate();");
    expect(pageSource).not.toContain(
      "const submitReply = () => {\n    sendMutation.mutate();\n  };"
    );
  });

  it("does not abort older-message loads or clear optimistic attachment URLs on preview changes", () => {
    const controllerSource = readFileSync(controllerPath, "utf8");

    expect(controllerSource).toContain("}, [attachmentPreviewUrl]);");
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
