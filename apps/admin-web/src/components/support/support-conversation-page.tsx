"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import { AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import { SupportConversationChatPane } from "@/components/support/support-conversation-chat-pane";
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
import type { AdminSupportConversation, SupportConversationStatus } from "@/lib/api-client";

export function SupportConversationPage({
  locale,
  conversationId,
  navigationMode = "route",
  onConversationSelect,
}: SupportConversationPageProps) {
  const copy = useMemo(() => getSupportConversationCopy(locale), [locale]);
  const [fullscreenImage, setFullscreenImage] = useState<FullscreenImage | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [highlightedMessageId, setHighlightedMessageId] = useState<string | null>(null);
  const [subFilter, setSubFilter] = useState<"all" | "unassigned" | "archive">("all");
  const [queueStatusFilter, setQueueStatusFilter] = useState<"all" | SupportConversationStatus>(
    "all"
  );
  const [pendingAttachmentActionKey, setPendingAttachmentActionKey] = useState<string | null>(null);
  const [pendingFullscreenAction, setPendingFullscreenAction] = useState<
    "download" | "share" | "open" | null
  >(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const messageHighlightTimerRef = useRef<number | null>(null);
  const fullscreenActionAbortControllerRef = useRef<AbortController | null>(null);
  const attachmentActionAbortControllerRef = useRef<AbortController | null>(null);
  const controller = useSupportConversationController({
    locale,
    conversationId,
    queueStatusFilter,
  });
  const {
    attachmentInputRef,
    attachmentPreviewUrl,
    composerPlaceholder,
    composerValue,
    conversation,
    conversationQuery,
    conversationSla,
    filteredInboxItems,
    canManageSupportWorkspace,
    canGoToNextQueuePage,
    canGoToPreviousQueuePage,
    hasComposerAttachment,
    inboxMetrics,
    inboxQuery,
    isSidePanelOpen,
    isSendReplySubmitting,
    loadOlderMessages,
    primaryStatusAction,
    reply,
    replyToMessage,
    replyToPreview,
    queuePage,
    requestSendReply,
    resetSelectedAttachment,
    searchQuery,
    secondaryStatusActions,
    selectedAttachment,
    selectReplyToMessage,
    setMessagesViewportVisible,
    setReply,
    setQueueFilter,
    setQueuePage,
    setSearchQuery,
    setSelectedAttachment,
    statusMutation,
    text,
    toast,
    userEmailDisplay,
    userDisplayName,
  } = controller;

  const isConversationReadOnly = conversation?.isReadOnly ?? false;
  const isComposerBusy = isSendReplySubmitting;
  const isComposerDisabled = isConversationReadOnly || !canManageSupportWorkspace || isComposerBusy;
  const isConversationClosed = conversation?.status === "Closed";
  const isQueueControlsLocked = !canManageSupportWorkspace || inboxQuery.isFetching;
  const setQueueSubFilter = (value: "all" | "unassigned" | "archive") => {
    if (isQueueControlsLocked) {
      return;
    }

    setSubFilter(value);
    setQueueStatusFilter("all");
    if (value === "archive") {
      setQueueFilter("Closed");
      return;
    }
    if (value === "unassigned") {
      setQueueFilter("unassigned");
      return;
    }
    setQueueFilter("all");
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
    if (!canManageSupportWorkspace || conversationQuery.isFetching) {
      return;
    }

    void loadOlderMessages();
  };

  const archiveCount = inboxMetrics?.closedConversations ?? 0;
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
    : statusHint(conversation?.status ?? "Closed", text);
  const imageViewerLabels = copy.page.imageViewer;
  const queueLabels = copy.page.queue;
  const messageLabels = copy.page.message;
  const supportWorkspaceSubtitle = copy.page.workspaceSubtitle;
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
    fullscreenActionAbortControllerRef.current?.abort();
    fullscreenActionAbortControllerRef.current = null;
    attachmentActionAbortControllerRef.current?.abort();
    attachmentActionAbortControllerRef.current = null;

    queueMicrotask(() => {
      setFullscreenImage(null);
      setPendingFullscreenAction(null);
      setPendingAttachmentActionKey(null);
      setHighlightedMessageId(null);
      setIsDragging(false);
    });
  }, [conversationId]);

  const submitReply = () => {
    if (isComposerDisabled || (!reply.trim() && !hasComposerAttachment)) {
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
  }, []);

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
  }, [fullscreenImage]);

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
                href={`/${locale}/support`}
                className="ui-button ui-button--secondary ui-button--md"
              >
                {text.supportBackToInbox}
              </Link>
            </div>
          }
        />
      ) : (
        <>
          <div
            className={`${styles.workspace} ${isSidePanelOpen ? styles.workspaceFullView : styles.workspaceCompact}`}
          >
            <SupportConversationQueuePane
              archiveCount={archiveCount}
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
              queueShownEnd={queueShownEnd}
              queueShownStart={queueShownStart}
              queueStatusFilter={queueStatusFilter}
              requestInboxRetry={requestInboxRetry}
              requestNextQueuePage={requestNextQueuePage}
              requestPreviousQueuePage={requestPreviousQueuePage}
              setExactQueueStatusFilter={setExactQueueStatusFilter}
              setQueueSubFilter={setQueueSubFilter}
              subFilter={subFilter}
              text={text}
              unassignedCount={unassignedCount}
            />

            <SupportConversationChatPane
              attachmentInputRef={attachmentInputRef}
              attachmentPreviewUrl={attachmentPreviewUrl}
              canManageSupportWorkspace={canManageSupportWorkspace}
              composerPlaceholder={composerPlaceholder}
              composerValue={composerValue}
              conversation={conversation}
              conversationQueryIsFetching={conversationQuery.isFetching}
              conversationSla={conversationSla}
              copy={copy}
              groupedConversationFeed={groupedConversationFeed}
              hasComposerAttachment={hasComposerAttachment}
              highlightedMessageId={highlightedMessageId}
              isComposerBusy={isComposerBusy}
              isComposerDisabled={isComposerDisabled}
              isConversationClosed={isConversationClosed}
              isConversationReadOnly={isConversationReadOnly}
              isDragging={isDragging}
              jumpToMessage={jumpToMessage}
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
              requestOlderMessagesLoad={requestOlderMessagesLoad}
              requestReopenConversation={requestReopenConversation}
              reopenStatusAction={reopenStatusAction}
              renderAttachmentTile={renderAttachmentTile}
              renderReplyThumbnail={renderReplyThumbnail}
              resetSelectedAttachment={resetSelectedAttachment}
              searchInputRef={searchInputRef}
              searchQuery={searchQuery}
              selectedAttachment={selectedAttachment}
              selectReplyToMessage={(messageId) => selectReplyToMessage(messageId)}
              setFullscreenImage={setFullscreenImage}
              setIsDragging={setIsDragging}
              setReply={(value) => setReply(value.slice(0, SUPPORT_REPLY_MAX_LENGTH))}
              setSearchQuery={(value) => setSearchQuery(value.slice(0, SUPPORT_SEARCH_MAX_LENGTH))}
              setSelectedAttachment={setSelectedAttachment}
              startReplyToMessage={startReplyToMessage}
              statusMutationIsPending={statusMutation.isPending}
              submitReply={submitReply}
              supportWorkspaceSubtitle={supportWorkspaceSubtitle}
              text={text}
              userDisplayName={userDisplayName}
              userEmailDisplay={userEmailDisplay}
            />

            {isSidePanelOpen ? (
              <>
                <SupportInfoPanel locale={locale} controller={controller} />
              </>
            ) : null}
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
