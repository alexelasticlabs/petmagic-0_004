"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import { FileIcon } from "@/components/admin/admin-icons";
import {
  formatAccountAge,
  formatDateTime,
  formatFileSize,
  formatRelativeTime,
  formatSafeSupportDownloadName,
  formatSafeSupportDisplay,
  getMessageAttachments,
} from "@/components/support/support-conversation-helpers";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import styles from "@/components/support/support-page.module.css";
import { SupportSecureMedia } from "@/components/support/support-secure-media";
import { useSupportConversationController } from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { type SupportConversationStatus } from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type SupportInfoPanelProps = {
  locale: Locale;
  controller: ReturnType<typeof useSupportConversationController>;
};

type SupportInfoAttachment = ReturnType<typeof getMessageAttachments>[number];

function downloadSupportInfoBlobUrl(objectUrl: string, fileName: string): void {
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = fileName;
  document.body.append(link);
  link.click();
  link.remove();
}

function formatSupportInfoLogText(value: string | null | undefined, maxLength = 80) {
  return value ? sanitizeSensitiveText(value, maxLength) : undefined;
}

function getSupportInfoErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export function SupportInfoPanel({ locale, controller }: SupportInfoPanelProps) {
  const [pendingStatusConfirm, setPendingStatusConfirm] =
    useState<SupportConversationStatus | null>(null);
  const [tagInput, setTagInput] = useState("");
  const [isTagEditorOpen, setIsTagEditorOpen] = useState(false);
  const [pendingAttachmentOpenKey, setPendingAttachmentOpenKey] = useState<string | null>(null);
  const tagInputRef = useRef<HTMLInputElement>(null);
  const attachmentOpenAbortControllerRef = useRef<AbortController | null>(null);
  const previousConversationIdRef = useRef<string | null>(null);

  const {
    activeSidePanelTab,
    accountCreatedAt,
    addOperatorTag,
    activityTimeline,
    analyticsQuery,
    conversation,
    conversationTimeline,
    destructiveStatusAction,
    canManageSupportWorkspace,
    canViewSubjectUserContext,
    lastActivityAtUtc,
    operatorPriority,
    operatorTags,
    primaryStatusAction,
    recentFailures,
    recentUserPurchases,
    removeOperatorTag,
    secondaryStatusActions,
    setActiveSidePanelTab,
    setOperatorPriority,
    sidePanelTabs,
    statusMutation,
    text,
    totalPurchases,
    userQuery,
  } = controller;

  const panelText = useMemo(() => getSupportConversationCopy(locale).infoPanel, [locale]);
  const isUserPremium = canViewSubjectUserContext ? (userQuery.data?.isPremium ?? false) : false;

  useEffect(
    () => () => {
      attachmentOpenAbortControllerRef.current?.abort();
    },
    []
  );

  const recentAttachments = useMemo(() => {
    const entries = (conversation?.messages ?? [])
      .flatMap((message) =>
        getMessageAttachments(message)
          .filter((attachment) => !attachment.isDeleted && Boolean(attachment.fileUrl?.trim()))
          .map((attachment) => ({
            messageId: message.messageId,
            createdAtUtc: message.createdAtUtc,
            attachment,
          }))
      )
      .sort((left, right) => right.createdAtUtc.localeCompare(left.createdAtUtc));

    const seen = new Set<string>();
    return entries.filter((entry) => {
      const key = `${entry.messageId}|${entry.attachment.fileName}|${entry.attachment.sizeBytes}|${entry.createdAtUtc}`;
      if (seen.has(key)) {
        return false;
      }

      seen.add(key);
      return true;
    });
  }, [conversation?.messages]);

  useEffect(() => {
    const previousConversationId = previousConversationIdRef.current;
    previousConversationIdRef.current = conversation?.conversationId ?? null;

    if (!pendingStatusConfirm || statusMutation.isPending) {
      return;
    }

    if (
      !conversation ||
      conversation.status === pendingStatusConfirm ||
      (previousConversationId !== null && previousConversationId !== conversation.conversationId)
    ) {
      queueMicrotask(() => setPendingStatusConfirm(null));
    }
  }, [conversation, pendingStatusConfirm, statusMutation.isPending]);

  if (!conversation) {
    return null;
  }

  const attachmentPreviewEntries = recentAttachments.slice(0, 4);
  const remainingAttachmentCount = Math.max(
    recentAttachments.length - attachmentPreviewEntries.length,
    0
  );

  const handleAddTag = () => {
    if (!canManageSupportWorkspace) {
      return;
    }

    const nextTag = tagInput.trim();
    if (!nextTag) {
      return;
    }

    const added = addOperatorTag(nextTag);
    if (added) {
      setTagInput("");
      setIsTagEditorOpen(false);
    }
  };

  const getAttachmentOpenKey = (
    messageId: string,
    createdAtUtc: string,
    attachment: SupportInfoAttachment,
    index: number
  ) => `${messageId}:${createdAtUtc}:${attachment.fileName}:${attachment.sizeBytes}:${index}`;

  const openAttachmentBlob = async (
    messageId: string,
    createdAtUtc: string,
    attachment: SupportInfoAttachment,
    index: number
  ) => {
    const openKey = getAttachmentOpenKey(messageId, createdAtUtc, attachment, index);
    if (!canManageSupportWorkspace || pendingAttachmentOpenKey !== null) {
      return;
    }

    setPendingAttachmentOpenKey(openKey);
    attachmentOpenAbortControllerRef.current?.abort();
    const controller = new AbortController();
    attachmentOpenAbortControllerRef.current = controller;
    try {
      const response = await fetchWithTimeout(attachment.fileUrl, {
        credentials: "include",
        signal: controller.signal,
      });
      if (!response.ok) {
        clientLogger.warn("support.attachment_open_failed", {
          messageId: formatSupportInfoLogText(messageId),
          status: response.status,
          mimeType: formatSupportInfoLogText(attachment.mimeType),
        });
        return;
      }

      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");
      if (!opened) {
        downloadSupportInfoBlobUrl(objectUrl, formatSafeSupportDownloadName(attachment.fileName));
        window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
        return;
      }

      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    } catch (error) {
      if (controller.signal.aborted) {
        return;
      }

      clientLogger.warn("support.attachment_open_failed", {
        messageId: formatSupportInfoLogText(messageId),
        mimeType: formatSupportInfoLogText(attachment.mimeType),
        ...getSupportInfoErrorDetails(error),
      });
    } finally {
      if (attachmentOpenAbortControllerRef.current === controller) {
        attachmentOpenAbortControllerRef.current = null;
        setPendingAttachmentOpenKey(null);
      }
    }
  };

  const confirmPendingStatusChange = async () => {
    if (!canManageSupportWorkspace || !pendingStatusConfirm || statusMutation.isPending) {
      return;
    }

    try {
      await statusMutation.mutateAsync(pendingStatusConfirm);
      setPendingStatusConfirm(null);
    } catch {
      // The controller mutation already routes sanitized errors to support notifications.
    }
  };

  const requestStatusChange = (status: SupportConversationStatus) => {
    if (
      !canManageSupportWorkspace ||
      statusMutation.isPending ||
      conversation.status === status
    ) {
      return;
    }

    if (status === "Closed") {
      setPendingStatusConfirm(status);
      return;
    }

    statusMutation.mutate(status);
  };

  return (
    <div className={styles.infoPanelFlat}>
      <div className={styles.infoPanel}>
        <div className={styles.infoPanelSection}>
          <div
            className={styles.sidePanelTabs}
            role="tablist"
            aria-label={panelText.panelTabsLabel}
          >
            {sidePanelTabs
              .filter((tab) => tab.value !== "activity" && tab.value !== "dialog")
              .map((tab) => (
                <button
                  key={tab.value}
                  type="button"
                  role="tab"
                  aria-selected={activeSidePanelTab === tab.value}
                  className={`${styles.spTabBtn} ${activeSidePanelTab === tab.value ? styles.spTabBtnActive : ""}`}
                  onClick={() => setActiveSidePanelTab(tab.value)}
                >
                  {tab.label}
                </button>
              ))}
          </div>
        </div>

        {activeSidePanelTab === "user" ? (
          <>
            <div className={styles.infoPanelSection}>
              <div className={styles.infoPanelSectionHeader}>
                <span className={styles.infoPanelSectionTitle}>
                  {panelText.ticketInformation}
                </span>
              </div>
              <div className={styles.infoPanelKvRow}>
                <span className={styles.infoPanelKvLabel}>
                  <span className={styles.infoPanelKvIcon} aria-hidden="true">
                    ⚑
                  </span>
                  <span>{text.supportPriorityLabel}</span>
                </span>
                <div className={styles.infoPanelSelectWrap}>
                  <Select
                    value={operatorPriority}
                    onChange={(value) => setOperatorPriority(value as typeof operatorPriority)}
                    disabled={!canManageSupportWorkspace}
                    showSelectedDescription={false}
                    options={[
                      { value: "Low", label: text.supportPriorityLow },
                      { value: "Normal", label: text.supportPriorityNormal },
                      { value: "High", label: text.supportPriorityHigh },
                    ]}
                  />
                </div>
              </div>
              <div className={styles.infoPanelKvRow}>
                <span className={styles.infoPanelKvLabel}>
                  <span className={styles.infoPanelKvIcon} aria-hidden="true">
                    ↻
                  </span>
                  <span>{panelText.updated}</span>
                </span>
                <strong>{formatDateTime(conversation.updatedAtUtc, locale)}</strong>
              </div>
            </div>

            <div className={styles.infoPanelSection}>
              <div className={styles.infoPanelSectionHeader}>
                <span className={styles.infoPanelSectionTitle}>
                  {panelText.attachmentsTitle(recentAttachments.length)}
                </span>
                {remainingAttachmentCount > 0 ? (
                  <button
                    type="button"
                    className={styles.infoPanelSectionLinkButton}
                    onClick={() => setActiveSidePanelTab("attachments")}
                  >
                    {panelText.viewAll}
                  </button>
                ) : null}
              </div>
              {recentAttachments.length === 0 ? (
                <span className={styles.subtle}>{panelText.noAttachments}</span>
              ) : (
                <div className={styles.infoPanelAttachmentPreviewStrip}>
                  {attachmentPreviewEntries.map((entry, index) => {
                    const { attachment } = entry;
                    const isImage = attachment.mimeType.toLowerCase().startsWith("image/");
                    const safeName = formatSafeSupportDisplay(
                      attachment.fileName,
                      panelText.fileFallback,
                      120
                    );

                    return (
                      <button
                        key={`${entry.messageId}-${index}`}
                        type="button"
                        onClick={() =>
                          void openAttachmentBlob(
                            entry.messageId,
                            entry.createdAtUtc,
                            attachment,
                            index
                          )
                        }
                        disabled={
                          !canManageSupportWorkspace ||
                          pendingAttachmentOpenKey !== null
                        }
                        className={styles.infoPanelAttachmentPreviewTile}
                        title={safeName}
                      >
                        {isImage ? (
                          <SupportSecureMedia
                            url={attachment.fileUrl}
                            kind="image"
                            alt={safeName}
                            width={64}
                            height={64}
                            className={styles.infoPanelAttachmentPreviewImage}
                            logContext={{
                              messageId: entry.messageId,
                              mimeType: attachment.mimeType,
                            }}
                          />
                        ) : (
                          <span className={styles.infoPanelAttachmentPreviewIcon}>
                            <FileIcon className={styles.supportFileIcon} />
                          </span>
                        )}
                        <span className={styles.infoPanelAttachmentPreviewSize}>
                          {formatFileSize(attachment.sizeBytes, locale)}
                        </span>
                      </button>
                    );
                  })}
                  {remainingAttachmentCount > 0 ? (
                    <span className={styles.infoPanelAttachmentPreviewMore}>
                      +{remainingAttachmentCount}
                    </span>
                  ) : null}
                </div>
              )}
            </div>

            <div className={styles.infoPanelSection}>
              <div className={styles.infoPanelSectionHeader}>
                <span className={styles.infoPanelSectionTitle}>
                  {panelText.operatorTags}
                </span>
                <button
                  type="button"
                  className={styles.infoPanelTagAddChip}
                  onClick={() => {
                    if (!canManageSupportWorkspace) {
                      return;
                    }
                    setIsTagEditorOpen((current) => !current);
                    window.setTimeout(() => tagInputRef.current?.focus(), 0);
                  }}
                  disabled={!canManageSupportWorkspace}
                  aria-label={panelText.addTag}
                  title={panelText.addTag}
                >
                  +
                </button>
              </div>
              {operatorTags.length > 0 ? (
                <div className={styles.infoPanelTagsWrap}>
                  {operatorTags.map((tag) => (
                    <button
                      key={tag}
                      type="button"
                      className={styles.infoPanelTagChip}
                      onClick={() => removeOperatorTag(tag)}
                      disabled={!canManageSupportWorkspace}
                      title={panelText.removeTag}
                    >
                      {formatSafeSupportDisplay(tag, panelText.tagFallback, 40)}{" "}
                      <span aria-hidden="true">×</span>
                    </button>
                  ))}
                </div>
              ) : null}
              {isTagEditorOpen || operatorTags.length === 0 ? (
                <div className={styles.infoPanelTagInputRow}>
                  <input
                    ref={tagInputRef}
                    className={styles.infoPanelTagInput}
                    value={tagInput}
                    onChange={(event) => setTagInput(event.target.value.slice(0, 40))}
                    onKeyDown={(event) => {
                      if (event.key === "Enter" || event.key === ",") {
                        event.preventDefault();
                        handleAddTag();
                      }
                    }}
                    maxLength={40}
                    placeholder={text.tagsLabel}
                    disabled={!canManageSupportWorkspace}
                  />
                  <Button
                    type="button"
                    size="sm"
                    variant="secondary"
                    onClick={handleAddTag}
                    disabled={!canManageSupportWorkspace || !tagInput.trim()}
                  >
                    {panelText.add}
                  </Button>
                </div>
              ) : null}
              <span className={styles.subtle}>{panelText.tagHint}</span>
            </div>

            <div className={styles.infoPanelSection}>
              <div className={styles.infoPanelSectionHeader}>
                <span className={styles.infoPanelSectionTitle}>
                  {panelText.user}
                </span>
              </div>
              {canViewSubjectUserContext ? (
                <div className={styles.infoPanelStatsGrid}>
                  <div className={styles.infoPanelStatTile}>
                    <span>{text.supportPlanLabel}</span>
                    <strong>{isUserPremium ? text.premiumLabel : text.freeLabel}</strong>
                  </div>
                  <div className={styles.infoPanelStatTile}>
                    <span>{panelText.walletLabel}</span>
                    <strong>{String(analyticsQuery.data?.summary.walletBalance ?? 0)}</strong>
                  </div>
                  <div className={styles.infoPanelStatTile}>
                    <span>{text.supportAccountAgeLabel}</span>
                    <strong>{formatAccountAge(accountCreatedAt, locale)}</strong>
                  </div>
                </div>
              ) : null}
              <div className={styles.infoPanelStatsSecondaryGrid}>
                {canViewSubjectUserContext ? (
                  <button
                    type="button"
                    className={`${styles.infoPanelStatTileFull} ${styles.infoPanelStatTileButton}`}
                    onClick={() => setActiveSidePanelTab("activity")}
                  >
                    <span>{panelText.purchases}</span>
                    <strong>{String(totalPurchases)}</strong>
                  </button>
                ) : null}
                <button
                  type="button"
                  className={`${styles.infoPanelStatTileFull} ${styles.infoPanelStatTileButton}`}
                  onClick={() => setActiveSidePanelTab("dialog")}
                >
                  <span>{text.supportLastSeenLabel}</span>
                  <strong>
                    {lastActivityAtUtc
                      ? formatDateTime(lastActivityAtUtc, locale)
                      : panelText.noData}
                  </strong>
                </button>
              </div>
            </div>

            <div className={styles.infoPanelSection}>
              <div className={styles.infoPanelSectionHeader}>
                <span className={styles.infoPanelSectionTitle}>
                  {panelText.ticketActions}
                </span>
              </div>

              <div className={styles.infoPanelActionStack}>
                {pendingStatusConfirm ? (
                  <div className={styles.spConfirmBox}>
                    <span className={styles.spConfirmText}>
                      {panelText.closeConversationPrompt}
                    </span>
                    <div className={styles.spConfirmActions}>
                      <Button
                        variant="primary"
                        size="sm"
                        onClick={() => void confirmPendingStatusChange()}
                        disabled={!canManageSupportWorkspace || statusMutation.isPending}
                      >
                        {panelText.close}
                      </Button>
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => setPendingStatusConfirm(null)}
                        disabled={statusMutation.isPending}
                      >
                        {panelText.cancel}
                      </Button>
                    </div>
                  </div>
                ) : primaryStatusAction ? (
                  <button
                    type="button"
                    className={`ui-button ui-button--primary ui-button--md ${styles.actionsPanelBtn}`}
                    onClick={() => requestStatusChange(primaryStatusAction.status)}
                    disabled={
                      !canManageSupportWorkspace ||
                      statusMutation.isPending ||
                      conversation.status === primaryStatusAction.status
                    }
                  >
                    {primaryStatusAction.label}
                  </button>
                ) : null}

                {secondaryStatusActions.map((action) => (
                  <button
                    key={action.status}
                    type="button"
                    className={`ui-button ui-button--secondary ui-button--md ${styles.actionsPanelBtn}`}
                    onClick={() => requestStatusChange(action.status)}
                    disabled={
                      !canManageSupportWorkspace ||
                      statusMutation.isPending ||
                      conversation.status === action.status
                    }
                  >
                    {action.label}
                  </button>
                ))}

                {destructiveStatusAction ? (
                  <Button
                    variant="danger"
                    onClick={() => requestStatusChange(destructiveStatusAction.status)}
                    disabled={
                      !canManageSupportWorkspace ||
                      statusMutation.isPending ||
                      conversation.status === destructiveStatusAction.status
                    }
                  >
                    {destructiveStatusAction.label}
                  </Button>
                ) : null}
              </div>
            </div>
          </>
        ) : null}

        {activeSidePanelTab === "attachments" ? (
          <div className={styles.infoPanelSection}>
            <div className={styles.infoPanelSectionHeader}>
              <span className={styles.infoPanelSectionTitle}>
                {panelText.allAttachments}
              </span>
            </div>
            {recentAttachments.length === 0 ? (
              <span className={styles.subtle}>{panelText.noAttachments}</span>
            ) : (
              <div className={styles.attachmentList}>
                {recentAttachments.map((entry, index) => {
                  const { attachment } = entry;
                  const safeName = formatSafeSupportDisplay(
                    attachment.fileName,
                    panelText.fileFallback,
                    120
                  );
                  const isImage = attachment.mimeType.toLowerCase().startsWith("image/");
                  const attachmentKindLabel = getAttachmentKindLabel(
                    attachment.mimeType,
                    safeName,
                    panelText
                  );

                  return (
                    <div key={`${entry.messageId}-${index}`} className={styles.attachmentListItem}>
                      {isImage ? (
                        <button
                          type="button"
                          onClick={() =>
                            void openAttachmentBlob(
                              entry.messageId,
                              entry.createdAtUtc,
                              attachment,
                              index
                            )
                          }
                          disabled={
                            !canManageSupportWorkspace ||
                            pendingAttachmentOpenKey !== null
                          }
                          className={styles.attachmentListThumbButton}
                        >
                          <SupportSecureMedia
                            url={attachment.fileUrl}
                            kind="image"
                            alt={safeName}
                            width={76}
                            height={76}
                            className={styles.attachmentListThumb}
                            logContext={{
                              messageId: entry.messageId,
                              mimeType: attachment.mimeType,
                            }}
                          />
                        </button>
                      ) : (
                        <span className={styles.attachmentPreviewFileIcon}>
                          <FileIcon className={styles.supportFileIcon} />
                        </span>
                      )}
                      <div className={styles.attachmentListMeta}>
                        <div className={styles.attachmentListMetaTop}>
                          <strong title={safeName}>{safeName}</strong>
                          <span className={styles.attachmentListTypeBadge}>
                            {attachmentKindLabel}
                          </span>
                        </div>
                        <div className={styles.attachmentListMetaRow}>
                          <span>{formatRelativeTime(entry.createdAtUtc, locale)}</span>
                          <span aria-hidden="true">•</span>
                          <span>{formatFileSize(attachment.sizeBytes, locale)}</span>
                        </div>
                        <span className={styles.attachmentListMetaHint}>
                          {formatDateTime(entry.createdAtUtc, locale)}
                        </span>
                      </div>
                      <div className={styles.attachmentListActions}>
                        <button
                          type="button"
                          onClick={() =>
                            void openAttachmentBlob(
                              entry.messageId,
                              entry.createdAtUtc,
                              attachment,
                              index
                            )
                          }
                          disabled={
                            !canManageSupportWorkspace ||
                            pendingAttachmentOpenKey !== null
                          }
                          className="ui-button ui-button--secondary ui-button--sm"
                        >
                          {panelText.open}
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        ) : null}

        {activeSidePanelTab === "activity" ? (
          <div className={styles.infoPanelSection}>
            <div className={styles.infoPanelSectionHeader}>
              <span className={styles.infoPanelSectionTitle}>
                {panelText.activity}
              </span>
            </div>
            <div className={styles.sidePanelContent}>
              {canViewSubjectUserContext && recentUserPurchases.length > 0 ? (
                <div className={styles.sectionBlock}>
                  <div className={styles.sectionHeaderCompact}>
                    <strong>{panelText.purchases}</strong>
                  </div>
                  <div className={styles.timelineList}>
                    {recentUserPurchases.slice(0, 4).map((purchase) => (
                      <article key={purchase.orderId} className={styles.timelineCard}>
                        <div className={styles.timelineCardHeader}>
                          <strong>
                            {formatSafeSupportDisplay(purchase.paymentProvider, "—", 48)}
                          </strong>
                          <span>
                            {formatRelativeTime(
                              purchase.confirmedAtUtc ?? purchase.createdAtUtc,
                              locale
                            )}
                          </span>
                        </div>
                        <p className={styles.timelineCardBody}>
                          {`${purchase.priceAmount} ${formatSafeSupportDisplay(
                            purchase.currencyCode,
                            "—",
                            12
                          )} · ${formatSafeSupportDisplay(purchase.status, "—", 48)}`}
                        </p>
                      </article>
                    ))}
                  </div>
                </div>
              ) : null}

              {recentFailures.length > 0 ? (
                <div className={styles.sectionBlock}>
                  <div className={styles.sectionHeaderCompact}>
                    <strong>{panelText.failures}</strong>
                  </div>
                  <div className={styles.timelineList}>
                    {recentFailures.map((item) => (
                      <article key={item.failureCode} className={styles.timelineCard}>
                        <div className={styles.timelineCardHeader}>
                          <strong>{formatSafeSupportDisplay(item.failureCode, "—", 120)}</strong>
                          <span>{formatRelativeTime(item.lastOccurredAtUtc, locale)}</span>
                        </div>
                        <p className={styles.timelineCardBody}>{panelText.occurrences(item.count)}</p>
                      </article>
                    ))}
                  </div>
                </div>
              ) : null}

              <div className={styles.sectionBlock}>
                <div className={styles.sectionHeaderCompact}>
                  <strong>{panelText.recentEvents}</strong>
                </div>
                <div className={styles.timelineList}>
                  {activityTimeline.length > 0 ? (
                    activityTimeline.slice(0, 6).map((item) => (
                      <article key={item.id} className={styles.timelineCard}>
                        <div className={styles.timelineCardHeader}>
                          <strong>{item.title}</strong>
                          <span>{formatRelativeTime(item.occurredAtUtc, locale)}</span>
                        </div>
                        <p className={styles.timelineCardBody}>{item.subtitle}</p>
                      </article>
                    ))
                  ) : (
                    <span className={styles.subtle}>{panelText.noActivityData}</span>
                  )}
                </div>
              </div>
            </div>
          </div>
        ) : null}

        {activeSidePanelTab === "dialog" ? (
          <div className={styles.infoPanelSection}>
            <div className={styles.infoPanelSectionHeader}>
              <span className={styles.infoPanelSectionTitle}>
                {panelText.conversationHistory}
              </span>
            </div>
            <div className={styles.sidePanelContent}>
              <div className={styles.sectionBlock}>
                <div className={styles.sectionHeaderCompact}>
                  <strong>{panelText.timeline}</strong>
                </div>
                <div className={styles.timelineList}>
                  {conversationTimeline.length > 0 ? (
                    conversationTimeline.map((item) => (
                      <article key={item.id} className={styles.timelineCard}>
                        <div className={styles.timelineCardHeader}>
                          <strong>{item.title}</strong>
                          <span>{formatRelativeTime(item.occurredAtUtc, locale)}</span>
                        </div>
                        <p className={styles.timelineCardBody}>{item.subtitle}</p>
                      </article>
                    ))
                  ) : (
                    <span className={styles.subtle}>{panelText.timelineEmpty}</span>
                  )}
                </div>
              </div>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}

function getAttachmentKindLabel(
  mimeType: string,
  fileName: string,
  panelText: ReturnType<typeof getSupportConversationCopy>["infoPanel"]
) {
  const normalizedMime = mimeType.trim().toLowerCase();
  const extensionFromName = fileName.includes(".")
    ? (fileName.split(".").pop()?.trim().toUpperCase() ?? "")
    : "";

  if (extensionFromName.length >= 2 && extensionFromName.length <= 6) {
    return extensionFromName;
  }

  if (normalizedMime.startsWith("image/")) {
    return panelText.attachmentKinds.photo;
  }

  if (normalizedMime.startsWith("video/")) {
    return panelText.attachmentKinds.video;
  }

  if (normalizedMime.startsWith("audio/")) {
    return panelText.attachmentKinds.audio;
  }

  if (normalizedMime === "application/pdf") {
    return "PDF";
  }

  return panelText.attachmentKinds.file;
}
