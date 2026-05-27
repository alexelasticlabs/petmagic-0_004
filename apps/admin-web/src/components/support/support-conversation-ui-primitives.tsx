import { type ReactNode } from "react";

import { AdminStateCard } from "@/components/admin/admin-primitives";
import styles from "@/components/support/support-page.module.css";
import { Button } from "@/components/ui/button";

type TimelineCardProps = {
  title: string;
  timestampLabel: string;
  details?: ReactNode;
  meta?: ReactNode;
};

type SectionBlockProps = {
  title: string;
  children: ReactNode;
};

type SidePanelAsyncStateProps = {
  isLoading: boolean;
  isError: boolean;
  hasContent: boolean;
  loadingTitle: string;
  errorTitle: string;
  retryLabel?: string;
  onRetry?: () => void;
  emptyTitle: string;
  children: ReactNode;
};

export function TimelineCard({ title, timestampLabel, details, meta }: TimelineCardProps) {
  return (
    <article className={styles.timelineCard}>
      <div className={styles.timelineCardHeader}>
        <strong>{title}</strong>
        <span>{timestampLabel}</span>
      </div>
      {meta ? <div className={styles.rowMetaGroup}>{meta}</div> : null}
      {details !== undefined ? <p className={styles.timelineCardBody}>{details}</p> : null}
    </article>
  );
}

export function SectionBlock({ title, children }: SectionBlockProps) {
  return (
    <div className={styles.sectionBlock}>
      <div className={styles.sectionHeaderCompact}>
        <strong>{title}</strong>
      </div>
      {children}
    </div>
  );
}

export function SidePanelAsyncState({
  isLoading,
  isError,
  hasContent,
  loadingTitle,
  errorTitle,
  retryLabel,
  onRetry,
  emptyTitle,
  children,
}: SidePanelAsyncStateProps) {
  if (isLoading) {
    return <AdminStateCard tone="info" title={loadingTitle} />;
  }

  if (isError) {
    return (
      <AdminStateCard
        tone="danger"
        title={errorTitle}
        action={
          onRetry && retryLabel ? (
            <Button variant="secondary" size="sm" onClick={onRetry}>
              {retryLabel}
            </Button>
          ) : null
        }
      />
    );
  }

  if (!hasContent) {
    return <AdminStateCard tone="info" title={emptyTitle} />;
  }

  return <>{children}</>;
}
