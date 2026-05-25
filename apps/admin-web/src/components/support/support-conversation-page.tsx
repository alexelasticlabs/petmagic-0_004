"use client";

import Image from "next/image";
import Link from "next/link";
import { useState } from "react";

import { AdminBadge, AdminCard, AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import {
    formatAccountAge,
    formatClockTime,
    formatDateTime,
    formatFileSize,
    formatMoney,
    formatRelativeTime,
    getConversationSla,
    hasAttachment,
    hasImageAttachment,
    initialsFor,
    shortId,
    shouldRenderMessageBody,
} from "@/components/support/support-conversation-helpers";
import {
    SectionBlock,
    SidePanelAsyncState,
    TimelineCard,
} from "@/components/support/support-conversation-ui-primitives";
import { SupportOptionGroup } from "@/components/support/support-option-group";
import styles from "@/components/support/support-page.module.css";
import {
    priorityLabel,
    priorityTone,
    statusHint,
    statusLabel,
    toneForGeneration,
    toneForStatus,
} from "@/components/support/support-status-helpers";
import {
    emptyTemplateDraft,
    statusOptions,
    type SupportFilter,
    useSupportConversationController,
} from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { type Locale } from "@/lib/i18n";

type SupportConversationPageProps = {
    locale: Locale;
    conversationId: string;
};

export function SupportConversationPage({ locale, conversationId }: SupportConversationPageProps) {
    const [fullscreenImage, setFullscreenImage] = useState<{ url: string; fileName?: string | null } | null>(null);

    const {
        activeSidePanelTab,
        accountCreatedAt,
        activityTimeline,
        analyticsQuery,
        applyTemplate,
        assignmentMutation,
        attachmentInputRef,
        attachmentPreviewUrl,
        chatFacts,
        composerPlaceholder,
        composerValue,
        conversation,
        conversationQuery,
        conversationSla,
        conversationTimeline,
        destructiveStatusAction,
        failedGenerations,
        filteredInboxItems,
        filteredTemplates,
        hasComposerAttachment,
        inboxQuery,
        isAssignedToCurrentAdmin,
        isSidePanelOpen,
        isTemplateEditorOpen,
        openTemplateEditor,
        primaryStatusAction,
        recentFailures,
        reply,
        resetSelectedAttachment,
        searchQuery,
        selectedAttachment,
        selectedTemplate,
        secondaryStatusActions,
        sendMutation,
        sessionUserId,
        setActiveSidePanelTab,
        setIsSidePanelOpen,
        setIsTemplateEditorOpen,
        setReply,
        setSearchQuery,
        setSelectedAttachment,
        setSelectedTemplateId,
        setStatusFilter,
        setTemplateDraft,
        setTemplateSearchQuery,
        sidePanelDescription,
        sidePanelTabs,
        sidePanelTitle,
        statusFilter,
        statusMutation,
        templateDeleteMutation,
        templateDraft,
        templateSaveMutation,
        templateSearchQuery,
        templatesQuery,
        text,
        toast,
        totalPurchases,
        userDisplayName,
        userQuery,
        visibleTemplates,
    } = useSupportConversationController({ locale, conversationId });

    const closeFullscreenImage = () => {
        setFullscreenImage(null);
    };

    const saveFullscreenImage = async () => {
        if (!fullscreenImage) {
            return;
        }

        try {
            const response = await fetch(fullscreenImage.url, { credentials: "include" });
            if (!response.ok) {
                return;
            }

            const blob = await response.blob();
            const objectUrl = URL.createObjectURL(blob);
            const link = document.createElement("a");
            link.href = objectUrl;
            link.download = fullscreenImage.fileName?.trim() || "support-image";
            document.body.append(link);
            link.click();
            link.remove();
            URL.revokeObjectURL(objectUrl);
        } catch {
            // Keep the dialog actionable even if browser download API is blocked.
        }
    };

    const shareFullscreenImage = async () => {
        if (!fullscreenImage) {
            return;
        }

        try {
            if (typeof window === "undefined") {
                return;
            }

            const browserNavigator = window.navigator as Navigator & {
                share?: (data: ShareData) => Promise<void>;
                clipboard?: Clipboard;
            };

            if (browserNavigator.share) {
                await browserNavigator.share({
                    title: fullscreenImage.fileName ?? "Support attachment",
                    url: fullscreenImage.url,
                });
                return;
            }

            if (browserNavigator.clipboard) {
                await browserNavigator.clipboard.writeText(fullscreenImage.url);
            }
        } catch {
            // Ignore action errors to avoid breaking message rendering.
        }
    };

    const openFullscreenImageInNewTab = () => {
        if (!fullscreenImage) {
            return;
        }

        window.open(fullscreenImage.url, "_blank", "noopener,noreferrer");
    };

    return (
        <AdminPage className={styles.page}>
            {toast ? <Toast type={toast.type} message={toast.message} /> : null}

            {conversationQuery.isLoading ? (
                <AdminStateCard tone="info" title={text.loading} description={text.supportConversationDescription} />
            ) : conversationQuery.isError || !conversation ? (
                <AdminStateCard
                    tone="danger"
                    title={text.supportLoadError}
                    action={<Link href={`/${locale}/support`} className="ui-button ui-button--secondary ui-button--md">{text.supportBackToInbox}</Link>}
                />
            ) : (
                <>
                    <div className={styles.compactHeader}>
                        <div className={styles.compactHeaderTrail}>
                            <Link href={`/${locale}/support`} className={styles.compactHeaderLink}>{text.supportTitle}</Link>
                            <span className={styles.compactHeaderSeparator}>/</span>
                            <strong>{shortId(conversation.conversationId)}</strong>
                            <span className={styles.subtle}>{userDisplayName}</span>
                        </div>
                        <div className={styles.compactHeaderMeta}>
                            {conversation.adminUnreadCount > 0 ? <span className={styles.unreadDot}>{conversation.adminUnreadCount}</span> : null}
                            <Button variant="secondary" size="sm" onClick={() => setIsSidePanelOpen((current) => !current)}>
                                {isSidePanelOpen ? text.supportClosePanelAction : text.supportOpenPanelAction}
                            </Button>
                        </div>
                    </div>

                    <div className={`${styles.workspace} ${isSidePanelOpen ? styles.workspaceWithSidebar : styles.workspaceCompact}`}>
                        <AdminCard className={styles.inboxPane}>
                            <div className={styles.paneTopbar}>
                                <div className={styles.paneTitleGroup}>
                                    <span className={styles.paneEyebrow}>{text.supportTitle}</span>
                                    <h2 className={styles.paneTitle}>{text.supportInboxTitle}</h2>
                                    <p className={styles.paneDescription}>{text.supportInboxDescription}</p>
                                </div>
                                <div className={styles.paneCountBadge}>{filteredInboxItems.length}</div>
                            </div>
                            <div className={styles.inboxToolbar}>
                                <SupportOptionGroup
                                    label={text.statusLabel}
                                    value={statusFilter}
                                    options={[
                                        { value: "all", label: text.supportStatusAll },
                                        ...statusOptions.map((status) => ({ value: status, label: statusLabel(status, text) })),
                                    ]}
                                    onChange={(value) => setStatusFilter(value as SupportFilter)}
                                    compact
                                />
                                <label className={styles.searchField}>
                                    <span className={styles.searchLabelHidden}>{text.supportSearchPlaceholder}</span>
                                    <input
                                        className={styles.searchInput}
                                        value={searchQuery}
                                        onChange={(event) => setSearchQuery(event.target.value)}
                                        placeholder={text.supportSearchPlaceholder}
                                    />
                                </label>
                            </div>

                            {inboxQuery.isLoading ? (
                                <AdminStateCard tone="info" title={text.loading} />
                            ) : inboxQuery.isError ? (
                                <AdminStateCard tone="danger" title={text.supportLoadError} />
                            ) : filteredInboxItems.length === 0 ? (
                                <AdminStateCard tone="info" title={text.supportEmpty} />
                            ) : (
                                <div className={styles.list}>
                                    {filteredInboxItems.map((item) => {
                                        const itemSla = getConversationSla(
                                            item.lastMessageAtUtc ?? item.createdAtUtc,
                                            locale,
                                            item.adminUnreadCount,
                                        );

                                        return (
                                            <Link
                                                key={item.conversationId}
                                                href={`/${locale}/support/${item.conversationId}`}
                                                className={`${styles.conversationRow} ${item.conversationId === conversationId ? styles.conversationRowActive : ""}`}
                                            >
                                                <div className={styles.rowHeader}>
                                                    <div className={styles.rowIdentity}>
                                                        <span className={styles.avatar}>{initialsFor(item.userDisplayName?.trim() || item.userEmail)}</span>
                                                        <div className={styles.rowTextStack}>
                                                            <div className={styles.rowTitle}>{item.userDisplayName?.trim() || item.userEmail}</div>
                                                            <div className={styles.rowPreview}><span>{item.lastMessagePreview || text.supportNoMessages}</span></div>
                                                        </div>
                                                    </div>
                                                    <span className={styles.timePill}>{formatRelativeTime(item.lastMessageAtUtc ?? item.updatedAtUtc, locale)}</span>
                                                </div>
                                                <div className={styles.rowSlaLine}>
                                                    <span className={`${styles.slaPill} ${styles[`slaPill_${itemSla.level}`]}`}>
                                                        {itemSla.primaryLabel}
                                                    </span>
                                                    <div className={styles.rowMetaGroup}>
                                                        {item.adminUnreadCount > 0 ? <span className={styles.unreadDot}>{item.adminUnreadCount}</span> : null}
                                                        {item.status !== "Open" ? <span className={styles.rowSecondaryMeta}>{statusLabel(item.status, text)}</span> : null}
                                                        {item.priority.toLowerCase() === "high" ? <span className={styles.rowSecondaryMeta}>{priorityLabel(item.priority, text)}</span> : null}
                                                    </div>
                                                </div>
                                            </Link>
                                        );
                                    })}
                                </div>
                            )}
                        </AdminCard>

                        <div className={styles.chatPane}>
                            <AdminCard className={styles.chatShell}>
                                <div className={styles.chatTopbar}>
                                    <div className={styles.chatIdentityCompact}>
                                        <div className={styles.chatTitleRow}>
                                            <strong className={styles.chatUserName}>{userDisplayName}</strong>
                                            <span className={styles.onlineDot} />
                                        </div>
                                        <div className={styles.chatFacts}>
                                            {chatFacts.map((fact) => (
                                                <span key={fact} className={styles.chatFactChip}>{fact}</span>
                                            ))}
                                        </div>
                                        <div className={styles.chatMetaLine}>
                                            <span>{conversation.userEmail}</span>
                                            <span>•</span>
                                            <span>{shortId(conversation.initiatorUserId)}</span>
                                            <span>•</span>
                                            <span>{`${text.supportAssignedTo}: ${conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}`}</span>
                                        </div>
                                    </div>

                                    <div className={styles.chatHeaderAside}>
                                        <span className={`${styles.slaPill} ${styles[`slaPill_${conversationSla.level}`]}`}>{conversationSla.waitLabel}</span>
                                        <div className={styles.chatStatusControls}>
                                            <AdminBadge tone={toneForStatus(conversation.status)}>{statusLabel(conversation.status, text)}</AdminBadge>
                                            <AdminBadge tone={priorityTone(conversation.priority)}>{priorityLabel(conversation.priority, text)}</AdminBadge>
                                        </div>
                                        <p className={styles.chatStatusNote}>{statusHint(conversation.status, text)}</p>
                                    </div>
                                </div>

                                {conversation.messages.length > 0 ? (
                                    <div className={styles.messagesWrap}>
                                        <div className={styles.dayDivider}>{text.supportTodayLabel}</div>
                                        <div className={styles.messages}>
                                            {conversation.messages.map((message) => (
                                                <article
                                                    key={message.messageId}
                                                    className={`${styles.messageItem} ${message.isFromAdmin ? styles.messageAdmin : styles.messageUser}`}
                                                >
                                                    <div className={styles.messageHeader}>
                                                        <div className={styles.messageSenderWrap}>
                                                            {!message.isFromAdmin ? <span className={styles.avatarTiny}>{initialsFor(message.senderDisplayName)}</span> : null}
                                                            <strong>{message.senderDisplayName}</strong>
                                                        </div>
                                                        <span>{formatClockTime(message.createdAtUtc, locale)}</span>
                                                    </div>
                                                    {hasImageAttachment(message) ? (
                                                        <button
                                                            type="button"
                                                            onClick={() => setFullscreenImage({
                                                                url: message.attachmentUrl!,
                                                                fileName: message.attachmentFileName,
                                                            })}
                                                            className={styles.messageImageButton}
                                                        >
                                                            <Image
                                                                src={message.attachmentUrl!}
                                                                alt={message.attachmentFileName ?? message.body}
                                                                width={704}
                                                                height={576}
                                                                sizes="(max-width: 860px) 100vw, 22rem"
                                                                className={styles.messageImage}
                                                                loading="lazy"
                                                                unoptimized
                                                            />
                                                        </button>
                                                    ) : hasAttachment(message) ? (
                                                        <a
                                                            href={message.attachmentUrl!}
                                                            target="_blank"
                                                            rel="noopener noreferrer"
                                                            download={message.attachmentFileName ?? "attachment"}
                                                            className={styles.messageAttachmentCard}
                                                        >
                                                            <div className={styles.messageAttachmentIcon}>FILE</div>
                                                            <div className={styles.messageAttachmentMeta}>
                                                                <strong>{message.attachmentFileName ?? message.body}</strong>
                                                                <span>{formatFileSize(message.attachmentFileSizeBytes, locale)}</span>
                                                            </div>
                                                        </a>
                                                    ) : null}
                                                    {shouldRenderMessageBody(message) ? <div className={styles.messageBody}>{message.body}</div> : null}
                                                    {message.attachmentUploadStatus ? (
                                                        <div className={styles.messageAttachmentStatusRow}>
                                                            <span
                                                                className={`${styles.messageAttachmentStatusPill} ${styles[`messageAttachmentStatus_${message.attachmentUploadStatus.toLowerCase()}`] ?? ""}`}
                                                            >
                                                                {message.attachmentUploadStatus}
                                                            </span>
                                                            {message.attachmentUploadErrorCode ? (
                                                                <span className={styles.messageAttachmentStatusErrorCode}>
                                                                    {message.attachmentUploadErrorCode}
                                                                </span>
                                                            ) : null}
                                                        </div>
                                                    ) : null}
                                                </article>
                                            ))}
                                        </div>
                                    </div>
                                ) : (
                                    <AdminStateCard tone="info" title={text.supportNoMessages} />
                                )}

                                <div className={styles.composerShell}>
                                    {visibleTemplates.length > 0 ? (
                                        <div className={styles.composerTemplateRail}>
                                            <span className={styles.subtle}>
                                                {text.supportQuickRepliesLabel}
                                            </span>
                                            <div className={styles.templateList}>
                                                {visibleTemplates.map((template) => (
                                                    <Button
                                                        key={template.templateId}
                                                        size="sm"
                                                        variant="ghost"
                                                        className={styles.quickTemplateButton}
                                                        onClick={() => applyTemplate(template)}
                                                    >
                                                        {`✓ ${template.title}`}
                                                    </Button>
                                                ))}
                                            </div>
                                        </div>
                                    ) : null}

                                    <input
                                        ref={attachmentInputRef}
                                        type="file"
                                        className={styles.hiddenFileInput}
                                        accept="image/jpeg,image/png,image/webp"
                                        onChange={(event) => {
                                            const nextFile = event.target.files?.[0] ?? null;
                                            setSelectedAttachment(nextFile);
                                        }}
                                    />
                                    <div className={styles.composerAttachmentBar}>
                                        <Button
                                            variant="secondary"
                                            size="sm"
                                            onClick={() => attachmentInputRef.current?.click()}
                                            disabled={sendMutation.isPending}
                                        >
                                            {text.chooseFile}
                                        </Button>
                                        <span className={styles.subtle}>{text.supportAttachmentHint}</span>
                                    </div>
                                    {selectedAttachment ? (
                                        <div className={styles.attachmentPreviewCard}>
                                            {attachmentPreviewUrl ? (
                                                <button
                                                    type="button"
                                                    className={styles.attachmentPreviewImageButton}
                                                    onClick={() => setFullscreenImage({
                                                        url: attachmentPreviewUrl,
                                                        fileName: selectedAttachment.name,
                                                    })}
                                                >
                                                    <Image
                                                        src={attachmentPreviewUrl}
                                                        alt={selectedAttachment.name}
                                                        width={72}
                                                        height={72}
                                                        sizes="72px"
                                                        className={styles.attachmentPreviewImage}
                                                        unoptimized
                                                    />
                                                </button>
                                            ) : (
                                                <div className={styles.attachmentPreviewFileIcon}>FILE</div>
                                            )}
                                            <div className={styles.attachmentPreviewMeta}>
                                                <span className={styles.subtle}>{text.selectedFileLabel}</span>
                                                <strong>{selectedAttachment.name}</strong>
                                                <span className={styles.subtle}>{formatFileSize(selectedAttachment.size, locale)}</span>
                                            </div>
                                            <div className={styles.attachmentPreviewActions}>
                                                {attachmentPreviewUrl ? (
                                                    <button
                                                        type="button"
                                                        className={styles.attachmentActionButton}
                                                        onClick={() => setFullscreenImage({
                                                            url: attachmentPreviewUrl,
                                                            fileName: selectedAttachment.name,
                                                        })}
                                                    >
                                                        {text.supportAttachmentOpenAction}
                                                    </button>
                                                ) : null}
                                                <Button variant="ghost" size="sm" onClick={resetSelectedAttachment}>
                                                    {text.supportAttachmentRemoveAction}
                                                </Button>
                                            </div>
                                        </div>
                                    ) : null}

                                    <textarea
                                        className={styles.textarea}
                                        value={composerValue}
                                        onChange={(event) => setReply(event.target.value)}
                                        placeholder={composerPlaceholder}
                                    />

                                    <div className={styles.composerActions}>
                                        <div className={styles.composerContextHint}>
                                            <span className={styles.subtle}>{`${text.supportMessagesCount}: ${conversation.messages.length}`}</span>
                                            <span className={styles.subtle}>{`${text.supportUnreadAdmin}: ${conversation.adminUnreadCount}`}</span>
                                            <span className={styles.subtle}>{`${text.supportUnreadUser}: ${conversation.userUnreadCount}`}</span>
                                        </div>
                                        <div className={styles.rowMetaGroup}>
                                            <Button
                                                variant="primary"
                                                onClick={() => sendMutation.mutate()}
                                                disabled={sendMutation.isPending || (!reply.trim() && !hasComposerAttachment)}
                                            >
                                                {sendMutation.isPending ? text.supportReplySending : text.supportReplyAction}
                                            </Button>
                                        </div>
                                    </div>
                                </div>
                            </AdminCard>
                        </div>

                        {isSidePanelOpen ? <div className={styles.sidePane}>
                            <AdminCard className={`${styles.sideCard} ${styles.sidePanelCard}`}>
                                <div className={styles.sidePanelTopbar}>
                                    <div className={styles.paneTitleGroup}>
                                        <span className={styles.paneEyebrow}>{text.supportConversationDetailsTitle}</span>
                                        <h2 className={styles.paneTitle}>{sidePanelTitle}</h2>
                                        {sidePanelDescription ? <p className={styles.paneDescription}>{sidePanelDescription}</p> : null}
                                    </div>
                                    <div className={styles.sidePanelTabs}>
                                        {sidePanelTabs.map(({ value, label }) => (
                                            <button
                                                key={value}
                                                type="button"
                                                className={`${styles.sidePanelTab} ${activeSidePanelTab === value ? styles.sidePanelTabActive : ""}`}
                                                onClick={() => setActiveSidePanelTab(value)}
                                            >
                                                {label}
                                            </button>
                                        ))}
                                    </div>
                                </div>
                                {activeSidePanelTab === "profile" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.statusOverviewCard}>
                                            <div className={styles.statusOverviewHeader}>
                                                <div className={styles.statusOverviewCopy}>
                                                    <span className={styles.paneEyebrow}>{text.supportStatusWorkflowTitle}</span>
                                                    <strong className={styles.statusOverviewTitle}>{statusLabel(conversation.status, text)}</strong>
                                                    <p className={styles.statusOverviewText}>{statusHint(conversation.status, text)}</p>
                                                </div>
                                                <AdminBadge tone={toneForStatus(conversation.status)}>{statusLabel(conversation.status, text)}</AdminBadge>
                                            </div>
                                            <div className={styles.workflowPrimaryRow}>
                                                <Button
                                                    variant="secondary"
                                                    className={styles.workflowSecondaryButton}
                                                    onClick={() => assignmentMutation.mutate(isAssignedToCurrentAdmin ? null : sessionUserId)}
                                                    disabled={assignmentMutation.isPending || !sessionUserId}
                                                >
                                                    {isAssignedToCurrentAdmin ? text.supportUnassign : text.supportAssignToMe}
                                                </Button>
                                                {primaryStatusAction ? (
                                                    <Button
                                                        variant="primary"
                                                        className={styles.workflowPrimaryButton}
                                                        onClick={() => statusMutation.mutate(primaryStatusAction.status)}
                                                        disabled={statusMutation.isPending || conversation.status === primaryStatusAction.status}
                                                    >
                                                        {primaryStatusAction.label}
                                                    </Button>
                                                ) : null}
                                            </div>
                                            {secondaryStatusActions.length ? (
                                                <div className={styles.workflowSecondaryGrid}>
                                                    {secondaryStatusActions.map((action) => (
                                                        <Button
                                                            key={action.status}
                                                            variant="secondary"
                                                            className={styles.workflowSecondaryButton}
                                                            onClick={() => statusMutation.mutate(action.status)}
                                                            disabled={statusMutation.isPending || conversation.status === action.status}
                                                        >
                                                            {action.label}
                                                        </Button>
                                                    ))}
                                                </div>
                                            ) : null}
                                            {destructiveStatusAction ? (
                                                <div className={styles.workflowDangerZone}>
                                                    <span className={styles.workflowDangerLabel}>{text.supportCloseConversationAction}</span>
                                                    <Button
                                                        variant="danger"
                                                        className={styles.workflowDangerButton}
                                                        onClick={() => statusMutation.mutate(destructiveStatusAction.status)}
                                                        disabled={statusMutation.isPending || conversation.status === destructiveStatusAction.status}
                                                    >
                                                        {destructiveStatusAction.label}
                                                    </Button>
                                                </div>
                                            ) : null}
                                            <p className={styles.statusOverviewHint}>{text.supportStatusAutomationHint}</p>
                                        </div>

                                        <div className={styles.userSummaryHeader}>
                                            <div className={styles.userCard}>
                                                <span className={styles.avatarHero}>{initialsFor(userDisplayName)}</span>
                                                <div className={styles.userCardBody}>
                                                    <strong>{userDisplayName}</strong>
                                                    <span>{conversation.userEmail}</span>
                                                    <span>{`User ID: ${shortId(conversation.initiatorUserId)}`}</span>
                                                </div>
                                            </div>
                                            <Link href={`/${locale}/users/${conversation.initiatorUserId}`} className="ui-button ui-button--secondary ui-button--sm">
                                                {text.userOpenFullProfile}
                                            </Link>
                                        </div>

                                        <div className={styles.rowMetaGroup}>
                                            <AdminBadge tone={userQuery.data?.isPremium ? "warning" : "neutral"}>{userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel}</AdminBadge>
                                            <AdminBadge tone={userQuery.data?.isActive === false ? "danger" : "success"}>{userQuery.data?.isActive === false ? text.noLabel : text.activeLabel}</AdminBadge>
                                            <AdminBadge tone={userQuery.data?.emailConfirmed ? "info" : "neutral"}>{userQuery.data?.emailConfirmed ? text.emailConfirmedLabel : text.noLabel}</AdminBadge>
                                        </div>

                                        <div className={styles.metricsGrid}>
                                            <div className={styles.metricTile}><span>{text.supportPlanLabel}</span><strong>{userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportAccountAgeLabel}</span><strong>{formatAccountAge(accountCreatedAt, locale)}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportMessagesCount}</span><strong>{String(conversation.messages.length)}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportPurchasesLabel}</span><strong>{String(totalPurchases)}</strong></div>
                                        </div>

                                        <SectionBlock title={text.supportConversationMetaTitle}>
                                            <div className={styles.detailGrid}>
                                                <div className={styles.detailRow}><span>{text.statusLabel}</span><strong>{statusLabel(conversation.status, text)}</strong></div>
                                                <div className={styles.detailRow}><span>{text.supportAssignedTo}</span><strong>{conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}</strong></div>
                                                <div className={styles.detailRow}><span>{text.createdAtLabel}</span><strong>{formatDateTime(conversation.createdAtUtc, locale)}</strong></div>
                                                <div className={styles.detailRow}><span>{text.supportLastMessage}</span><strong>{formatDateTime(conversation.lastMessageAtUtc ?? conversation.createdAtUtc, locale)}</strong></div>
                                                <div className={styles.detailRow}><span>{text.supportLastSeenLabel}</span><strong>{formatRelativeTime(analyticsQuery.data?.summary.lastActivityAtUtc, locale)}</strong></div>
                                            </div>
                                        </SectionBlock>
                                    </div>
                                ) : null}

                                {activeSidePanelTab === "purchases" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.metricsGrid}>
                                            <div className={styles.metricTile}><span>{text.supportPurchasesLabel}</span><strong>{String(totalPurchases)}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportLastPaymentLabel}</span><strong>{analyticsQuery.data?.summary.lastPurchaseAtUtc ? formatRelativeTime(analyticsQuery.data.summary.lastPurchaseAtUtc, locale) : "—"}</strong></div>
                                        </div>

                                        <SectionBlock title={text.supportRecentPurchasesTitle}>
                                            <SidePanelAsyncState
                                                isLoading={analyticsQuery.isLoading}
                                                isError={analyticsQuery.isError}
                                                hasContent={Boolean(analyticsQuery.data?.recentPurchases.length)}
                                                loadingTitle={text.loading}
                                                errorTitle={text.supportLoadError}
                                                emptyTitle={text.supportNoPurchases}
                                            >
                                                <div className={styles.timelineList}>
                                                    {(analyticsQuery.data?.recentPurchases ?? []).slice(0, 4).map((purchase) => (
                                                        <TimelineCard
                                                            key={purchase.orderId}
                                                            title={formatMoney(purchase.priceAmount, purchase.currencyCode, locale)}
                                                            timestampLabel={formatRelativeTime(purchase.confirmedAtUtc ?? purchase.createdAtUtc, locale)}
                                                            meta={(
                                                                <>
                                                                    <AdminBadge tone={purchase.status.toLowerCase() === "paid" || purchase.status.toLowerCase() === "completed" ? "success" : "warning"}>{purchase.status}</AdminBadge>
                                                                    <span className={styles.subtle}>{`${purchase.sparkToGrant} spark`}</span>
                                                                </>
                                                            )}
                                                            details={purchase.paymentProvider}
                                                        />
                                                    ))}
                                                </div>
                                            </SidePanelAsyncState>
                                        </SectionBlock>
                                    </div>
                                ) : null}

                                {activeSidePanelTab === "generations" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.metricsGrid}>
                                            <div className={styles.metricTile}><span>{text.completedGenerationsLabel}</span><strong>{analyticsQuery.data ? String(analyticsQuery.data.summary.completedGenerations) : "—"}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportLastGenerationLabel}</span><strong>{formatRelativeTime(analyticsQuery.data?.summary.lastGenerationAtUtc, locale)}</strong></div>
                                        </div>

                                        <SectionBlock title={text.supportRecentGenerationsTitle}>
                                            <SidePanelAsyncState
                                                isLoading={analyticsQuery.isLoading}
                                                isError={analyticsQuery.isError}
                                                hasContent={Boolean(analyticsQuery.data?.recentGenerations.length)}
                                                loadingTitle={text.loading}
                                                errorTitle={text.supportLoadError}
                                                emptyTitle={text.userNoGenerations}
                                            >
                                                <div className={styles.timelineList}>
                                                    {(analyticsQuery.data?.recentGenerations ?? []).slice(0, 4).map((generation) => (
                                                        <TimelineCard
                                                            key={generation.generationId}
                                                            title={generation.templateTitle}
                                                            timestampLabel={formatRelativeTime(generation.completedAtUtc ?? generation.createdAtUtc, locale)}
                                                            meta={(
                                                                <>
                                                                    <AdminBadge tone={toneForGeneration(generation.status)}>{generation.status}</AdminBadge>
                                                                    <span className={styles.subtle}>{`${generation.tokenCost} spark`}</span>
                                                                </>
                                                            )}
                                                            details={generation.failureMessage || undefined}
                                                        />
                                                    ))}
                                                </div>
                                            </SidePanelAsyncState>
                                        </SectionBlock>
                                    </div>
                                ) : null}

                                {activeSidePanelTab === "errors" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.metricsGrid}>
                                            <div className={styles.metricTile}><span>{text.supportGenerationErrorsTitle}</span><strong>{String(analyticsQuery.data?.summary.failedGenerations ?? failedGenerations.length)}</strong></div>
                                            <div className={styles.metricTile}><span>{text.supportLastSeenLabel}</span><strong>{recentFailures[0]?.lastOccurredAtUtc ? formatRelativeTime(recentFailures[0].lastOccurredAtUtc, locale) : "—"}</strong></div>
                                        </div>

                                        <SectionBlock title={text.supportGenerationErrorsTitle}>
                                            <SidePanelAsyncState
                                                isLoading={analyticsQuery.isLoading}
                                                isError={analyticsQuery.isError}
                                                hasContent={recentFailures.length > 0 || failedGenerations.length > 0}
                                                loadingTitle={text.loading}
                                                errorTitle={text.supportLoadError}
                                                emptyTitle={text.supportNoGenerationErrors}
                                            >
                                                {recentFailures.length ? (
                                                    <div className={styles.timelineList}>
                                                        {recentFailures.map((item) => (
                                                            <TimelineCard
                                                                key={item.failureCode}
                                                                title={item.failureCode}
                                                                timestampLabel={formatRelativeTime(item.lastOccurredAtUtc, locale)}
                                                                details={`${text.supportOccurrencesLabel}: ${item.count}`}
                                                            />
                                                        ))}
                                                    </div>
                                                ) : (
                                                    <div className={styles.timelineList}>
                                                        {failedGenerations.slice(0, 3).map((generation) => (
                                                            <TimelineCard
                                                                key={generation.generationId}
                                                                title={generation.templateTitle}
                                                                timestampLabel={formatRelativeTime(generation.completedAtUtc ?? generation.createdAtUtc, locale)}
                                                                details={generation.failureMessage ?? generation.failureCode ?? generation.status}
                                                            />
                                                        ))}
                                                    </div>
                                                )}
                                            </SidePanelAsyncState>
                                        </SectionBlock>
                                    </div>
                                ) : null}

                                {activeSidePanelTab === "templates" ? (
                                    <div className={styles.sidePanelContent}>
                                        <div className={styles.templateCatalogControls}>
                                            <label className={styles.searchField}>
                                                <span className={styles.searchLabel}>{text.supportTemplateSearchPlaceholder}</span>
                                                <input
                                                    className={styles.searchInput}
                                                    value={templateSearchQuery}
                                                    onChange={(event) => setTemplateSearchQuery(event.target.value)}
                                                    placeholder={text.supportTemplateSearchPlaceholder}
                                                />
                                            </label>
                                            <div className={styles.templateToolbarCompact}>
                                                <Button size="sm" variant="secondary" onClick={() => openTemplateEditor()}>
                                                    {text.supportTemplateCreateAction}
                                                </Button>
                                            </div>
                                        </div>

                                        <SidePanelAsyncState
                                            isLoading={templatesQuery.isLoading}
                                            isError={templatesQuery.isError}
                                            hasContent={filteredTemplates.length > 0}
                                            loadingTitle={text.loading}
                                            errorTitle={text.supportLoadError}
                                            emptyTitle={text.supportTemplateNoTemplates}
                                        >
                                            <>
                                                <div className={styles.templateCatalogList}>
                                                    {filteredTemplates.map((template) => (
                                                        <button
                                                            key={template.templateId}
                                                            type="button"
                                                            className={`${styles.templateListItem} ${selectedTemplate?.templateId === template.templateId ? styles.templateListItemActive : ""}`}
                                                            onClick={() => setSelectedTemplateId(template.templateId)}
                                                        >
                                                            <div className={styles.templateListItemHeader}>
                                                                <div className={styles.templateTitleStack}>
                                                                    <strong className={styles.rowTitle}>{template.title}</strong>
                                                                    <span className={styles.subtle}>{`${text.supportUpdatedLabel}: ${formatRelativeTime(template.updatedAtUtc, locale)}`}</span>
                                                                </div>
                                                                <div className={styles.rowMetaGroup}>
                                                                    <AdminBadge tone="primary">{text.supportTemplateKindReply}</AdminBadge>
                                                                    {!template.isEnabled ? <AdminBadge tone="neutral">{text.supportTemplateDisabledBadge}</AdminBadge> : null}
                                                                </div>
                                                            </div>
                                                            <div className={styles.templateSnippet}>{template.body}</div>
                                                        </button>
                                                    ))}
                                                </div>

                                                {selectedTemplate ? (
                                                    <div className={styles.templateDetailPane}>
                                                        <div className={styles.templatePreviewHeader}>
                                                            <div className={styles.templateTitleStack}>
                                                                <strong className={styles.chatUserName}>{selectedTemplate.title}</strong>
                                                                <span className={styles.subtle}>{`${text.supportUpdatedLabel}: ${formatDateTime(selectedTemplate.updatedAtUtc, locale)}`}</span>
                                                            </div>
                                                            <div className={styles.templateRowActions}>
                                                                <Button size="sm" variant="primary" onClick={() => applyTemplate(selectedTemplate)}>
                                                                    {text.supportTemplateUseAction}
                                                                </Button>
                                                                <Button size="sm" variant="secondary" onClick={() => openTemplateEditor(selectedTemplate)}>
                                                                    {text.supportTemplateEditAction}
                                                                </Button>
                                                                <Button
                                                                    size="sm"
                                                                    variant="danger"
                                                                    onClick={() => templateDeleteMutation.mutate(selectedTemplate.templateId)}
                                                                    disabled={templateDeleteMutation.isPending}
                                                                >
                                                                    {text.supportTemplateDeleteAction}
                                                                </Button>
                                                            </div>
                                                        </div>
                                                        <div className={styles.templatePreviewBody}>{selectedTemplate.body}</div>
                                                    </div>
                                                ) : null}

                                                {isTemplateEditorOpen ? (
                                                    <div className={styles.templateEditor}>
                                                        <div className={styles.templateEditorHeader}>
                                                            <strong className={styles.chatUserName}>
                                                                {templateDraft.templateId ? text.supportTemplateUpdateAction : text.supportTemplateCreateAction}
                                                            </strong>
                                                            <span className={styles.subtle}>{text.supportTemplatesManagerDescription}</span>
                                                        </div>

                                                        <div className={styles.templateForm}>
                                                            <label className={styles.templateSection}>
                                                                <span className={styles.subtle}>{text.supportTemplateTitleLabel}</span>
                                                                <input
                                                                    className={styles.input}
                                                                    value={templateDraft.title}
                                                                    onChange={(event) => setTemplateDraft((current) => ({ ...current, title: event.target.value }))}
                                                                />
                                                            </label>

                                                            <label className={styles.templateSection}>
                                                                <span className={styles.subtle}>{text.supportTemplateBodyLabel}</span>
                                                                <textarea
                                                                    className={styles.textarea}
                                                                    value={templateDraft.body}
                                                                    onChange={(event) => setTemplateDraft((current) => ({ ...current, body: event.target.value }))}
                                                                />
                                                            </label>

                                                            <div className={styles.templateFormGrid}>
                                                                <label className={styles.templateSection}>
                                                                    <span className={styles.subtle}>{text.supportTemplateSortOrderLabel}</span>
                                                                    <input
                                                                        className={styles.input}
                                                                        type="number"
                                                                        min={0}
                                                                        value={String(templateDraft.sortOrder)}
                                                                        onChange={(event) => setTemplateDraft((current) => ({ ...current, sortOrder: Number(event.target.value) || 0 }))}
                                                                    />
                                                                </label>
                                                            </div>

                                                            <label className={styles.checkboxRow}>
                                                                <input
                                                                    type="checkbox"
                                                                    checked={templateDraft.isEnabled}
                                                                    onChange={(event) => setTemplateDraft((current) => ({ ...current, isEnabled: event.target.checked }))}
                                                                />
                                                                <span>{text.supportTemplateEnabledLabel}</span>
                                                            </label>

                                                            <div className={styles.templateRowActions}>
                                                                <Button
                                                                    variant="primary"
                                                                    onClick={() => templateSaveMutation.mutate()}
                                                                    disabled={templateSaveMutation.isPending || !templateDraft.title.trim() || !templateDraft.body.trim()}
                                                                >
                                                                    {templateSaveMutation.isPending
                                                                        ? text.loading
                                                                        : templateDraft.templateId
                                                                            ? text.supportTemplateUpdateAction
                                                                            : text.supportTemplateCreateAction}
                                                                </Button>
                                                                <Button variant="secondary" onClick={() => setTemplateDraft(emptyTemplateDraft)}>
                                                                    {text.supportTemplateResetAction}
                                                                </Button>
                                                                <Button variant="secondary" onClick={() => setIsTemplateEditorOpen(false)}>
                                                                    {text.supportTemplateCancelEditAction}
                                                                </Button>
                                                            </div>
                                                        </div>
                                                    </div>
                                                ) : null}
                                            </>
                                        </SidePanelAsyncState>
                                    </div>
                                ) : null}

                                {activeSidePanelTab === "history" ? (
                                    <div className={styles.sidePanelContent}>
                                        <SectionBlock title={text.supportTimelineTitle}>
                                            {conversationTimeline.length ? (
                                                <div className={styles.timelineList}>
                                                    {conversationTimeline.map((item) => (
                                                        <TimelineCard
                                                            key={item.id}
                                                            title={item.title}
                                                            timestampLabel={formatRelativeTime(item.occurredAtUtc, locale)}
                                                            meta={<AdminBadge tone={item.tone}>{formatDateTime(item.occurredAtUtc, locale)}</AdminBadge>}
                                                            details={item.subtitle}
                                                        />
                                                    ))}
                                                </div>
                                            ) : (
                                                <AdminStateCard tone="info" title={text.supportHistoryEmpty} />
                                            )}
                                        </SectionBlock>

                                        <SectionBlock title={text.userActivityTitle}>
                                            <SidePanelAsyncState
                                                isLoading={analyticsQuery.isLoading}
                                                isError={analyticsQuery.isError}
                                                hasContent={activityTimeline.length > 0}
                                                loadingTitle={text.loading}
                                                errorTitle={text.supportLoadError}
                                                emptyTitle={text.supportHistoryEmpty}
                                            >
                                                <div className={styles.timelineList}>
                                                    {activityTimeline.map((item) => (
                                                        <TimelineCard
                                                            key={item.id}
                                                            title={item.title}
                                                            timestampLabel={formatRelativeTime(item.occurredAtUtc, locale)}
                                                            details={item.subtitle}
                                                        />
                                                    ))}
                                                </div>
                                            </SidePanelAsyncState>
                                        </SectionBlock>
                                    </div>
                                ) : null}
                            </AdminCard>
                        </div> : null}
                    </div>
                    {fullscreenImage ? (
                        <div className={styles.imageViewerOverlay} role="dialog" aria-modal="true">
                            <div className={styles.imageViewerPanel}>
                                <div className={styles.imageViewerHeader}>
                                    <strong>{fullscreenImage.fileName?.trim() || "Image"}</strong>
                                    <Button variant="ghost" size="sm" onClick={closeFullscreenImage}>
                                        Close
                                    </Button>
                                </div>
                                <div className={styles.imageViewerBody}>
                                    <Image
                                        src={fullscreenImage.url}
                                        alt={fullscreenImage.fileName ?? "Support image"}
                                        width={1720}
                                        height={980}
                                        sizes="100vw"
                                        className={styles.imageViewerImage}
                                        unoptimized
                                    />
                                </div>
                                <div className={styles.imageViewerActions}>
                                    <Button variant="secondary" size="sm" onClick={saveFullscreenImage}>
                                        Save image
                                    </Button>
                                    <Button variant="secondary" size="sm" onClick={shareFullscreenImage}>
                                        Share
                                    </Button>
                                    <Button variant="secondary" size="sm" onClick={openFullscreenImageInNewTab}>
                                        Open original
                                    </Button>
                                    <Button variant="primary" size="sm" onClick={closeFullscreenImage}>
                                        Close
                                    </Button>
                                </div>
                            </div>
                        </div>
                    ) : null}
                </>
            )}
        </AdminPage>
    );
}

