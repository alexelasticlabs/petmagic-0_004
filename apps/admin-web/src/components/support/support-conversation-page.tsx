"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useId, useMemo, useRef, useState } from "react";

import { AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import { useAdminUrlStateSyncGuard } from "@/components/admin/use-admin-url-state-sync-guard";
import { SupportConversationChatPane } from "@/components/support/support-conversation-chat-pane";
import {
  buildSupportQueueSearchParams,
  readSupportQueueUrlState,
  type SupportQueueSubFilter,
} from "@/components/support/support-conversation-controller.helpers";
import { SupportConversationDetailsDrawer } from "@/components/support/support-conversation-details-drawer";
import { SupportConversationFullscreenViewer } from "@/components/support/support-conversation-fullscreen-viewer";
import { groupSupportConversationFeed } from "@/components/support/support-conversation-helpers";
import { useSupportConversationMediaActions } from "@/components/support/support-conversation-media-actions";
import {
  type FullscreenImage,
  type SupportConversationPageProps,
  type SupportMessage,
} from "@/components/support/support-conversation-page.types";
import { SupportConversationQueuePane } from "@/components/support/support-conversation-queue-pane";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import { SupportInfoPanel } from "@/components/support/support-info-panel";
import styles from "@/components/support/support-page.module.css";
import { statusHint } from "@/components/support/support-status-helpers";
import {
  SUPPORT_REPLY_MAX_LENGTH,
  SUPPORT_SEARCH_MAX_LENGTH,
  useSupportConversationController,
} from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import type {
  SupportConversationPriority,
  SupportConversationStatus,
  SupportInboxSort,
} from "@/lib/api-client";

export function SupportConversationPage({
  locale,
  conversationId,
  navigationMode = "route",
  onConversationSelect,
  initialQueueState: providedInitialQueueState,
}: SupportConversationPageProps) {
  const copy = useMemo(() => getSupportConversationCopy(locale), [locale]);
  const pathname = usePathname();
  const router = useRouter();
  const searchParams = useSearchParams();
  const [initialQueueState] = useState(
    () => providedInitialQueueState ?? readSupportQueueUrlState(searchParams)
  );
  const [fullscreenImage, setFullscreenImage] = useState<FullscreenImage | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [highlightedMessageId, setHighlightedMessageId] = useState<string | null>(null);
  const [subFilter, setSubFilter] = useState<SupportQueueSubFilter>(initialQueueState.subFilter);
  const [queueStatusFilter, setQueueStatusFilter] = useState<"all" | SupportConversationStatus>(
    initialQueueState.status
  );
  const [pendingAttachmentActionKey, setPendingAttachmentActionKey] = useState<string | null>(null);
  const [pendingFullscreenAction, setPendingFullscreenAction] = useState<
    "download" | "share" | "open" | null
  >(null);
  const [isSupportDetailsDrawerMode, setIsSupportDetailsDrawerMode] = useState(false);
  const [isSupportDetailsDrawerOpen, setIsSupportDetailsDrawerOpen] = useState(false);
  const [claimRequestId, setClaimRequestId] = useState(0);
  const [isOwnershipComposerNoticeVisible, setIsOwnershipComposerNoticeVisible] = useState(false);
  const supportDetailsDrawerId = useId();
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const messageHighlightTimerRef = useRef<number | null>(null);
  const fullscreenActionAbortControllerRef = useRef<AbortController | null>(null);
  const attachmentActionAbortControllerRef = useRef<AbortController | null>(null);
  const controller = useSupportConversationController({
    locale,
    conversationId,
    queueStatusFilter,
    initialQueueState,
  });
  const {
    attachmentInputRef,
    attachmentPreviewUrl,
    composerPlaceholder,
    composerValue,
    conversation,
    conversationQuery,
    conversationSla,
    debouncedSearchQuery,
    filteredInboxItems,
    canManageSupportWorkspace,
    canMutateConversation,
    canGoToNextQueuePage,
    canGoToPreviousQueuePage,
    hasComposerAttachment,
    inboxMetrics,
    inboxQuery,
    isAttachmentRetrySubmitting,
    isLoadingOlderMessages,
    isSendReplySubmitting,
    loadOlderMessages,
    primaryStatusAction,
    queuePriorityFilter,
    queueSort,
    reply,
    replyToMessage,
    replyToPreview,
    requestAttachmentRetry,
    queuePage,
    requestSendReply,
    resetSelectedAttachment,
    searchQuery,
    secondaryStatusActions,
    selectedAttachment,
    sessionUserRoles,
    selectReplyToMessage,
    setMessagesViewportVisible,
    setReply,
    setQueueFilter,
    setQueuePage,
    setQueuePriorityFilter,
    setQueueSort,
    setSearchQuery,
    setActiveSidePanelTab,
    setSelectedAttachment,
    statusMutation,
    text,
    toast,
    userEmailDisplay,
    userDisplayName,
  } = controller;

  const currentSearchParams = searchParams.toString();
  const { consumeUrlStateApplication, markUrlStateWritten } = useAdminUrlStateSyncGuard({
    currentSearch: currentSearchParams,
    applyUrlState: (nextSearchParams) => {
      const nextQueueState = readSupportQueueUrlState(nextSearchParams);
      setSubFilter(nextQueueState.subFilter);
      setQueueStatusFilter(nextQueueState.status);
      setQueueFilter(nextQueueState.subFilter);
      setQueuePriorityFilter(nextQueueState.priority);
      setQueueSort(nextQueueState.sort);
      setSearchQuery(nextQueueState.search);
      setQueuePage(nextQueueState.page);
    },
  });
  const currentQueueUrlState = readSupportQueueUrlState(searchParams);
  const isSupportUrlStatePending =
    subFilter !== currentQueueUrlState.subFilter ||
    queueStatusFilter !== currentQueueUrlState.status ||
    queuePriorityFilter !== currentQueueUrlState.priority ||
    queueSort !== currentQueueUrlState.sort ||
    searchQuery.trim() !== currentQueueUrlState.search ||
    debouncedSearchQuery !== currentQueueUrlState.search ||
    queuePage !== currentQueueUrlState.page;
  const queueSearchParams = buildSupportQueueSearchParams(
    {
      subFilter,
      status: queueStatusFilter,
      priority: queuePriorityFilter,
      sort: queueSort,
      search: debouncedSearchQuery,
      page: queuePage,
    },
    currentSearchParams
  );
  const supportRouteSearchSuffix = queueSearchParams ? `?${queueSearchParams}` : "";

  useEffect(() => {
    if (consumeUrlStateApplication(isSupportUrlStatePending)) {
      return;
    }

    if (queueSearchParams === currentSearchParams) {
      return;
    }

    markUrlStateWritten(queueSearchParams);
    router.replace(`${pathname}${supportRouteSearchSuffix}`, { scroll: false });
  }, [
    consumeUrlStateApplication,
    currentSearchParams,
    isSupportUrlStatePending,
    markUrlStateWritten,
    pathname,
    queueSearchParams,
    router,
    supportRouteSearchSuffix,
  ]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    const media = window.matchMedia("(max-width: 1320px)");
    const syncDrawerMode = () => {
      setIsSupportDetailsDrawerMode(media.matches);
      if (!media.matches) {
        setIsSupportDetailsDrawerOpen(false);
      }
    };

    syncDrawerMode();
    media.addEventListener("change", syncDrawerMode);
    return () => media.removeEventListener("change", syncDrawerMode);
  }, []);

  const isConversationReadOnly = conversation?.isReadOnly ?? false;
  const isComposerBusy = isSendReplySubmitting;
  const isComposerDisabled = isConversationReadOnly || !canManageSupportWorkspace || isComposerBusy;
  const isConversationClosed = conversation?.status === "Closed";
  const canClaimConversation =
    Boolean(conversation) &&
    !conversation?.assignedAdminId &&
    canManageSupportWorkspace &&
    !isConversationReadOnly;
  const requestClaimConversation = () => {
    if (!canClaimConversation) {
      return;
    }

    setActiveSidePanelTab("user");
    if (isSupportDetailsDrawerMode) {
      setIsSupportDetailsDrawerOpen(true);
    }
    setClaimRequestId((current) => current + 1);
  };

  const revealOwnershipComposerNotice = () => {
    if (!isConversationReadOnly && canManageSupportWorkspace && !canMutateConversation) {
      setIsOwnershipComposerNoticeVisible(true);
    }
  };
  const isQueueControlsLocked = !canManageSupportWorkspace || inboxQuery.isFetching;
  const setQueueSubFilter = (value: SupportQueueSubFilter) => {
    if (isQueueControlsLocked) {
      return;
    }

    setSubFilter(value);
    setQueueStatusFilter("all");
    setQueueFilter(value);
    setQueuePage(1);
  };
  const setExactQueueStatusFilter = (value: "all" | SupportConversationStatus) => {
    if (isQueueControlsLocked) {
      return;
    }

    setSubFilter("all");
    setQueueFilter("all");
    setQueueStatusFilter(value);
    setQueuePage(1);
  };
  const setExactQueuePriorityFilter = (value: "all" | SupportConversationPriority) => {
    if (isQueueControlsLocked) {
      return;
    }

    setQueuePriorityFilter(value);
  };
  const setExactQueueSort = (value: SupportInboxSort) => {
    if (isQueueControlsLocked) {
      return;
    }

    setQueueSort(value);
  };
  const requestPreviousQueuePage = () => {
    if (isQueueControlsLocked || !canGoToPreviousQueuePage) {
      return;
    }

    setQueuePage((currentPage) => Math.max(1, currentPage - 1));
  };
  const requestNextQueuePage = () => {
    if (isQueueControlsLocked || !canGoToNextQueuePage) {
      return;
    }

    setQueuePage((currentPage) => currentPage + 1);
  };
  const requestConversationRetry = () => {
    if (!canManageSupportWorkspace || conversationQuery.isFetching) {
      return;
    }

    void conversationQuery.refetch().catch(() => undefined);
  };
  const requestInboxRetry = () => {
    if (isQueueControlsLocked) {
      return;
    }

    void inboxQuery.refetch().catch(() => undefined);
  };
  const requestOlderMessagesLoad = () => {
    if (!canManageSupportWorkspace || conversationQuery.isFetching || isLoadingOlderMessages) {
      return;
    }

    void loadOlderMessages();
  };

  const queueCount = inboxMetrics?.openConversations ?? 0;
  const incomingMessagesCount = inboxMetrics?.unreadForAdminConversations ?? 0;
  const unassignedCount = inboxMetrics?.unassignedConversations ?? 0;
  const displayedInboxItems = filteredInboxItems;
  const inboxTotalCount = inboxQuery.data?.totalCount ?? filteredInboxItems.length;
  const inboxPageSize = inboxQuery.data?.pageSize ?? displayedInboxItems.length;
  const inboxCurrentPage = inboxQuery.data?.page ?? queuePage;
  const queueShownStart = inboxTotalCount > 0 ? (inboxCurrentPage - 1) * inboxPageSize + 1 : 0;
  const queueShownEnd =
    inboxTotalCount > 0
      ? Math.min(inboxTotalCount, queueShownStart + displayedInboxItems.length - 1)
      : 0;
  const reopenStatusAction =
    primaryStatusAction?.status === "InProgress"
      ? primaryStatusAction
      : (secondaryStatusActions.find((action) => action.status === "InProgress") ?? null);
  const readOnlyComposerTitle = isConversationClosed
    ? copy.page.closedConversationReadonly
    : !canMutateConversation
      ? copy.controller.ownershipRequired
      : statusHint(conversation?.status ?? "Closed", text);
  const imageViewerLabels = copy.page.imageViewer;
  const queueLabels = copy.page.queue;
  const messageLabels = copy.page.message;
  const {
    closeFullscreenImage,
    openFullscreenImageInNewTab,
    renderAttachmentTile,
    renderReplyThumbnail,
    replyComposerAttachment,
    replyComposerPreview,
    saveFullscreenImage,
    shareFullscreenImage,
    startReplyToMessage,
  } = useSupportConversationMediaActions({
    attachmentActionAbortControllerRef,
    canManageSupportWorkspace,
    copy,
    fullscreenActionAbortControllerRef,
    fullscreenImage,
    imageViewerLabels,
    locale,
    messageLabels,
    pendingAttachmentActionKey,
    pendingFullscreenAction,
    replyToMessage,
    replyToPreview,
    selectReplyToMessage,
    setFullscreenImage,
    setPendingAttachmentActionKey,
    setPendingFullscreenAction,
    text,
  });

  const groupedConversationFeed = useMemo(
    () =>
      conversation
        ? groupSupportConversationFeed(conversation, {
            today: text.supportTodayLabel,
            yesterday: text.supportYesterdayLabel,
            earlier: text.supportEarlierLabel,
            ticketCreated: text.supportSystemTicketCreated,
            ticketResolved: text.supportSystemTicketResolved,
            ticketReopened: text.supportSystemTicketReopened,
            ticketClosed: text.supportSystemTicketClosed,
            ticketClosedByUser: text.supportSystemTicketClosedByUser,
            ticketClosedByOperator: text.supportSystemTicketClosedByOperator,
          })
        : [],
    [
      conversation,
      text.supportEarlierLabel,
      text.supportSystemTicketClosed,
      text.supportSystemTicketClosedByOperator,
      text.supportSystemTicketClosedByUser,
      text.supportSystemTicketCreated,
      text.supportSystemTicketReopened,
      text.supportSystemTicketResolved,
      text.supportTodayLabel,
      text.supportYesterdayLabel,
    ]
  );

  const messagesById = useMemo(() => {
    if (!conversation) {
      return new Map<string, SupportMessage>();
    }

    return new Map(conversation.messages.map((message) => [message.messageId, message]));
  }, [conversation]);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: "smooth" });
    }
  }, [conversation?.messages.length]);

  // Track whether the latest messages are actually inside the viewport so the
  // controller only marks the conversation read when the operator can see them.
  useEffect(() => {
    const node = messagesEndRef.current;
    if (!node || typeof IntersectionObserver === "undefined") {
      setMessagesViewportVisible(true);
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        setMessagesViewportVisible(entries.some((entry) => entry.isIntersecting));
      },
      { threshold: 0.1 }
    );

    observer.observe(node);
    return () => {
      observer.disconnect();
      setMessagesViewportVisible(false);
    };
  }, [conversationId, conversation?.messages.length, setMessagesViewportVisible]);

  useEffect(() => {
    selectReplyToMessage(null);
    setReply("");
    resetSelectedAttachment();
  }, [conversationId, resetSelectedAttachment, selectReplyToMessage, setReply]);

  useEffect(() => {
    let isActive = true;
    fullscreenActionAbortControllerRef.current?.abort();
    fullscreenActionAbortControllerRef.current = null;
    attachmentActionAbortControllerRef.current?.abort();
    attachmentActionAbortControllerRef.current = null;

    queueMicrotask(() => {
      if (!isActive) {
        return;
      }

      setFullscreenImage(null);
      setPendingFullscreenAction(null);
      setPendingAttachmentActionKey(null);
      setHighlightedMessageId(null);
      setIsDragging(false);
      setIsOwnershipComposerNoticeVisible(false);
    });

    return () => {
      isActive = false;
    };
  }, [conversationId]);

  const submitReply = () => {
    if (isComposerDisabled || (!reply.trim() && !hasComposerAttachment)) {
      return;
    }

    if (!canMutateConversation) {
      revealOwnershipComposerNotice();
      return;
    }

    requestSendReply();
  };

  const requestReopenConversation = () => {
    if (
      !canManageSupportWorkspace ||
      !reopenStatusAction ||
      statusMutation.isPending ||
      conversation?.status === reopenStatusAction.status
    ) {
      return;
    }

    statusMutation.mutate(reopenStatusAction.status);
  };

  // Keyboard shortcut: "/" focuses the inbox search input
  useEffect(() => {
    const handleGlobalKeyDown = (event: KeyboardEvent) => {
      const tag = (event.target as HTMLElement).tagName;
      if (
        event.key === "/" &&
        !fullscreenImage &&
        tag !== "INPUT" &&
        tag !== "TEXTAREA" &&
        !event.metaKey &&
        !event.ctrlKey
      ) {
        event.preventDefault();
        searchInputRef.current?.focus();
      }
    };
    window.addEventListener("keydown", handleGlobalKeyDown);
    return () => window.removeEventListener("keydown", handleGlobalKeyDown);
  }, [fullscreenImage]);

  useEffect(() => {
    if (!fullscreenImage || typeof document === "undefined") {
      return;
    }

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        closeFullscreenImage();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [closeFullscreenImage, fullscreenImage]);

  useEffect(
    () => () => {
      if (messageHighlightTimerRef.current !== null) {
        window.clearTimeout(messageHighlightTimerRef.current);
      }
      fullscreenActionAbortControllerRef.current?.abort();
      attachmentActionAbortControllerRef.current?.abort();
    },
    []
  );

  const highlightMessage = (messageId: string) => {
    setHighlightedMessageId(messageId);
    if (messageHighlightTimerRef.current !== null) {
      window.clearTimeout(messageHighlightTimerRef.current);
    }

    messageHighlightTimerRef.current = window.setTimeout(() => {
      setHighlightedMessageId((current) => (current === messageId ? null : current));
      messageHighlightTimerRef.current = null;
    }, 1500);
  };

  const jumpToMessage = (messageId: string) => {
    const target = document.getElementById(getSupportMessageElementId(messageId));
    if (!target) {
      return;
    }

    target.scrollIntoView({ behavior: "smooth", block: "center" });
    highlightMessage(messageId);
  };
  return (
    <AdminPage className={styles.page}>
      {toast ? <Toast type={toast.type} message={toast.message} /> : null}

      {conversationQuery.isLoading ? (
        <AdminStateCard
          tone="info"
          title={text.loading}
          description={text.supportConversationDescription}
        />
      ) : conversationQuery.isError || !conversation ? (
        <AdminStateCard
          tone="danger"
          title={text.supportLoadError}
          action={
            <div className={styles.errorActions}>
              <Button
                variant="secondary"
                onClick={requestConversationRetry}
                disabled={!canManageSupportWorkspace || conversationQuery.isFetching}
              >
                {text.supportRetryAction}
              </Button>
              <Link
                href={`/${locale}/support${supportRouteSearchSuffix}`}
                className="ui-button ui-button--secondary ui-button--md"
              >
                {text.supportBackToInbox}
              </Link>
            </div>
          }
        />
      ) : (
        <>
          <div className={`${styles.workspace} ${styles.workspaceFullView}`}>
            <SupportConversationQueuePane
              canManageSupportWorkspace={canManageSupportWorkspace}
              canGoToNextQueuePage={canGoToNextQueuePage}
              canGoToPreviousQueuePage={canGoToPreviousQueuePage}
              conversationId={conversationId}
              deletedUserName={copy.shared.deletedUserName}
              displayedInboxItems={displayedInboxItems}
              incomingMessagesCount={incomingMessagesCount}
              inboxCurrentPage={inboxCurrentPage}
              inboxQueryIsError={inboxQuery.isError}
              inboxQueryIsFetching={inboxQuery.isFetching}
              inboxQueryIsLoading={inboxQuery.isLoading}
              inboxTotalCount={inboxTotalCount}
              isQueueControlsLocked={isQueueControlsLocked}
              locale={locale}
              navigationMode={navigationMode}
              onConversationSelect={onConversationSelect}
              queueCount={queueCount}
              queueLabels={queueLabels}
              queueSearchParams={queueSearchParams}
              queueShownEnd={queueShownEnd}
              queueShownStart={queueShownStart}
              queuePriorityFilter={queuePriorityFilter}
              queueSort={queueSort}
              queueStatusFilter={queueStatusFilter}
              requestInboxRetry={requestInboxRetry}
              requestNextQueuePage={requestNextQueuePage}
              requestPreviousQueuePage={requestPreviousQueuePage}
              searchInputRef={searchInputRef}
              searchQuery={searchQuery}
              setExactQueueStatusFilter={setExactQueueStatusFilter}
              setExactQueuePriorityFilter={setExactQueuePriorityFilter}
              setExactQueueSort={setExactQueueSort}
              setQueueSubFilter={setQueueSubFilter}
              setSearchQuery={(value) => setSearchQuery(value.slice(0, SUPPORT_SEARCH_MAX_LENGTH))}
              subFilter={subFilter}
              text={text}
              unassignedCount={unassignedCount}
            />

            <SupportConversationChatPane
              attachmentInputRef={attachmentInputRef}
              attachmentPreviewUrl={attachmentPreviewUrl}
              canManageSupportWorkspace={canManageSupportWorkspace}
              canClaimConversation={canClaimConversation}
              canManageReplyTemplates={sessionUserRoles.includes("Admin")}
              canRetryAttachment={canMutateConversation}
              composerPlaceholder={composerPlaceholder}
              composerValue={composerValue}
              conversation={conversation}
              conversationQueryIsFetching={conversationQuery.isFetching}
              conversationSla={conversationSla}
              copy={copy}
              detailsAction={
                <Button
                  variant="secondary"
                  size="sm"
                  className={styles.detailsTrigger}
                  aria-controls={supportDetailsDrawerId}
                  aria-expanded={isSupportDetailsDrawerOpen}
                  aria-label={text.supportConversationDetailsTitle}
                  onClick={() => setIsSupportDetailsDrawerOpen(true)}
                >
                  {text.supportConversationDetailsTitle}
                </Button>
              }
              groupedConversationFeed={groupedConversationFeed}
              hasComposerAttachment={hasComposerAttachment}
              highlightedMessageId={highlightedMessageId}
              isComposerBusy={isComposerBusy}
              isComposerDisabled={isComposerDisabled}
              isOwnershipComposerNoticeVisible={
                isOwnershipComposerNoticeVisible && !canMutateConversation
              }
              isOwnershipRequired={!canMutateConversation}
              isAttachmentRetrySubmitting={isAttachmentRetrySubmitting}
              isLoadingOlderMessages={isLoadingOlderMessages}
              isConversationClosed={isConversationClosed}
              isConversationReadOnly={isConversationReadOnly}
              isDragging={isDragging}
              jumpToMessage={jumpToMessage}
              onClaimConversation={requestClaimConversation}
              onOwnershipRequired={revealOwnershipComposerNotice}
              locale={locale}
              messageLabels={messageLabels}
              messagesById={messagesById}
              messagesEndRef={messagesEndRef}
              readOnlyComposerTitle={readOnlyComposerTitle}
              reply={reply}
              replyComposerAttachment={replyComposerAttachment}
              replyComposerPreview={replyComposerPreview}
              replyToMessage={replyToMessage}
              replyToPreview={replyToPreview}
              requestAttachmentRetry={requestAttachmentRetry}
              requestOlderMessagesLoad={requestOlderMessagesLoad}
              requestReopenConversation={requestReopenConversation}
              reopenStatusAction={reopenStatusAction}
              renderAttachmentTile={renderAttachmentTile}
              renderReplyThumbnail={renderReplyThumbnail}
              resetSelectedAttachment={resetSelectedAttachment}
              selectedAttachment={selectedAttachment}
              selectReplyToMessage={(messageId) => selectReplyToMessage(messageId)}
              setFullscreenImage={setFullscreenImage}
              setIsDragging={setIsDragging}
              setReply={(value) => setReply(value.slice(0, SUPPORT_REPLY_MAX_LENGTH))}
              setSelectedAttachment={setSelectedAttachment}
              startReplyToMessage={startReplyToMessage}
              statusMutationIsPending={statusMutation.isPending}
              submitReply={submitReply}
              text={text}
              userDisplayName={userDisplayName}
              userEmailDisplay={userEmailDisplay}
            />

            <SupportConversationDetailsDrawer
              drawerId={supportDetailsDrawerId}
              isDrawerMode={isSupportDetailsDrawerMode}
              isOpen={isSupportDetailsDrawerOpen}
              title={text.supportConversationDetailsTitle}
              closeLabel={text.supportClosePanelAction}
              onClose={() => setIsSupportDetailsDrawerOpen(false)}
            >
              <SupportInfoPanel
                locale={locale}
                controller={controller}
                claimRequestId={claimRequestId}
              />
            </SupportConversationDetailsDrawer>
          </div>
          {fullscreenImage ? (
            <SupportConversationFullscreenViewer
              canManageSupportWorkspace={canManageSupportWorkspace}
              closeFullscreenImage={closeFullscreenImage}
              copy={copy}
              fullscreenImage={fullscreenImage}
              imageViewerLabels={imageViewerLabels}
              jumpToMessage={jumpToMessage}
              locale={locale}
              openFullscreenImageInNewTab={openFullscreenImageInNewTab}
              pendingFullscreenAction={pendingFullscreenAction}
              saveFullscreenImage={saveFullscreenImage}
              shareFullscreenImage={shareFullscreenImage}
            />
          ) : null}
        </>
      )}
    </AdminPage>
  );
}

function getSupportMessageElementId(messageId: string) {
  return `message-${encodeURIComponent(messageId)}`;
}
