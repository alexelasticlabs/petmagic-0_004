"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { type ReactElement, useEffect, useMemo, useState } from "react";

import {
  AdminBadge,
  AdminCard,
  AdminKpiCard,
  AdminMetricStrip,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminStateCard,
  AdminStatusBadge,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { Button } from "@/components/ui/button";
import { useAdminUserProfile } from "@/components/users/use-admin-user-profile";
import { UserAvatarView } from "@/components/users/user-avatar";
import { getUserDetailPetText, type UserDetailPetText } from "@/components/users/user-detail-page.content";
import styles from "@/components/users/user-detail-page.module.css";
import { UserWalletPanel } from "@/components/users/user-wallet-panel";
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

const ACTIVITY_LIMIT = 12;
const RECENT_ITEMS_LIMIT = 8;
const AUDIT_ITEMS_LIMIT = 12;

function formatBytes(value: number): string {
  if (!Number.isFinite(value) || value < 0) {
    return "0 B";
  }

  if (value < 1024) {
    return `${value} B`;
  }

  const kib = value / 1024;
  if (kib < 1024) {
    return `${kib.toFixed(1)} KB`;
  }

  return `${(kib / 1024).toFixed(1)} MB`;
}

function getPurchaseStatusColor(status: string): string {
  return status === "succeeded" ? "var(--success)" : "var(--warning)";
}

function getGenerationStatusColor(status: string): string {
  if (status === "Completed") {
    return "var(--success)";
  }

  if (status === "Failed") {
    return "var(--danger)";
  }

  return "var(--text-muted)";
}

function formatPetStatus(status: string, text: UserDetailPetText) {
  if (status === "active") {
    return text.activeStatus;
  }

  if (status === "hidden") {
    return text.hiddenStatus;
  }

  return sanitizeSensitiveText(status, 32);
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
  const router = useRouter();
  const session = useAuthSession();
  const queryClient = useQueryClient();
  const [expandedPetIds, setExpandedPetIds] = useState<ReadonlySet<string>>(() => new Set());
  const [petActionError, setPetActionError] = useState<string | null>(null);
  const canViewUserProfile = session?.user.roles.includes("Admin") ?? false;
  const { analytics, hasError, isFetching, isLoading, refresh, user } = useAdminUserProfile({
    enabled: canViewUserProfile,
    userId,
  });
  const petsQuery = useQuery<AdminUserPet[]>({
    enabled: canViewUserProfile && Boolean(userId),
    queryKey: ["admin", "users", userId, "pets"],
    queryFn: ({ signal }) => fetchAdminUserPets(userId, signal),
  });
  const petStatusMutation = useMutation({
    mutationFn: ({ petId, status }: { petId: string; status: "active" | "hidden" }) =>
      changeAdminUserPetStatus(userId, petId, status),
    onMutate: () => {
      setPetActionError(null);
    },
    onSuccess: async () => {
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
      setPetActionError(getAdminErrorMessage(error, petText.statusUpdateError));
    },
  });
  const isPetActionLocked = petStatusMutation.isPending || petsQuery.isFetching;
  const visiblePetIds = useMemo(
    () => new Set((petsQuery.data ?? []).map((pet) => pet.id)),
    [petsQuery.data]
  );

  useEffect(() => {
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
      setExpandedPetIds((current) => {
        const next = new Set([...current].filter((petId) => visiblePetIds.has(petId)));
        return next.size === current.size ? current : next;
      });
    });
  }, [expandedPetIds, petsQuery.data, visiblePetIds]);

  function requestPetStatusChange(pet: AdminUserPet) {
    if (!canViewUserProfile || isPetActionLocked) {
      return;
    }

    petStatusMutation.mutate({
      petId: pet.id,
      status: pet.status === "active" ? "hidden" : "active",
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

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  const metaItems = useMemo(() => {
    if (!user || !analytics) {
      return [];
    }

    return [
      `${text.createdAtLabel}: ${formatDateTime(user.createdAtUtc, locale)}`,
      `${text.lastActivityLabel}: ${formatDateTime(analytics.summary.lastActivityAtUtc, locale)}`,
      `${text.tokenBalanceLabel}: ${analytics.summary.walletBalance}`,
      `${text.loginsLabel}: ${analytics.summary.successfulLogins}`,
      `${text.viewsLabel}: ${analytics.summary.totalViews}`,
    ];
  }, [
    analytics,
    locale,
    text.createdAtLabel,
    text.lastActivityLabel,
    text.loginsLabel,
    text.tokenBalanceLabel,
    text.viewsLabel,
    user,
  ]);

  if (!canViewUserProfile || isLoading) {
    return (
      <AdminPage className={styles.page}>
        <AdminPageHero
          eyebrow={text.userDetailsEyebrow}
          title={text.userDetailsTitle}
          description={text.userDetailsDescription}
        />
        <AdminStateCard tone="info" title={text.loading} description={text.userAnalyticsTitle} />
      </AdminPage>
    );
  }

  if (hasError || !user || !analytics) {
    return (
      <AdminPage className={styles.page}>
        <AdminPageHero
          eyebrow={text.userDetailsEyebrow}
          title={text.userDetailsTitle}
          description={text.userDetailsDescription}
        />
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
              <Link href={`/${locale}/users`} className={styles.backLink}>
                {text.navUsers}
              </Link>
            </div>
          }
        />
      </AdminPage>
    );
  }

  const safeUserName = sanitizeSensitiveText(getAdminUserDisplayName(user), 96);

  return (
    <AdminPage className={styles.page}>
      <AdminPageHero
        eyebrow={text.userDetailsEyebrow}
        title={safeUserName}
        description={text.userDetailsDescription}
        actions={
          <Link href={`/${locale}/users`} className={styles.backLink}>
            {text.navUsers}
          </Link>
        }
        metaItems={metaItems}
      />

      <AdminCard title={text.userDetailsTitle} description={text.userAnalyticsTitle}>
        <div className={styles.profileHeader}>
          <UserAvatarView
            avatar={user.avatar}
            label={`${text.avatarLabel}: ${safeUserName}`}
            fallbackLabel={safeUserName}
            size="lg"
          />
          <div className={styles.profileCopy}>
            <h2 className={styles.profileTitle}>{safeUserName}</h2>
            <p className={styles.profileEmail}>{maskEmail(user.email)}</p>
            <div className={styles.profileBadges}>
              <AdminBadge tone={user.isActive ? "success" : "danger"}>
                {user.isActive ? text.activeLabel : text.blockedLabel}
              </AdminBadge>
              <AdminBadge tone={user.isPremium ? "warning" : "neutral"}>
                {user.isPremium ? text.premiumLabel : text.freeLabel}
              </AdminBadge>
              <AdminBadge tone={user.emailConfirmed ? "info" : "neutral"}>
                {user.emailConfirmed ? text.emailConfirmedLabel : text.noLabel}
              </AdminBadge>
              {user.roles.map((role) => (
                <AdminBadge key={role}>{sanitizeSensitiveText(role, 32)}</AdminBadge>
              ))}
            </div>
          </div>
          <div className={styles.profileMeta}>
            <Metric label={text.createdAtLabel} value={formatDateTime(user.createdAtUtc, locale)} />
            <Metric
              label={text.lastPurchaseLabel}
              value={formatDateTime(analytics.summary.lastPurchaseAtUtc, locale)}
            />
            <Metric
              label={text.lastGenerationLabel}
              value={formatDateTime(analytics.summary.lastGenerationAtUtc, locale)}
            />
          </div>
        </div>
      </AdminCard>

      <AdminPageGrid columns="four">
        <AdminKpiCard
          label={text.tokenBalanceLabel}
          value={String(analytics.summary.walletBalance)}
          hint={`${text.tokensGrantedLabel}: ${analytics.summary.totalTokensCredited}`}
          tone="primary"
        />
        <AdminKpiCard
          label={text.loginsLabel}
          value={String(analytics.summary.successfulLogins)}
          hint={`${text.failedLoginsLabel}: ${analytics.summary.failedLogins}`}
          tone="magenta"
        />
        <AdminKpiCard
          label={text.viewsLabel}
          value={String(analytics.summary.totalViews)}
          hint={`${text.videoViewsLabel}: ${analytics.summary.totalVideoViews}`}
          tone="info"
        />
        <AdminKpiCard
          label={text.totalPurchasesLabel}
          value={String(analytics.summary.totalPurchases)}
          hint={`${text.successfulPurchasesLabel}: ${analytics.summary.successfulPurchases}`}
          tone="info"
        />
        <AdminKpiCard
          label={text.totalGenerationsLabel}
          value={String(analytics.summary.totalGenerations)}
          hint={`${text.completedGenerationsLabel}: ${analytics.summary.completedGenerations}`}
          tone="success"
        />
        <AdminKpiCard
          label={text.failedGenerationsLabel}
          value={String(analytics.summary.failedGenerations)}
          hint={`${text.templateEventsLabel}: ${analytics.summary.templateAnalyticsEvents}`}
          tone="danger"
        />
      </AdminPageGrid>

      <UserWalletPanel
        locale={locale}
        userId={user.userId}
        analytics={analytics}
        canAdjustWallet={canViewUserProfile}
        onUpdated={async () => {
          await refresh();
        }}
      />

      <AdminCard title={petText.title} description={petText.description}>
        {petActionError ? <AdminStateCard tone="warning" title={petActionError} /> : null}
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

              return (
                <article key={pet.id} className={styles.dataCard}>
                  <div className={styles.dataHeader}>
                    <strong>{sanitizeSensitiveText(pet.name, 80)}</strong>
                    <AdminStatusBadge color={pet.status === "active" ? "var(--success)" : "var(--warning)"}>
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
                        pet.status === "active" ? petText.hidePetLabel : petText.restorePetLabel
                      }: ${sanitizeSensitiveText(pet.name, 80)}`}
                      disabled={!canViewUserProfile || isPetActionLocked}
                      onClick={() => requestPetStatusChange(pet)}
                    >
                      {pet.status === "active" ? petText.hide : petText.restore}
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
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
                      locale={locale}
                      userId={userId}
                      pet={pet}
                      text={petText}
                      canManagePets={canViewUserProfile}
                      retryLabel={text.supportRetryAction}
                    />
                  ) : null}
                </article>
              );
            })}
          />
        )}
      </AdminCard>

      <AdminCard title={text.userActivityTitle}>
        {analytics.recentActivity.length ? (
          <div className={styles.timeline}>
            {analytics.recentActivity.slice(0, ACTIVITY_LIMIT).map((item) => (
              <article
                key={`${item.kind}:${item.occurredAtUtc}:${item.title}`}
                className={styles.timelineItem}
              >
                <div className={styles.timelineHeader}>
                  <strong>{sanitizeSensitiveText(item.title, 120)}</strong>
                  <span>{formatDateTime(item.occurredAtUtc, locale)}</span>
                </div>
                {item.details ? <p>{sanitizeSensitiveText(item.details, 220)}</p> : null}
              </article>
            ))}
          </div>
        ) : (
          <AdminStateCard tone="info" title={text.userNoActivity} />
        )}
      </AdminCard>

      <AdminPageGrid columns="two">
        <AdminCard title={text.userPurchasesTitle}>
          <DataList
            emptyTitle={text.userNoPurchases}
            items={analytics.recentPurchases.slice(0, RECENT_ITEMS_LIMIT).map((purchase) => (
              <article key={purchase.orderId} className={styles.dataCard}>
                <div className={styles.dataHeader}>
                  <strong>{purchase.sparkToGrant} spark</strong>
                  <AdminStatusBadge color={getPurchaseStatusColor(purchase.status)}>
                    {sanitizeSensitiveText(purchase.status, 48)}
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

        <AdminCard title={text.userGenerationsTitle}>
          <DataList
            emptyTitle={text.userNoGenerations}
            items={analytics.recentGenerations.slice(0, RECENT_ITEMS_LIMIT).map((generation) => (
              <article key={generation.generationId} className={styles.dataCard}>
                <div className={styles.dataHeader}>
                  <strong>{sanitizeSensitiveText(generation.templateTitle, 120)}</strong>
                  <AdminStatusBadge color={getGenerationStatusColor(generation.status)}>
                    {sanitizeSensitiveText(generation.status, 48)}
                  </AdminStatusBadge>
                </div>
                <p>
                  {sanitizeSensitiveText(generation.templateType, 48)} • {generation.tokenCost} PawSpark
                </p>
                <span>
                  {formatDateTime(generation.completedAtUtc ?? generation.createdAtUtc, locale)}
                </span>
              </article>
            ))}
          />
        </AdminCard>
      </AdminPageGrid>

      <AdminPageGrid columns="two">
        <AdminCard title={text.userEventsTitle}>
          <DataList
            emptyTitle={text.userNoEvents}
            items={analytics.recentTemplateEvents.slice(0, RECENT_ITEMS_LIMIT).map((event) => (
              <article key={event.eventId} className={styles.dataCard}>
                <div className={styles.dataHeader}>
                  <strong>{sanitizeSensitiveText(event.eventType, 80)}</strong>
                  <span>{sanitizeSensitiveText(event.templateTitle, 120)}</span>
                </div>
                <p>
                  {sanitizeSensitiveText(event.source, 80)} •{" "}
                  {sanitizeSensitiveText(event.deviceClass, 48)} •{" "}
                  {sanitizeSensitiveText(event.countryCode, 16)}
                </p>
                {event.feedbackMessage ? (
                  <p>{sanitizeSensitiveText(event.feedbackMessage, 220)}</p>
                ) : null}
                <span>{formatDateTime(event.createdAtUtc, locale)}</span>
              </article>
            ))}
          />
        </AdminCard>

        <AdminCard title={text.userFailureBreakdownTitle}>
          {analytics.failureBreakdown.length ? (
            <AdminMetricStrip
              items={analytics.failureBreakdown.map((item) => ({
                label: sanitizeSensitiveText(item.failureCode, 120),
                value: `${item.count} • ${formatDateTime(item.lastOccurredAtUtc, locale)}`,
              }))}
            />
          ) : (
            <AdminStateCard tone="success" title={text.userNoFailures} />
          )}
        </AdminCard>
      </AdminPageGrid>

      <AdminCard title={text.auditEventsLabel}>
        <DataList
          emptyTitle={text.userNoActivity}
          items={analytics.recentAuditEvents.slice(0, AUDIT_ITEMS_LIMIT).map((event) => (
            <article key={event.auditEventId} className={styles.dataCard}>
              <div className={styles.dataHeader}>
                <strong>{sanitizeSensitiveText(event.action, 120)}</strong>
                <span>{formatDateTime(event.occurredAtUtc, locale)}</span>
              </div>
              <p>{sanitizeSensitiveText(event.details, 220)}</p>
            </article>
          ))}
        />
      </AdminCard>
    </AdminPage>
  );
}

function DataList({ items, emptyTitle }: { items: ReactElement[]; emptyTitle: string }) {
  if (!items.length) {
    return <AdminStateCard tone="info" title={emptyTitle} />;
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
  locale,
  pet,
  retryLabel,
  text,
  userId,
}: {
  canManagePets: boolean;
  locale: Locale;
  pet: AdminUserPet;
  retryLabel: string;
  text: UserDetailPetText;
  userId: string;
}) {
  const queryClient = useQueryClient();
  const [photoActionError, setPhotoActionError] = useState<string | null>(null);
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
    mutationFn: ({
      photoId,
      status,
    }: {
      photoId: string;
      status: "active" | "hidden";
    }) => changeAdminUserPetPhotoStatus(userId, pet.id, photoId, status),
    onMutate: () => {
      setPhotoActionError(null);
    },
    onSuccess: async () => {
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
      setPhotoActionError(getAdminErrorMessage(error, text.photoStatusUpdateError));
    },
  });
  const isPhotoActionLocked = photoStatusMutation.isPending || photosQuery.isFetching;
  function requestPhotoStatusChange(photo: AdminUserPetPhoto) {
    if (!canManagePets || isPhotoActionLocked) {
      return;
    }

    photoStatusMutation.mutate({
      photoId: photo.id,
      status: photo.status === "active" ? "hidden" : "active",
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
      className={styles.petDetails}
      aria-busy={
        photosQuery.isFetching || generationsQuery.isFetching || photoStatusMutation.isPending
          ? "true"
          : undefined
      }
    >
      {photoActionError ? <AdminStateCard tone="warning" title={photoActionError} /> : null}
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
              <Image
                src={photo.thumbnailUrl ?? photo.url}
                alt={`${sanitizeSensitiveText(pet.name, 40)} ${text.photoAlt}`}
                width={160}
                height={160}
              />
              <span>
                {photo.isAvatar ? `${text.avatar} • ` : ""}
                {photo.isFavorite ? `${text.favorite} • ` : ""}
                {formatPetStatus(photo.status, text)}
              </span>
              <span>
                {sanitizeSensitiveText(photo.contentType, 64)}
                {typeof photo.fileSizeBytes === "number" ? ` • ${formatBytes(photo.fileSizeBytes)}` : ""}
                {" • "}
                {photo.thumbnailUrl ? text.thumbnailReady : text.originalOnly}
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
                <strong>{sanitizeSensitiveText(generation.templateTitle ?? generation.templateId, 120)}</strong>
                <AdminStatusBadge color={getGenerationStatusColor(generation.status)}>
                  {sanitizeSensitiveText(generation.status, 48)}
                </AdminStatusBadge>
              </div>
              <p>
                {sanitizeSensitiveText(generation.templateType ?? text.fallbackTemplate, 48)} •{" "}
                {generation.tokenCost} PawSpark
              </p>
              <span>{formatDateTime(generation.completedAtUtc ?? generation.createdAtUtc, locale)}</span>
            </article>
          ))}
        />
      ) : (
        <span className={styles.petDetailState}>{text.noGenerations}</span>
      )}
    </div>
  );
}
