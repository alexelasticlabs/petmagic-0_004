"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import {
  formatAccountAge,
  formatDateTime,
  formatFileSize,
  formatRelativeTime,
  formatSafeSupportDisplay,
  getMessageAttachments,
} from "@/components/support/support-conversation-helpers";
import styles from "@/components/support/support-page.module.css";
import { SupportSecureMedia } from "@/components/support/support-secure-media";
import { useSupportConversationController } from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { type SupportConversationStatus } from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";
import { type Locale } from "@/lib/i18n";

type SupportInfoPanelProps = {
  locale: Locale;
  controller: ReturnType<typeof useSupportConversationController>;
};

type SupportInfoAttachment = ReturnType<typeof getMessageAttachments>[number];

export function SupportInfoPanel({ locale, controller }: SupportInfoPanelProps) {
  const [pendingStatusConfirm, setPendingStatusConfirm] =
    useState<SupportConversationStatus | null>(null);
  const [tagInput, setTagInput] = useState("");
  const [isTagEditorOpen, setIsTagEditorOpen] = useState(false);
  const [pendingAttachmentOpenKey, setPendingAttachmentOpenKey] = useState<string | null>(null);
  const tagInputRef = useRef<HTMLInputElement>(null);
  const attachmentOpenAbortControllerRef = useRef<AbortController | null>(null);

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
          messageId,
          status: response.status,
          mimeType: attachment.mimeType,
        });
        return;
      }

      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");
      if (!opened) {
        URL.revokeObjectURL(objectUrl);
        return;
      }

      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    } catch (error) {
      if (controller.signal.aborted) {
        return;
      }

      clientLogger.warn("support.attachment_open_failed", {
        messageId,
        mimeType: attachment.mimeType,
        error,
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
            aria-label={locale === "ru" ? "Разделы панели" : "Panel tabs"}
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
                  {locale === "ru" ? "Информация о тикете" : "Ticket information"}
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
                  <span>{locale === "ru" ? "Обновлён" : "Updated"}</span>
                </span>
                <strong>{formatDateTime(conversation.updatedAtUtc, locale)}</strong>
              </div>
            </div>

            <div className={styles.infoPanelSection}>
              <div className={styles.infoPanelSectionHeader}>
                <span className={styles.infoPanelSectionTitle}>
                  {locale === "ru"
                    ? `Вложения (${recentAttachments.length})`
                    : `Attachments (${recentAttachments.length})`}
                </span>
                {remainingAttachmentCount > 0 ? (
                  <button
                    type="button"
                    className={styles.infoPanelSectionLinkButton}
                    onClick={() => setActiveSidePanelTab("attachments")}
                  >
                    {locale === "ru" ? "Смотреть все" : "View all"}
                  </button>
                ) : null}
              </div>
              {recentAttachments.length === 0 ? (
                <span className={styles.subtle}>
                  {locale === "ru" ? "Вложений пока нет" : "No attachments yet"}
                </span>
              ) : (
                <div className={styles.infoPanelAttachmentPreviewStrip}>
                  {attachmentPreviewEntries.map((entry, index) => {
                    const { attachment } = entry;
                    const isImage = attachment.mimeType.toLowerCase().startsWith("image/");
                    const safeName = formatSafeSupportDisplay(
                      attachment.fileName,
                      locale === "ru" ? "Файл" : "File",
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
                          <span className={styles.infoPanelAttachmentPreviewIcon}>FILE</span>
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
                  {locale === "ru" ? "Теги оператора" : "Operator tags"}
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
                  aria-label={locale === "ru" ? "Добавить тег" : "Add tag"}
                  title={locale === "ru" ? "Добавить тег" : "Add tag"}
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
                      title={locale === "ru" ? "Удалить тег" : "Remove tag"}
                    >
                      {formatSafeSupportDisplay(tag, locale === "ru" ? "Тег" : "Tag", 40)}{" "}
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
                    {locale === "ru" ? "Добавить" : "Add"}
                  </Button>
                </div>
              ) : null}
              <span className={styles.subtle}>
                {locale === "ru"
                  ? "Теги используются для быстрого поиска в очереди."
                  : "Tags are used for fast queue search."}
              </span>
            </div>

            <div className={styles.infoPanelSection}>
              <div className={styles.infoPanelSectionHeader}>
                <span className={styles.infoPanelSectionTitle}>
                  {locale === "ru" ? "Пользователь" : "User"}
                </span>
              </div>
              {canViewSubjectUserContext ? (
                <div className={styles.infoPanelStatsGrid}>
                  <div className={styles.infoPanelStatTile}>
                    <span>{text.supportPlanLabel}</span>
                    <strong>{isUserPremium ? text.premiumLabel : text.freeLabel}</strong>
                  </div>
                  <div className={styles.infoPanelStatTile}>
                    <span>{locale === "ru" ? "PawSpark" : "PawSpark"}</span>
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
                    <span>{locale === "ru" ? "Покупки" : "Purchases"}</span>
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
                      : locale === "ru"
                        ? "Нет данных"
                        : "No data"}
                  </strong>
                </button>
              </div>
            </div>

            <div className={styles.infoPanelSection}>
              <div className={styles.infoPanelSectionHeader}>
                <span className={styles.infoPanelSectionTitle}>
                  {locale === "ru" ? "Действия по тикету" : "Ticket actions"}
                </span>
              </div>

              <div className={styles.infoPanelActionStack}>
                {pendingStatusConfirm ? (
                  <div className={styles.spConfirmBox}>
                    <span className={styles.spConfirmText}>
                      {locale === "ru" ? "Закрыть обращение?" : "Close conversation?"}
                    </span>
                    <div className={styles.spConfirmActions}>
                      <Button
                        variant="primary"
                        size="sm"
                        onClick={() => void confirmPendingStatusChange()}
                        disabled={!canManageSupportWorkspace || statusMutation.isPending}
                      >
                        {locale === "ru" ? "Закрыть" : "Close"}
                      </Button>
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => setPendingStatusConfirm(null)}
                      >
                        {locale === "ru" ? "Отмена" : "Cancel"}
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
                {locale === "ru" ? "Все вложения" : "All attachments"}
              </span>
            </div>
            {recentAttachments.length === 0 ? (
              <span className={styles.subtle}>
                {locale === "ru" ? "Вложений пока нет" : "No attachments yet"}
              </span>
            ) : (
              <div className={styles.attachmentList}>
                {recentAttachments.map((entry, index) => {
                  const { attachment } = entry;
                  const safeName = formatSafeSupportDisplay(
                    attachment.fileName,
                    locale === "ru" ? "Файл" : "File",
                    120
                  );
                  const isImage = attachment.mimeType.toLowerCase().startsWith("image/");
                  const attachmentKindLabel = getAttachmentKindLabel(
                    attachment.mimeType,
                    safeName,
                    locale
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
                        <span className={styles.attachmentPreviewFileIcon}>FILE</span>
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
                          {locale === "ru" ? "Открыть" : "Open"}
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
                {locale === "ru" ? "Активность" : "Activity"}
              </span>
            </div>
            <div className={styles.sidePanelContent}>
              {canViewSubjectUserContext && recentUserPurchases.length > 0 ? (
                <div className={styles.sectionBlock}>
                  <div className={styles.sectionHeaderCompact}>
                    <strong>{locale === "ru" ? "Покупки" : "Purchases"}</strong>
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
                    <strong>{locale === "ru" ? "Ошибки" : "Failures"}</strong>
                  </div>
                  <div className={styles.timelineList}>
                    {recentFailures.map((item) => (
                      <article key={item.failureCode} className={styles.timelineCard}>
                        <div className={styles.timelineCardHeader}>
                          <strong>{formatSafeSupportDisplay(item.failureCode, "—", 120)}</strong>
                          <span>{formatRelativeTime(item.lastOccurredAtUtc, locale)}</span>
                        </div>
                        <p className={styles.timelineCardBody}>
                          {locale === "ru"
                            ? `Повторений: ${item.count}`
                            : `Occurrences: ${item.count}`}
                        </p>
                      </article>
                    ))}
                  </div>
                </div>
              ) : null}

              <div className={styles.sectionBlock}>
                <div className={styles.sectionHeaderCompact}>
                  <strong>{locale === "ru" ? "Последние события" : "Recent events"}</strong>
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
                    <span className={styles.subtle}>
                      {locale === "ru" ? "Нет данных активности" : "No activity data"}
                    </span>
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
                {locale === "ru" ? "История диалога" : "Conversation history"}
              </span>
            </div>
            <div className={styles.sidePanelContent}>
              <div className={styles.sectionBlock}>
                <div className={styles.sectionHeaderCompact}>
                  <strong>{locale === "ru" ? "Таймлайн" : "Timeline"}</strong>
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
                    <span className={styles.subtle}>
                      {locale === "ru" ? "История пуста" : "Timeline is empty"}
                    </span>
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

function getAttachmentKindLabel(mimeType: string, fileName: string, locale: Locale) {
  const normalizedMime = mimeType.trim().toLowerCase();
  const extensionFromName = fileName.includes(".")
    ? (fileName.split(".").pop()?.trim().toUpperCase() ?? "")
    : "";

  if (extensionFromName.length >= 2 && extensionFromName.length <= 6) {
    return extensionFromName;
  }

  if (normalizedMime.startsWith("image/")) {
    return locale === "ru" ? "ФОТО" : "PHOTO";
  }

  if (normalizedMime.startsWith("video/")) {
    return locale === "ru" ? "ВИДЕО" : "VIDEO";
  }

  if (normalizedMime.startsWith("audio/")) {
    return locale === "ru" ? "АУДИО" : "AUDIO";
  }

  if (normalizedMime === "application/pdf") {
    return "PDF";
  }

  return locale === "ru" ? "ФАЙЛ" : "FILE";
}
