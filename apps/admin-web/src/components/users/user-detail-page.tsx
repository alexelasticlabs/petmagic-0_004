"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { type ReactElement, useEffect, useMemo, useState } from "react";

import {
  DollarIcon,
  MoreHorizontalIcon,
  PawIcon,
  SupportIcon,
} from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminMetricStrip,
  AdminPage,
  AdminStateCard,
  AdminStatusBadge,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import { useAdminUserProfile } from "@/components/users/use-admin-user-profile";
import { UserAccessControlPanel } from "@/components/users/user-access-control-panel";
import { getUserActivityPresentation } from "@/components/users/user-activity-presentation";
import { UserAvatarView } from "@/components/users/user-avatar";
import {
  getUserDetailPetText,
  getUserDetailWorkspaceText,
  type UserDetailPetText,
  type UserDetailWorkspaceText,
} from "@/components/users/user-detail-page.content";
import styles from "@/components/users/user-detail-page.module.css";
import { formatLabeledMetric } from "@/components/users/user-monetization-format";
import { UserSecureMediaImage } from "@/components/users/user-secure-media-image";
import { UserSessionsPanel } from "@/components/users/user-sessions-panel";
import { UserSupportTicketsPanel } from "@/components/users/user-support-tickets-panel";
import { UserWalletPanel } from "@/components/users/user-wallet-panel";
import { getUserRoleLabel, getUserRoleTone } from "@/components/users-management-page.helpers";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import {
  changeAdminUserPetPhotoStatus,
  changeAdminUserPetStatus,
  fetchAdminUserPetGenerations,
  fetchAdminUserPetPhotos,
  fetchAdminUserPets,
  type AdminUserPet,
  type AdminUserPetGeneration,
  type AdminUserPetPhoto,
  useAuthSession,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { formatDateTime } from "@/lib/format-date-time";
import { getDictionary, type Locale } from "@/lib/i18n";
import { getAdminUserDisplayName, maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

type UserDetailPageProps = {
  locale: Locale;
  userId: string;
};

type UserDetailTab = "overview" | "wallet" | "support" | "content" | "access";

type PendingPetStatusChange = {
  nextStatus: "active" | "hidden";
  pet: AdminUserPet;
};

type PendingPetPhotoStatusChange = {
  nextStatus: "active" | "hidden";
  photo: AdminUserPetPhoto;
};

const ACTIVITY_LIMIT = 6;
const RECENT_ITEMS_LIMIT = 8;

function getUserDetailTab(value: string | null): UserDetailTab {
  switch (value) {
    case "wallet":
    case "support":
    case "content":
    case "access":
      return value;
    default:
      return "overview";
  }
}

function getUserDetailHref(
  locale: Locale,
  userId: string,
  tab: UserDetailTab,
  action?: "adjust-balance"
) {
  const basePath = `/${locale}/users/${encodeURIComponent(userId)}`;
  const query = new URLSearchParams();

  if (tab !== "overview") {
    query.set("tab", tab);
  }

  if (action) {
    query.set("action", action);
  }

  const queryString = query.toString();
  return queryString ? `${basePath}?${queryString}` : basePath;
}

function getPurchaseStatusColor(status: string): string {
  return status.toLowerCase() === "succeeded" ? "var(--success)" : "var(--warning)";
}

function getGenerationStatusColor(status: string): string {
  if (status.toLowerCase() === "completed") {
    return "var(--success)";
  }

  if (status.toLowerCase() === "failed") {
    return "var(--danger)";
  }

  return "var(--text-muted)";
}

function formatPurchaseStatus(status: string, text: UserDetailWorkspaceText) {
  return status.toLowerCase() === "succeeded" ? text.purchaseCompleted : text.purchaseIncomplete;
}

function formatGenerationStatus(status: string, text: UserDetailWorkspaceText) {
  switch (status.toLowerCase()) {
    case "completed":
      return text.generationCompleted;
    case "failed":
      return text.generationFailed;
    default:
      return text.generationInProgress;
  }
}

function formatPetStatus(status: string, text: UserDetailPetText) {
  if (status === "active") {
    return text.activeStatus;
  }

  if (status === "hidden") {
    return text.hiddenStatus;
  }

  return text.needsReview;
}

function getUserPetActionErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export function UserDetailPage({ locale, userId }: UserDetailPageProps) {
  const text = getDictionary(locale);
  const petText = useMemo(() => getUserDetailPetText(locale), [locale]);
  const workspaceText = useMemo(() => getUserDetailWorkspaceText(locale), [locale]);
  const router = useRouter();
  const searchParams = useSearchParams();
  const session = useAuthSession();
  const queryClient = useQueryClient();
  const requestedTab = getUserDetailTab(searchParams.get("tab"));
  const activeTab = requestedTab;
  const shouldFocusWalletAdjustment = searchParams.get("action") === "adjust-balance";
  const [expandedPetIds, setExpandedPetIds] = useState<ReadonlySet<string>>(() => new Set());
  const [pendingPetStatusChange, setPendingPetStatusChange] =
    useState<PendingPetStatusChange | null>(null);
  const [petActionFeedback, setPetActionFeedback] = useState<{
    message: string;
    tone: "success" | "warning";
  } | null>(null);
  const canViewUserProfile = session?.user.roles.includes("Admin") ?? false;
  const { analytics, hasError, isFetching, isLoading, refresh, user } = useAdminUserProfile({
    enabled: canViewUserProfile,
    userId,
  });
  const petsQuery = useQuery<AdminUserPet[]>({
    enabled: canViewUserProfile && activeTab === "content" && Boolean(userId),
    queryKey: ["admin", "users", userId, "pets"],
    queryFn: ({ signal }) => fetchAdminUserPets(userId, signal),
  });
  const petStatusMutation = useMutation({
    mutationFn: ({ petId, status }: { petId: string; status: "active" | "hidden" }) =>
      changeAdminUserPetStatus(userId, petId, status),
    onMutate: () => {
      setPetActionFeedback(null);
    },
    onSuccess: async () => {
      setPendingPetStatusChange(null);
      setPetActionFeedback({ tone: "success", message: petText.petStatusUpdated });
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: ["admin", "users", userId, "pets"] }),
      ]);
    },
    onError: (error, variables) => {
      clientLogger.warn("users.pet_status_update_failed", {
        userId: sanitizeSensitiveText(userId, 80),
        petId: sanitizeSensitiveText(variables.petId, 80),
        status: variables.status,
        ...getUserPetActionErrorDetails(error),
      });
      setPendingPetStatusChange(null);
      setPetActionFeedback({
        tone: "warning",
        message: getAdminErrorMessage(error, petText.statusUpdateError),
      });
    },
  });
  const isPetActionLocked = petStatusMutation.isPending || petsQuery.isFetching;
  const visiblePetIds = useMemo(
    () => new Set((petsQuery.data ?? []).map((pet) => pet.id)),
    [petsQuery.data]
  );

  useEffect(() => {
    let isActive = true;
    if (!petsQuery.data || expandedPetIds.size === 0) {
      return;
    }

    const hasStaleExpandedPet = Array.from(expandedPetIds).some(
      (petId) => !visiblePetIds.has(petId)
    );
    if (!hasStaleExpandedPet) {
      return;
    }

    queueMicrotask(() => {
      if (!isActive) {
        return;
      }

      setExpandedPetIds((current) => {
        const next = new Set([...current].filter((petId) => visiblePetIds.has(petId)));
        return next.size === current.size ? current : next;
      });
    });

    return () => {
      isActive = false;
    };
  }, [expandedPetIds, petsQuery.data, visiblePetIds]);

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  function requestPetStatusChange(pet: AdminUserPet) {
    if (!canViewUserProfile || isPetActionLocked) {
      return;
    }

    const nextStatus = pet.status === "active" ? "hidden" : "active";
    if (nextStatus === "hidden") {
      setPendingPetStatusChange({ pet, nextStatus });
      return;
    }

    petStatusMutation.mutate({ petId: pet.id, status: nextStatus });
  }

  function confirmPetStatusChange() {
    if (!pendingPetStatusChange || isPetActionLocked) {
      return;
    }

    petStatusMutation.mutate({
      petId: pendingPetStatusChange.pet.id,
      status: pendingPetStatusChange.nextStatus,
    });
  }

  function requestPetsRetry() {
    if (!canViewUserProfile || petsQuery.isFetching) {
      return;
    }

    void petsQuery.refetch().catch(() => undefined);
  }

  function requestUserProfileRetry() {
    if (!canViewUserProfile || isFetching) {
      return;
    }

    void refresh().catch(() => undefined);
  }

  function selectTab(nextTab: UserDetailTab, action?: "adjust-balance") {
    router.replace(getUserDetailHref(locale, userId, nextTab, action), {
      scroll: false,
    });
  }

  function dismissWalletAdjustmentIntent() {
    router.replace(getUserDetailHref(locale, userId, "wallet"), {
      scroll: false,
    });
  }

  if (!canViewUserProfile || isLoading) {
    return (
      <AdminPage className={styles.page}>
        <Link href={`/${locale}/users`} className={styles.backLink}>
          {workspaceText.backToUsers}
        </Link>
        <section className={styles.compactState} aria-busy="true">
          <AdminStateCard tone="info" title={text.loading} />
        </section>
      </AdminPage>
    );
  }

  if (hasError || !user || !analytics) {
    return (
      <AdminPage className={styles.page}>
        <Link href={`/${locale}/users`} className={styles.backLink}>
          {workspaceText.backToUsers}
        </Link>
        <section className={styles.compactState}>
          <AdminStateCard
            tone="danger"
            title={text.userAnalyticsLoadError}
            action={
              <div className={styles.errorActions}>
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={requestUserProfileRetry}
                  disabled={!canViewUserProfile || isFetching}
                >
                  {text.supportRetryAction}
                </Button>
              </div>
            }
          />
        </section>
      </AdminPage>
    );
  }

  const safeUserName = sanitizeSensitiveText(getAdminUserDisplayName(user), 96);
  const tabs: Array<{ id: UserDetailTab; label: string }> = [
    { id: "overview", label: workspaceText.tabOverview },
    { id: "wallet", label: workspaceText.tabWallet },
    { id: "support", label: workspaceText.tabSupport },
    { id: "content", label: workspaceText.tabContent },
    { id: "access", label: workspaceText.tabAccess },
  ];
  const tabOptions: readonly SelectOption[] = tabs.map((tab) => ({
    value: tab.id,
    label: tab.label,
  }));

  return (
    <AdminPage className={styles.page}>
      <Link href={`/${locale}/users`} className={styles.backLink}>
        {workspaceText.backToUsers}
      </Link>
      <section className={styles.profileMasthead} aria-labelledby="user-profile-title">
        <div className={styles.profilePrimary}>
          <UserAvatarView
            avatar={user.avatar}
            label={`${text.avatarLabel}: ${safeUserName}`}
            fallbackLabel={safeUserName}
            size="lg"
          />
          <div className={styles.profileCopy}>
            <div className={styles.profileIdentity}>
              <h2 id="user-profile-title">{safeUserName}</h2>
              <p>{maskEmail(user.email)}</p>
            </div>
            <div className={styles.profileBadges}>
              <AdminBadge tone={user.isActive ? "success" : "danger"}>
                {user.isActive ? text.activeLabel : text.blockedLabel}
              </AdminBadge>
              <AdminBadge tone={user.isPremium ? "warning" : "neutral"}>
                {user.isPremium ? text.premiumLabel : text.freeLabel}
              </AdminBadge>
              {user.roles.map((role) => (
                <AdminBadge key={role} tone={getUserRoleTone(role)}>
                  {getUserRoleLabel(role, text)}
                </AdminBadge>
              ))}
            </div>
            <div className={styles.profileMeta}>
              <Metric label={workspaceText.profileId} value={user.userId} />
              <Metric
                label={workspaceText.profileCreatedAt}
                value={formatDateTime(user.createdAtUtc, locale)}
              />
              <Metric
                label={workspaceText.profileLastActivity}
                value={formatDateTime(analytics.summary.lastActivityAtUtc, locale)}
              />
            </div>
          </div>
        </div>
        <div
          className={styles.quickActions}
          role="group"
          aria-label={workspaceText.quickActionsTitle}
        >
          <Button variant="primary" size="sm" onClick={() => selectTab("wallet", "adjust-balance")}>
            <PawIcon className={styles.quickActionIcon} />
            {workspaceText.quickCredit}
          </Button>
          <Button variant="secondary" size="sm" onClick={() => selectTab("access")}>
            {workspaceText.quickPremium}
          </Button>
          <Button variant="secondary" size="sm" onClick={() => selectTab("support")}>
            <SupportIcon className={styles.quickActionIcon} />
            {workspaceText.quickMessage}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => selectTab("access")}
            aria-label={workspaceText.moreActions}
          >
            <MoreHorizontalIcon className={styles.quickActionIcon} />
          </Button>
        </div>
      </section>

      <div className={styles.profileKpis} aria-label={workspaceText.overviewSummaryTitle}>
        <button type="button" onClick={() => selectTab("wallet")}>
          {analytics.summary.walletBalance}
          <span>PawSpark</span>
        </button>
        <button type="button" onClick={() => selectTab("content")}>
          {analytics.summary.totalGenerations}
          <span>{workspaceText.overviewGenerations}</span>
        </button>
        <button type="button" onClick={() => selectTab("content")}>
          —<span>{workspaceText.petsMetric}</span>
        </button>
        <button type="button" onClick={() => selectTab("wallet")}>
          {analytics.summary.totalPurchases}
          <span>{workspaceText.overviewPurchases}</span>
        </button>
        <button type="button" onClick={() => selectTab("access")}>
          —<span>{workspaceText.activeSessionsMetric}</span>
        </button>
      </div>

      <nav className={styles.tabs} aria-label={workspaceText.tabsLabel}>
        {tabs.map((tab) => (
          <Link
            key={tab.id}
            href={getUserDetailHref(locale, userId, tab.id)}
            className={styles.tabButton}
            data-active={activeTab === tab.id ? "true" : "false"}
            aria-current={activeTab === tab.id ? "page" : undefined}
          >
            {tab.label}
          </Link>
        ))}
      </nav>

      <div className={styles.tabSelect}>
        <span>{workspaceText.tabsLabel}</span>
        <Select
          value={activeTab}
          options={tabOptions}
          onChange={(value) => selectTab(value as UserDetailTab)}
          ariaLabel={workspaceText.tabsLabel}
          showSelectedDescription={false}
        />
      </div>

      {activeTab === "overview" ? (
        <section className={styles.overviewWorkspace} aria-labelledby="user-overview-title">
          <header className={styles.workspaceHeader}>
            <div>
              <h2 id="user-overview-title">{workspaceText.overviewTitle}</h2>
              <p>{workspaceText.overviewDescription}</p>
            </div>
          </header>
          <div className={styles.overviewLayout}>
            <section className={styles.activitySurface} aria-labelledby="user-activity-title">
              <h3 id="user-activity-title" className={styles.timelineTitle}>
                {workspaceText.overviewActivityTitle}
              </h3>
              {analytics.recentActivity.length ? (
                <div className={styles.timeline}>
                  {analytics.recentActivity.slice(0, ACTIVITY_LIMIT).map((item) => {
                    const activity = getUserActivityPresentation(item, workspaceText);

                    return (
                      <article
                        key={`${item.kind}:${item.occurredAtUtc}:${item.title}`}
                        className={styles.timelineItem}
                      >
                        <div className={styles.timelineHeader}>
                          <strong>{activity.title}</strong>
                          <span>{formatDateTime(item.occurredAtUtc, locale)}</span>
                        </div>
                        {activity.details ? <p>{activity.details}</p> : null}
                      </article>
                    );
                  })}
                </div>
              ) : (
                <AdminStateCard
                  className={styles.activityEmptyState}
                  tone="info"
                  title={workspaceText.overviewNoActivity}
                />
              )}
            </section>
            <aside className={styles.overviewSummary} aria-labelledby="user-overview-summary-title">
              <h3 id="user-overview-summary-title">{workspaceText.overviewSummaryTitle}</h3>
              <AdminMetricStrip
                className={styles.overviewMetrics}
                items={[
                  { label: workspaceText.overviewBalance, value: analytics.summary.walletBalance },
                  {
                    label: workspaceText.overviewPurchases,
                    value: analytics.summary.successfulPurchases,
                  },
                  {
                    label: workspaceText.overviewGenerations,
                    value: analytics.summary.completedGenerations,
                  },
                ]}
              />
              <dl className={styles.overviewContextList}>
                <div>
                  <dt>{workspaceText.overviewAccountState}</dt>
                  <dd>
                    <AdminBadge tone={user.isActive ? "success" : "danger"}>
                      {user.isActive
                        ? workspaceText.overviewAccountActive
                        : workspaceText.overviewAccountBlocked}
                    </AdminBadge>
                  </dd>
                </div>
                <div>
                  <dt>{workspaceText.overviewPlan}</dt>
                  <dd>{user.isPremium ? text.premiumLabel : text.freeLabel}</dd>
                </div>
                <div>
                  <dt>{workspaceText.overviewRole}</dt>
                  <dd>
                    {user.roles.length
                      ? user.roles.map((role) => getUserRoleLabel(role, text)).join(", ")
                      : "—"}
                  </dd>
                </div>
                <div>
                  <dt>{workspaceText.contentPurchases}</dt>
                  <dd>
                    {analytics.recentPurchases.length
                      ? `${analytics.recentPurchases[0].priceAmount} ${analytics.recentPurchases[0].currencyCode}`
                      : "—"}
                  </dd>
                </div>
                <div>
                  <dt>{workspaceText.contentGenerations}</dt>
                  <dd>
                    {analytics.recentGenerations.length
                      ? sanitizeSensitiveText(analytics.recentGenerations[0].templateTitle, 48)
                      : "—"}
                  </dd>
                </div>
              </dl>
            </aside>
          </div>
        </section>
      ) : null}

      {activeTab === "wallet" ? (
        <section className={styles.tabPanel}>
          <UserWalletPanel
            key={shouldFocusWalletAdjustment ? "wallet-adjustment" : "wallet"}
            actorId={session?.user.userId ?? ""}
            locale={locale}
            userId={user.userId}
            analytics={analytics}
            canAdjustWallet={canViewUserProfile}
            autoFocusAdjustment={shouldFocusWalletAdjustment}
            onAdjustmentIntentDismissed={dismissWalletAdjustmentIntent}
            onUpdated={async () => {
              await refresh();
            }}
          />
          <AdminCard title={workspaceText.contentPurchases}>
            <DataList
              emptyTitle={workspaceText.noPurchases}
              items={analytics.recentPurchases.slice(0, RECENT_ITEMS_LIMIT).map((purchase) => (
                <article key={purchase.orderId} className={styles.dataCard}>
                  <div className={styles.dataHeader}>
                    <strong>
                      {formatLabeledMetric(text.purchasedSparkLabel, purchase.sparkToGrant)}
                    </strong>
                    <AdminStatusBadge color={getPurchaseStatusColor(purchase.status)}>
                      {formatPurchaseStatus(purchase.status, workspaceText)}
                    </AdminStatusBadge>
                  </div>
                  <p>
                    {purchase.priceAmount} {sanitizeSensitiveText(purchase.currencyCode, 12)} •{" "}
                    {sanitizeSensitiveText(purchase.paymentProvider, 48)}
                  </p>
                  <span>
                    {formatDateTime(purchase.confirmedAtUtc ?? purchase.createdAtUtc, locale)}
                  </span>
                </article>
              ))}
            />
          </AdminCard>
        </section>
      ) : null}

      {activeTab === "support" ? (
        <section className={styles.tabPanel}>
          <UserSupportTicketsPanel
            locale={locale}
            retryLabel={text.supportRetryAction}
            text={workspaceText}
            userId={user.userId}
          />
        </section>
      ) : null}

      {activeTab === "content" ? (
        <section className={styles.tabPanel}>
          <AdminCard
            className={styles.contentWorkspace}
            title={workspaceText.tabContent}
            description={petText.description}
          >
            <div className={styles.contentSplit}>
              <section className={styles.contentSection} aria-labelledby="user-pets-section-title">
                <h3 id="user-pets-section-title">{petText.title}</h3>
                {petActionFeedback ? (
                  <AdminStateCard tone={petActionFeedback.tone} title={petActionFeedback.message} />
                ) : null}
                {petsQuery.isError ? (
                  <AdminStateCard
                    tone="danger"
                    title={getAdminErrorMessage(petsQuery.error, petText.loadError)}
                    action={
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={requestPetsRetry}
                        disabled={!canViewUserProfile || petsQuery.isFetching}
                      >
                        {text.supportRetryAction}
                      </Button>
                    }
                  />
                ) : (
                  <DataList
                    emptyTitle={petsQuery.isLoading ? text.loading : petText.noPets}
                    items={(petsQuery.data ?? []).map((pet) => {
                      const isExpanded = expandedPetIds.has(pet.id);
                      const petDetailsId = `user-pet-details-${pet.id}`;

                      return (
                        <article key={pet.id} className={styles.dataCard}>
                          <div className={styles.dataHeader}>
                            <strong>{sanitizeSensitiveText(pet.name, 80)}</strong>
                            <AdminStatusBadge
                              color={pet.status === "active" ? "var(--success)" : "var(--warning)"}
                            >
                              {formatPetStatus(pet.status, petText)}
                            </AdminStatusBadge>
                          </div>
                          <p>
                            {sanitizeSensitiveText(pet.type, 24)}
                            {pet.breed ? ` • ${sanitizeSensitiveText(pet.breed, 60)}` : ""} •{" "}
                            {pet.photosCount} {petText.photosCount} • {pet.generationsCount}{" "}
                            {petText.generationsCount}
                          </p>
                          <span>{formatDateTime(pet.updatedAtUtc, locale)}</span>
                          <div className={styles.errorActions}>
                            <Button
                              variant="secondary"
                              size="sm"
                              aria-label={`${
                                pet.status === "active"
                                  ? petText.hidePetLabel
                                  : petText.restorePetLabel
                              }: ${sanitizeSensitiveText(pet.name, 80)}`}
                              disabled={!canViewUserProfile || isPetActionLocked}
                              onClick={() => requestPetStatusChange(pet)}
                            >
                              {pet.status === "active" ? petText.hide : petText.restore}
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              aria-expanded={isExpanded}
                              aria-controls={petDetailsId}
                              onClick={() =>
                                setExpandedPetIds((current) => {
                                  const next = new Set(current);
                                  if (next.has(pet.id)) {
                                    next.delete(pet.id);
                                  } else {
                                    next.add(pet.id);
                                  }
                                  return next;
                                })
                              }
                            >
                              {isExpanded ? petText.hideDetails : petText.showDetails}
                            </Button>
                          </div>
                          {isExpanded ? (
                            <AdminPetDetails
                              detailsId={petDetailsId}
                              locale={locale}
                              userId={userId}
                              pet={pet}
                              text={petText}
                              workspaceText={workspaceText}
                              canManagePets={canViewUserProfile}
                              retryLabel={text.supportRetryAction}
                            />
                          ) : null}
                        </article>
                      );
                    })}
                  />
                )}
              </section>

              <section
                className={styles.contentSection}
                aria-labelledby="user-generations-section-title"
              >
                <h3 id="user-generations-section-title">{workspaceText.contentGenerations}</h3>
                <DataList
                  emptyTitle={workspaceText.noGenerations}
                  items={analytics.recentGenerations
                    .slice(0, RECENT_ITEMS_LIMIT)
                    .map((generation) => (
                      <article key={generation.generationId} className={styles.dataCard}>
                        <div className={styles.dataHeader}>
                          <strong>{sanitizeSensitiveText(generation.templateTitle, 120)}</strong>
                          <AdminStatusBadge color={getGenerationStatusColor(generation.status)}>
                            {formatGenerationStatus(generation.status, workspaceText)}
                          </AdminStatusBadge>
                        </div>
                        <p>
                          {sanitizeSensitiveText(generation.templateType, 48)} •{" "}
                          {formatLabeledMetric(text.tokenCostLabel, generation.tokenCost)}
                        </p>
                        <span>
                          {formatDateTime(
                            generation.completedAtUtc ?? generation.createdAtUtc,
                            locale
                          )}
                        </span>
                      </article>
                    ))}
                />
              </section>
            </div>
          </AdminCard>
        </section>
      ) : null}

      {activeTab === "access" ? (
        <section className={styles.tabPanel}>
          <UserSessionsPanel locale={locale} userId={user.userId} />
          <UserAccessControlPanel
            locale={locale}
            text={text}
            user={user}
            workspaceText={workspaceText}
            onUpdated={async () => {
              await refresh();
            }}
            onDeleted={() => router.replace(`/${locale}/users`)}
          />
        </section>
      ) : null}

      <ConfirmationDialog
        open={pendingPetStatusChange !== null}
        title={petText.hideConfirmTitle}
        description={
          pendingPetStatusChange
            ? petText.hidePetConfirmDescription.replace(
                "{name}",
                sanitizeSensitiveText(pendingPetStatusChange.pet.name, 80)
              )
            : ""
        }
        confirmLabel={petText.hide}
        cancelLabel={workspaceText.confirmCancel}
        isSubmitting={petStatusMutation.isPending}
        onCancel={() => {
          if (!petStatusMutation.isPending) {
            setPendingPetStatusChange(null);
          }
        }}
        onConfirm={confirmPetStatusChange}
      />
    </AdminPage>
  );
}

