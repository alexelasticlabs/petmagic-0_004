"use client";

import {
  AdminKpiCard,
  AdminPageHero,
  AdminPageGrid,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import styles from "@/components/users-management-page.module.css";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import type { Dictionary } from "@/lib/i18n";

type UsersManagementHeroProps = {
  text: Dictionary;
};

export function UsersManagementHero({ text }: UsersManagementHeroProps) {
  return (
    <AdminPageHero
      eyebrow={text.usersHeroEyebrow}
      title={text.usersTitle}
      description={text.usersHeroDescription}
    />
  );
}

type UsersManagementAccessStateProps = {
  text: Dictionary;
};

export function UsersManagementAccessState({ text }: UsersManagementAccessStateProps) {
  return (
    <AdminStateCard
      tone="info"
      title={text.usersTitle}
      description={text.usersLoadingDescription}
    />
  );
}

type UsersManagementLoadingStateProps = {
  text: Dictionary;
};

export function UsersManagementLoadingState({ text }: UsersManagementLoadingStateProps) {
  return (
    <AdminStateCard tone="info" title={text.usersTitle} description={text.usersLoadingDescription}>
      <div className={styles.skeletonStack} aria-busy="true" aria-live="polite">
        {Array.from({ length: 8 }).map((_, index) => (
          <div key={index} className={styles.skeletonLine} />
        ))}
      </div>
    </AdminStateCard>
  );
}

type UsersManagementSummaryGridProps = {
  blockedUsersValue: string;
  newUsersValue: string;
  openSupportUserCount: number;
  premiumUsersValue: string;
  rangeDays: number;
  totalUsersValue: string;
  activeUsersValue: string;
  ui: UsersManagementPageText;
};

export function UsersManagementSummaryGrid({
  blockedUsersValue,
  newUsersValue,
  openSupportUserCount,
  premiumUsersValue,
  rangeDays,
  totalUsersValue,
  activeUsersValue,
  ui,
}: UsersManagementSummaryGridProps) {
  return (
    <AdminPageGrid columns="four" className={styles.summaryGrid}>
      <AdminKpiCard label={ui.summaryTotal} value={totalUsersValue} tone="primary" />
      <AdminKpiCard label={ui.summaryActive} value={activeUsersValue} tone="success" />
      <AdminKpiCard label={ui.summaryPremium} value={premiumUsersValue} tone="warning" />
      <AdminKpiCard label={ui.summaryBlocked} value={blockedUsersValue} tone="danger" />
      <AdminKpiCard
        label={ui.summaryNew}
        value={newUsersValue}
        hint={`${ui.periodLabel}: ${rangeDays}`}
        tone="info"
      />
      <AdminKpiCard
        label={ui.summaryOpenSupport}
        value={String(openSupportUserCount)}
        tone="magenta"
      />
    </AdminPageGrid>
  );
}
