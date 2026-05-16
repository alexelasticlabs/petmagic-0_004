import styles from "@/components/admin/admin-primitives.module.css";
import { type CSSProperties, type ReactNode } from "react";

type AdminCardProps = {
  title?: string;
  description?: string;
  action?: ReactNode;
  children: ReactNode;
  padding?: "md" | "lg";
  className?: string;
};

type AdminStatCardProps = {
  label: string;
  value: string;
  delta: ReactNode;
  subtext: string;
  accentColor: string;
  icon: ReactNode;
};

type AdminStatusBadgeProps = {
  children: ReactNode;
  color: string;
};

function joinClassNames(...classes: Array<string | false | null | undefined>) {
  return classes.filter(Boolean).join(" ");
}

export function AdminCard({ title, description, action, children, padding = "lg", className }: AdminCardProps) {
  const paddingClass = padding === "lg" ? styles.cardPaddingLg : styles.cardPaddingMd;
  const hasHeader = title || description || action;

  return (
    <section className={joinClassNames(styles.card, paddingClass, className)}>
      {hasHeader ? (
        <div className={styles.cardHeader}>
          <div className={styles.cardTitleGroup}>
            {title ? <h2 className={styles.cardTitle}>{title}</h2> : null}
            {description ? <p className={styles.cardDescription}>{description}</p> : null}
          </div>
          {action ? <div className={styles.cardAction}>{action}</div> : null}
        </div>
      ) : null}
      {children}
    </section>
  );
}

export function AdminStatCard({ label, value, delta, subtext, accentColor, icon }: AdminStatCardProps) {
  const style = { "--stat-accent": accentColor } as CSSProperties;

  return (
    <section className={styles.statCard} style={style}>
      <div className={styles.statContent}>
        <p className={styles.statLabel}>{label}</p>
        <p className={styles.statValue}>{value}</p>
        <p className={styles.statDelta}>{delta}</p>
        <p className={styles.statSubtext}>{subtext}</p>
      </div>
      <div className={styles.statIcon}>{icon}</div>
    </section>
  );
}

export function AdminStatusBadge({ children, color }: AdminStatusBadgeProps) {
  const style = { "--status-color": color } as CSSProperties;
  return (
    <span className={styles.statusBadge} style={style}>
      {children}
    </span>
  );
}

export const adminTableStyles = {
  tableWrap: styles.tableWrap,
  table: styles.table,
  mono: styles.mono,
  numeric: styles.numeric,
};