function DataList({ items, emptyTitle }: { items: ReactElement[]; emptyTitle: string }) {
  if (!items.length) {
    return (
      <p className={styles.inlineEmptyState} role="status">
        {emptyTitle}
      </p>
    );
  }

  return <div className={styles.dataList}>{items}</div>;
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.metric}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function AdminPetDetails({
  canManagePets,
  detailsId,
  locale,
  pet,
  retryLabel,
  text,
  userId,
  workspaceText,
}: {
  canManagePets: boolean;
  detailsId: string;
  locale: Locale;
  pet: AdminUserPet;
  retryLabel: string;
  text: UserDetailPetText;
  userId: string;
  workspaceText: UserDetailWorkspaceText;
}) {
  const queryClient = useQueryClient();
  const [pendingPhotoStatusChange, setPendingPhotoStatusChange] =
    useState<PendingPetPhotoStatusChange | null>(null);
  const [photoActionFeedback, setPhotoActionFeedback] = useState<{
    message: string;
    tone: "success" | "warning";
  } | null>(null);
  const photosQuery = useQuery<AdminUserPetPhoto[]>({
    enabled: canManagePets,
    queryKey: ["admin", "users", userId, "pets", pet.id, "photos"],
    queryFn: ({ signal }) => fetchAdminUserPetPhotos(userId, pet.id, signal),
  });
  const generationsQuery = useQuery<AdminUserPetGeneration[]>({
    enabled: canManagePets,
    queryKey: ["admin", "users", userId, "pets", pet.id, "generations"],
    queryFn: ({ signal }) => fetchAdminUserPetGenerations(userId, pet.id, signal),
  });
  const photoStatusMutation = useMutation({
    mutationFn: ({ photoId, status }: { photoId: string; status: "active" | "hidden" }) =>
      changeAdminUserPetPhotoStatus(userId, pet.id, photoId, status),
    onMutate: () => {
      setPhotoActionFeedback(null);
    },
    onSuccess: async () => {
      setPendingPhotoStatusChange(null);
      setPhotoActionFeedback({ message: text.photoStatusUpdated, tone: "success" });
      await Promise.allSettled([
        queryClient.invalidateQueries({
          queryKey: ["admin", "users", userId, "pets", pet.id, "photos"],
        }),
      ]);
    },
    onError: (error, variables) => {
      clientLogger.warn("users.pet_photo_status_update_failed", {
        userId: sanitizeSensitiveText(userId, 80),
        petId: sanitizeSensitiveText(pet.id, 80),
        photoId: sanitizeSensitiveText(variables.photoId, 80),
        status: variables.status,
        ...getUserPetActionErrorDetails(error),
      });
      setPendingPhotoStatusChange(null);
      setPhotoActionFeedback({
        message: getAdminErrorMessage(error, text.photoStatusUpdateError),
        tone: "warning",
      });
    },
  });
  const isPhotoActionLocked = photoStatusMutation.isPending || photosQuery.isFetching;

  function requestPhotoStatusChange(photo: AdminUserPetPhoto) {
    if (!canManagePets || isPhotoActionLocked) {
      return;
    }

    const nextStatus = photo.status === "active" ? "hidden" : "active";
    if (nextStatus === "hidden") {
      setPendingPhotoStatusChange({ nextStatus, photo });
      return;
    }

    photoStatusMutation.mutate({
      photoId: photo.id,
      status: nextStatus,
    });
  }

  function confirmPhotoStatusChange() {
    if (!pendingPhotoStatusChange || isPhotoActionLocked) {
      return;
    }

    photoStatusMutation.mutate({
      photoId: pendingPhotoStatusChange.photo.id,
      status: pendingPhotoStatusChange.nextStatus,
    });
  }

  function requestPhotosRetry() {
    if (!canManagePets || photosQuery.isFetching) {
      return;
    }

    void photosQuery.refetch().catch(() => undefined);
  }

  function requestGenerationsRetry() {
    if (!canManagePets || generationsQuery.isFetching) {
      return;
    }

    void generationsQuery.refetch().catch(() => undefined);
  }

  const photos = photosQuery.data ?? [];
  const generations = generationsQuery.data ?? [];

  return (
    <div
      id={detailsId}
      className={styles.petDetails}
      aria-busy={
        photosQuery.isFetching || generationsQuery.isFetching || photoStatusMutation.isPending
          ? "true"
          : undefined
      }
    >
      {photoActionFeedback ? (
        <AdminStateCard tone={photoActionFeedback.tone} title={photoActionFeedback.message} />
      ) : null}
      {photosQuery.isLoading ? (
        <span className={styles.petDetailState}>{text.loadingPhotos}</span>
      ) : photosQuery.isError ? (
        <AdminStateCard
          tone="danger"
          title={getAdminErrorMessage(photosQuery.error, text.photosLoadError)}
          action={
            <Button
              variant="secondary"
              size="sm"
              onClick={requestPhotosRetry}
              disabled={!canManagePets || photosQuery.isFetching}
            >
              {retryLabel}
            </Button>
          }
        />
      ) : photos.length ? (
        <div className={styles.petMediaGrid}>
          {photos.slice(0, 6).map((photo) => (
            <div key={photo.id} className={styles.petPhoto}>
              <UserSecureMediaImage
                src={photo.thumbnailUrl ?? photo.url}
                alt={`${sanitizeSensitiveText(pet.name, 40)} ${text.photoAlt}`}
                className={styles.petPhotoImage}
                logEvent="users.pet_photo_fetch_failed"
                fallback={<span className={styles.petPhotoPreviewFallback}>{text.noPhotos}</span>}
              />
              <span>
                {photo.isAvatar ? `${text.avatar} • ` : ""}
                {photo.isFavorite ? `${text.favorite} • ` : ""}
                {formatPetStatus(photo.status, text)}
              </span>
              <Button
                variant="secondary"
                size="sm"
                aria-label={`${
                  photo.status === "active" ? text.hidePhotoLabel : text.restorePhotoLabel
                }: ${sanitizeSensitiveText(pet.name, 80)} ${text.photoAlt}`}
                disabled={!canManagePets || isPhotoActionLocked}
                onClick={() => requestPhotoStatusChange(photo)}
              >
                {photo.status === "active" ? text.hidePhoto : text.restorePhoto}
              </Button>
            </div>
          ))}
        </div>
      ) : (
        <span className={styles.petDetailState}>{text.noPhotos}</span>
      )}

      {generationsQuery.isLoading ? (
        <span className={styles.petDetailState}>{text.loadingGenerations}</span>
      ) : generationsQuery.isError ? (
        <AdminStateCard
          tone="danger"
          title={getAdminErrorMessage(generationsQuery.error, text.generationsLoadError)}
          action={
            <Button
              variant="secondary"
              size="sm"
              onClick={requestGenerationsRetry}
              disabled={!canManagePets || generationsQuery.isFetching}
            >
              {retryLabel}
            </Button>
          }
        />
      ) : generations.length ? (
        <DataList
          emptyTitle={text.noGenerations}
          items={generations.slice(0, 6).map((generation) => (
            <article key={generation.generationId} className={styles.dataCard}>
              <div className={styles.dataHeader}>
                <strong>
                  {sanitizeSensitiveText(generation.templateTitle ?? generation.templateId, 120)}
                </strong>
                <AdminStatusBadge color={getGenerationStatusColor(generation.status)}>
                  {formatGenerationStatus(generation.status, workspaceText)}
                </AdminStatusBadge>
              </div>
              <p>
                {sanitizeSensitiveText(generation.templateType ?? text.fallbackTemplate, 48)} •{" "}
                {formatLabeledMetric(text.tokenCostLabel, generation.tokenCost)}
              </p>
              <span>
                {formatDateTime(generation.completedAtUtc ?? generation.createdAtUtc, locale)}
              </span>
            </article>
          ))}
        />
      ) : (
        <span className={styles.petDetailState}>{text.noGenerations}</span>
      )}

      <ConfirmationDialog
        open={pendingPhotoStatusChange !== null}
        title={text.hideConfirmTitle}
        description={
          pendingPhotoStatusChange
            ? text.hidePhotoConfirmDescription.replace(
                "{name}",
                sanitizeSensitiveText(pet.name, 80)
              )
            : ""
        }
        confirmLabel={text.hidePhoto}
        cancelLabel={workspaceText.confirmCancel}
        isSubmitting={photoStatusMutation.isPending}
        onCancel={() => {
          if (!photoStatusMutation.isPending) {
            setPendingPhotoStatusChange(null);
          }
        }}
        onConfirm={confirmPhotoStatusChange}
      />
    </div>
  );
}
