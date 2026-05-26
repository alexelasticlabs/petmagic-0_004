import Link from "next/link";

import {
    AdminBadge,
    AdminCard,
    AdminStateCard,
} from "@/components/admin/admin-primitives";
import {
    formatAccountAge,
    formatDateTime,
    formatMoney,
    formatRelativeTime,
    initialsFor,
    shortId,
} from "@/components/support/support-conversation-helpers";
import {
    SectionBlock,
    SidePanelAsyncState,
    TimelineCard,
} from "@/components/support/support-conversation-ui-primitives";
import styles from "@/components/support/support-page.module.css";
import {
    statusHint,
    statusLabel,
    toneForGeneration,
    toneForStatus,
} from "@/components/support/support-status-helpers";
import {
    emptyTemplateDraft,
    useSupportConversationController,
} from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { type Locale } from "@/lib/i18n";

type SupportConversationSidePanelProps = {
    locale: Locale;
    controller: ReturnType<typeof useSupportConversationController>;
};

export function SupportConversationSidePanel({
    locale,
    controller,
}: SupportConversationSidePanelProps) {
    const {
        activeSidePanelTab,
        activityTimeline,
        analyticsQuery,
        applyTemplate,
        assignmentMutation,
        conversation,
        conversationTimeline,
        destructiveStatusAction,
        failedGenerations,
        filteredTemplates,
        isAssignedToCurrentAdmin,
        isSidePanelOpen,
        isTemplateEditorOpen,
        openTemplateEditor,
        primaryStatusAction,
        recentFailures,
        selectedTemplate,
        secondaryStatusActions,
        sessionUserId,
        setActiveSidePanelTab,
        setIsTemplateEditorOpen,
        setSelectedTemplateId,
        setTemplateDraft,
        setTemplateSearchQuery,
        sidePanelDescription,
        sidePanelTabs,
        sidePanelTitle,
        templateDeleteMutation,
        templateDraft,
        templateSaveMutation,
        templateSearchQuery,
        templatesQuery,
        text,
        totalPurchases,
        userDisplayName,
        userQuery,
        statusMutation,
    } = controller;

    if (!isSidePanelOpen || !conversation) {
        return null;
    }

    return (
        <div className={styles.sidePane}>
            <AdminCard className={`${styles.sideCard} ${styles.sidePanelCard}`}>
                <div className={styles.sidePanelTopbar}>
                    <div className={styles.paneTitleGroup}>
                        <span className={styles.paneEyebrow}>{text.supportConversationDetailsTitle}</span>
                        <h2 className={styles.paneTitle}>{sidePanelTitle}</h2>
                        {sidePanelDescription ? (
                            <p className={styles.paneDescription}>{sidePanelDescription}</p>
                        ) : null}
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
                                    <strong className={styles.statusOverviewTitle}>
                                        {statusLabel(conversation.status, text)}
                                    </strong>
                                    <p className={styles.statusOverviewText}>{statusHint(conversation.status, text)}</p>
                                </div>
                                <AdminBadge tone={toneForStatus(conversation.status)}>
                                    {statusLabel(conversation.status, text)}
                                </AdminBadge>
                            </div>
                            <div className={styles.workflowPrimaryRow}>
                                <Button
                                    variant="secondary"
                                    className={styles.workflowSecondaryButton}
                                    onClick={() =>
                                        assignmentMutation.mutate(isAssignedToCurrentAdmin ? null : sessionUserId)
                                    }
                                    disabled={assignmentMutation.isPending || !sessionUserId}
                                >
                                    {isAssignedToCurrentAdmin ? text.supportUnassign : text.supportAssignToMe}
                                </Button>
                                {primaryStatusAction ? (
                                    <Button
                                        variant="primary"
                                        className={styles.workflowPrimaryButton}
                                        onClick={() => statusMutation.mutate(primaryStatusAction.status)}
                                        disabled={
                                            statusMutation.isPending ||
                                            conversation.status === primaryStatusAction.status
                                        }
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
                                    <span className={styles.workflowDangerLabel}>
                                        {text.supportCloseConversationAction}
                                    </span>
                                    <Button
                                        variant="danger"
                                        className={styles.workflowDangerButton}
                                        onClick={() => statusMutation.mutate(destructiveStatusAction.status)}
                                        disabled={
                                            statusMutation.isPending ||
                                            conversation.status === destructiveStatusAction.status
                                        }
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
                            <Link
                                href={`/${locale}/users/${conversation.initiatorUserId}`}
                                className="ui-button ui-button--secondary ui-button--sm"
                            >
                                {text.userOpenFullProfile}
                            </Link>
                        </div>

                        <div className={styles.rowMetaGroup}>
                            <AdminBadge tone={userQuery.data?.isPremium ? "warning" : "neutral"}>
                                {userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel}
                            </AdminBadge>
                            <AdminBadge tone={userQuery.data?.isActive === false ? "danger" : "success"}>
                                {userQuery.data?.isActive === false ? text.noLabel : text.activeLabel}
                            </AdminBadge>
                            <AdminBadge tone={userQuery.data?.emailConfirmed ? "info" : "neutral"}>
                                {userQuery.data?.emailConfirmed ? text.emailConfirmedLabel : text.noLabel}
                            </AdminBadge>
                        </div>

                        <div className={styles.metricsGrid}>
                            <div className={styles.metricTile}>
                                <span>{text.supportPlanLabel}</span>
                                <strong>{userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel}</strong>
                            </div>
                            <div className={styles.metricTile}>
                                <span>{text.supportAccountAgeLabel}</span>
                                <strong>{formatAccountAge(controller.accountCreatedAt, locale)}</strong>
                            </div>
                            <div className={styles.metricTile}>
                                <span>{text.supportMessagesCount}</span>
                                <strong>{String(conversation.messages.length)}</strong>
                            </div>
                            <div className={styles.metricTile}>
                                <span>{text.supportPurchasesLabel}</span>
                                <strong>{String(totalPurchases)}</strong>
                            </div>
                        </div>

                        <SectionBlock title={text.supportConversationMetaTitle}>
                            <div className={styles.detailGrid}>
                                <div className={styles.detailRow}>
                                    <span>{text.statusLabel}</span>
                                    <strong>{statusLabel(conversation.status, text)}</strong>
                                </div>
                                <div className={styles.detailRow}>
                                    <span>{text.supportAssignedTo}</span>
                                    <strong>{conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}</strong>
                                </div>
                                <div className={styles.detailRow}>
                                    <span>{text.createdAtLabel}</span>
                                    <strong>{formatDateTime(conversation.createdAtUtc, locale)}</strong>
                                </div>
                                <div className={styles.detailRow}>
                                    <span>{text.supportLastMessage}</span>
                                    <strong>
                                        {formatDateTime(
                                            conversation.lastMessageAtUtc ?? conversation.createdAtUtc,
                                            locale
                                        )}
                                    </strong>
                                </div>
                                <div className={styles.detailRow}>
                                    <span>{text.supportLastSeenLabel}</span>
                                    <strong>
                                        {formatRelativeTime(analyticsQuery.data?.summary.lastActivityAtUtc, locale)}
                                    </strong>
                                </div>
                            </div>
                        </SectionBlock>
                    </div>
                ) : null}

                {activeSidePanelTab === "purchases" ? (
                    <div className={styles.sidePanelContent}>
                        <div className={styles.metricsGrid}>
                            <div className={styles.metricTile}>
                                <span>{text.supportPurchasesLabel}</span>
                                <strong>{String(totalPurchases)}</strong>
                            </div>
                            <div className={styles.metricTile}>
                                <span>{text.supportLastPaymentLabel}</span>
                                <strong>
                                    {analyticsQuery.data?.summary.lastPurchaseAtUtc
                                        ? formatRelativeTime(analyticsQuery.data.summary.lastPurchaseAtUtc, locale)
                                        : "—"}
                                </strong>
                            </div>
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
                                            timestampLabel={formatRelativeTime(
                                                purchase.confirmedAtUtc ?? purchase.createdAtUtc,
                                                locale
                                            )}
                                            meta={
                                                <>
                                                    <AdminBadge
                                                        tone={
                                                            purchase.status.toLowerCase() === "paid" ||
                                                                purchase.status.toLowerCase() === "completed"
                                                                ? "success"
                                                                : "warning"
                                                        }
                                                    >
                                                        {purchase.status}
                                                    </AdminBadge>
                                                    <span className={styles.subtle}>{`${purchase.sparkToGrant} spark`}</span>
                                                </>
                                            }
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
                            <div className={styles.metricTile}>
                                <span>{text.completedGenerationsLabel}</span>
                                <strong>
                                    {analyticsQuery.data
                                        ? String(analyticsQuery.data.summary.completedGenerations)
                                        : "—"}
                                </strong>
                            </div>
                            <div className={styles.metricTile}>
                                <span>{text.supportLastGenerationLabel}</span>
                                <strong>
                                    {formatRelativeTime(analyticsQuery.data?.summary.lastGenerationAtUtc, locale)}
                                </strong>
                            </div>
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
                                    {(analyticsQuery.data?.recentGenerations ?? [])
                                        .slice(0, 4)
                                        .map((generation) => (
                                            <TimelineCard
                                                key={generation.generationId}
                                                title={generation.templateTitle}
                                                timestampLabel={formatRelativeTime(
                                                    generation.completedAtUtc ?? generation.createdAtUtc,
                                                    locale
                                                )}
                                                meta={
                                                    <>
                                                        <AdminBadge tone={toneForGeneration(generation.status)}>
                                                            {generation.status}
                                                        </AdminBadge>
                                                        <span className={styles.subtle}>{`${generation.tokenCost} spark`}</span>
                                                    </>
                                                }
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
                            <div className={styles.metricTile}>
                                <span>{text.supportGenerationErrorsTitle}</span>
                                <strong>
                                    {String(
                                        analyticsQuery.data?.summary.failedGenerations ??
                                        failedGenerations.length
                                    )}
                                </strong>
                            </div>
                            <div className={styles.metricTile}>
                                <span>{text.supportLastSeenLabel}</span>
                                <strong>
                                    {recentFailures[0]?.lastOccurredAtUtc
                                        ? formatRelativeTime(recentFailures[0].lastOccurredAtUtc, locale)
                                        : "—"}
                                </strong>
                            </div>
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
                                                timestampLabel={formatRelativeTime(
                                                    generation.completedAtUtc ?? generation.createdAtUtc,
                                                    locale
                                                )}
                                                details={
                                                    generation.failureMessage ?? generation.failureCode ?? generation.status
                                                }
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
                                                    {!template.isEnabled ? (
                                                        <AdminBadge tone="neutral">
                                                            {text.supportTemplateDisabledBadge}
                                                        </AdminBadge>
                                                    ) : null}
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
                                                <Button
                                                    size="sm"
                                                    variant="secondary"
                                                    onClick={() => openTemplateEditor(selectedTemplate)}
                                                >
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
                                                {templateDraft.templateId
                                                    ? text.supportTemplateUpdateAction
                                                    : text.supportTemplateCreateAction}
                                            </strong>
                                            <span className={styles.subtle}>{text.supportTemplatesManagerDescription}</span>
                                        </div>

                                        <div className={styles.templateForm}>
                                            <label className={styles.templateSection}>
                                                <span className={styles.subtle}>{text.supportTemplateTitleLabel}</span>
                                                <input
                                                    className={styles.input}
                                                    value={templateDraft.title}
                                                    onChange={(event) =>
                                                        setTemplateDraft((current) => ({
                                                            ...current,
                                                            title: event.target.value,
                                                        }))
                                                    }
                                                />
                                            </label>

                                            <label className={styles.templateSection}>
                                                <span className={styles.subtle}>{text.supportTemplateBodyLabel}</span>
                                                <textarea
                                                    className={styles.textarea}
                                                    value={templateDraft.body}
                                                    onChange={(event) =>
                                                        setTemplateDraft((current) => ({
                                                            ...current,
                                                            body: event.target.value,
                                                        }))
                                                    }
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
                                                        onChange={(event) =>
                                                            setTemplateDraft((current) => ({
                                                                ...current,
                                                                sortOrder: Number(event.target.value) || 0,
                                                            }))
                                                        }
                                                    />
                                                </label>
                                            </div>

                                            <label className={styles.checkboxRow}>
                                                <input
                                                    type="checkbox"
                                                    checked={templateDraft.isEnabled}
                                                    onChange={(event) =>
                                                        setTemplateDraft((current) => ({
                                                            ...current,
                                                            isEnabled: event.target.checked,
                                                        }))
                                                    }
                                                />
                                                <span>{text.supportTemplateEnabledLabel}</span>
                                            </label>

                                            <div className={styles.templateRowActions}>
                                                <Button
                                                    variant="primary"
                                                    onClick={() => templateSaveMutation.mutate()}
                                                    disabled={
                                                        templateSaveMutation.isPending ||
                                                        !templateDraft.title.trim() ||
                                                        !templateDraft.body.trim()
                                                    }
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
                                                <Button
                                                    variant="secondary"
                                                    onClick={() => setIsTemplateEditorOpen(false)}
                                                >
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
                                            meta={
                                                <AdminBadge tone={item.tone}>
                                                    {formatDateTime(item.occurredAtUtc, locale)}
                                                </AdminBadge>
                                            }
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
        </div>
    );
}
