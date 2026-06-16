import { type CSSProperties, type HTMLAttributes, type ReactNode } from "react";

import styles from "@/components/admin/admin-primitives.module.css";

export type AdminTone =
  | "neutral"
  | "primary"
  | "info"
  | "success"
  | "warning"
  | "danger"
  | "magenta";

type AdminCardProps = {
  title?: ReactNode;
  titleId?: string;
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
  className?: string;
};

type AdminPageHeroProps = {
  eyebrow?: string;
  title: string;
  description?: string;
  badge?: ReactNode;
  actions?: ReactNode;
  metaItems?: readonly ReactNode[];
  className?: string;
};

type AdminSummaryChipsProps = {
  items: readonly ReactNode[];
  className?: string;
};

type AdminSectionHeaderProps = {
  eyebrow?: string;
  title: ReactNode;
  description?: ReactNode;
  aside?: ReactNode;
  className?: string;
};

type AdminMetricStripItem = {
  label: ReactNode;
  value: ReactNode;
};

type AdminMetricStripProps = {
  items: readonly AdminMetricStripItem[];
  className?: string;
};

type AdminPageProps = HTMLAttributes<HTMLElement> & {
  children: ReactNode;
  className?: string;
};

type AdminPageGridProps = HTMLAttributes<HTMLDivElement> & {
  children: ReactNode;
  columns?: "two" | "three" | "four" | "auto";
  className?: string;
};

type AdminToolbarProps = {
  children: ReactNode;
  className?: string;
};

type AdminIconTileProps = {
  icon: ReactNode;
  tone?: AdminTone;
  className?: string;
};

type AdminKpiCardProps = {
  label: ReactNode;
  value: ReactNode;
  hint?: ReactNode;
  delta?: ReactNode;
  icon?: ReactNode;
  tone?: AdminTone;
  className?: string;
};

type AdminBadgeProps = {
  children: ReactNode;
  tone?: AdminTone;
  className?: string;
};

type AdminStateCardProps = {
  title?: ReactNode;
  description?: ReactNode;
  icon?: ReactNode;
  action?: ReactNode;
  children?: ReactNode;
  tone?: AdminTone;
  className?: string;
};

type AdminSelectOption = {
  value: string;
  label: string;
  disabled?: boolean;
};

type AdminSelectFieldProps = {
  label: string;
  value: string;
  options: readonly AdminSelectOption[];
  onChange: (value: string) => void;
  id?: string;
  name?: string;
  disabled?: boolean;
  className?: string;
};

function joinClassNames(...classes: Array<string | false | null | undefined>) {
  return classes.filter(Boolean).join(" ");
}

function styleClass(name: string) {
  return (styles as Record<string, string>)[name];
}

function toneClass(prefix: string, tone: AdminTone) {
  return styleClass(`${prefix}_${tone}`);
}

export function AdminPage({ children, className, ...rest }: AdminPageProps) {
  return (
    <section className={joinClassNames(styles.page, className)} {...rest}>
      {children}
    </section>
  );
}

export function AdminPageGrid({
  children,
  columns = "auto",
  className,
  ...rest
}: AdminPageGridProps) {
  return (
    <div
      className={joinClassNames(styles.pageGrid, styleClass(`pageGrid_${columns}`), className)}
      {...rest}
    >
      {children}
    </div>
  );
}

export function AdminToolbar({ children, className }: AdminToolbarProps) {
  return <div className={joinClassNames(styles.toolbar, className)}>{children}</div>;
}

export function AdminFilterBar({ children, className }: AdminToolbarProps) {
  return <div className={joinClassNames(styles.filterBar, className)}>{children}</div>;
}

export function AdminIconTile({ icon, tone = "primary", className }: AdminIconTileProps) {
  return (
    <span className={joinClassNames(styles.iconTile, toneClass("iconTile", tone), className)}>
      {icon}
    </span>
  );
}

export function AdminKpiCard({
  label,
  value,
  hint,
  delta,
  icon,
  tone = "primary",
  className,
}: AdminKpiCardProps) {
  return (
    <article className={joinClassNames(styles.kpiCard, toneClass("kpiCard", tone), className)}>
      <div className={styles.kpiBody}>
        <span className={styles.kpiLabel}>{label}</span>
        <strong className={styles.kpiValue}>{value}</strong>
        {delta ? <span className={styles.kpiDelta}>{delta}</span> : null}
        {hint ? <span className={styles.kpiHint}>{hint}</span> : null}
      </div>
      {icon ? <AdminIconTile icon={icon} tone={tone} /> : null}
    </article>
  );
}

export function AdminBadge({ children, tone = "neutral", className }: AdminBadgeProps) {
  return (
    <span className={joinClassNames(styles.badge, toneClass("badge", tone), className)}>
      {children}
    </span>
  );
}

export function AdminStateCard({
  title,
  description,
  icon,
  action,
  children,
  tone = "neutral",
  className,
}: AdminStateCardProps) {
  const stateRole = tone === "danger" || tone === "warning" ? "alert" : "status";
  const stateLiveMode = stateRole === "alert" ? "assertive" : "polite";

  return (
    <section
      className={joinClassNames(styles.stateCard, toneClass("stateCard", tone), className)}
      role={stateRole}
      aria-live={stateLiveMode}
    >
      {icon ? <AdminIconTile icon={icon} tone={tone} /> : null}
      <div className={styles.stateCardBody}>
        {title ? <h2 className={styles.stateCardTitle}>{title}</h2> : null}
        {description ? <p className={styles.stateCardText}>{description}</p> : null}
        {children}
      </div>
      {action ? <div className={styles.stateCardAction}>{action}</div> : null}
    </section>
  );
}

export function AdminSelectField({
  label,
  value,
  options,
  onChange,
  id,
  name,
  disabled,
  className,
}: AdminSelectFieldProps) {
  const hasOptions = options.length > 0;
  const isSelectDisabled = disabled || !hasOptions;

  return (
    <label className={joinClassNames(styles.selectField, className)}>
      <span className={styles.selectLabel}>{label}</span>
      <select
        id={id}
        name={name}
        value={value}
        disabled={isSelectDisabled}
        onChange={(event) => {
          if (isSelectDisabled) {
            return;
          }

          onChange(event.target.value);
        }}
        className={styles.selectControl}
      >
        {options.map((option) => (
          <option key={option.value} value={option.value} disabled={option.disabled}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

export function AdminCard({
  title,
  titleId,
  description,
  action,
  children,
  padding = "lg",
  className,
}: AdminCardProps) {
  const paddingClass = padding === "lg" ? styles.cardPaddingLg : styles.cardPaddingMd;
  const hasHeader = title || description || action;

  return (
    <section className={joinClassNames(styles.card, paddingClass, className)}>
      {hasHeader ? (
        <div className={styles.cardHeader}>
          <div className={styles.cardTitleGroup}>
            {title ? (
              <h2 id={titleId} className={styles.cardTitle}>
                {title}
              </h2>
            ) : null}
            {description ? <p className={styles.cardDescription}>{description}</p> : null}
          </div>
          {action ? <div className={styles.cardAction}>{action}</div> : null}
        </div>
      ) : null}
      {children}
    </section>
  );
}

export function AdminStatCard({
  label,
  value,
  delta,
  subtext,
  accentColor,
  icon,
}: AdminStatCardProps) {
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

export function AdminStatusBadge({ children, color, className }: AdminStatusBadgeProps) {
  const style = { "--status-color": color } as CSSProperties;
  const badgeClassName = className ? `${styles.statusBadge} ${className}` : styles.statusBadge;

  return (
    <span className={badgeClassName} style={style}>
      {children}
    </span>
  );
}

export function AdminSummaryChips({ items, className }: AdminSummaryChipsProps) {
  const visibleItems = items.filter(Boolean);

  if (!visibleItems.length) {
    return null;
  }

  return (
    <div className={joinClassNames(styles.pageMeta, className)}>
      {visibleItems.map((item, index) => (
        <span key={index} className={styles.pageMetaItem}>
          {item}
        </span>
      ))}
    </div>
  );
}

export function AdminPageHero({
  eyebrow,
  title,
  description,
  badge,
  actions,
  metaItems = [],
  className,
}: AdminPageHeroProps) {
  const hasAside = badge || actions;

  return (
    <section className={joinClassNames(styles.pageHero, className)}>
      <div className={styles.pageHeroHead}>
        <div className={styles.pageTitleGroup}>
          {eyebrow ? <p className={styles.pageEyebrow}>{eyebrow}</p> : null}
          <h1 className={styles.pageTitle}>{title}</h1>
          {description ? <p className={styles.pageDescription}>{description}</p> : null}
        </div>
        {hasAside ? (
          <div className={styles.pageHeroAside}>
            {actions}
            {badge ? <span className={styles.pageBadge}>{badge}</span> : null}
          </div>
        ) : null}
      </div>
      <AdminSummaryChips items={metaItems} />
    </section>
  );
}

export function AdminSectionHeader({
  eyebrow,
  title,
  description,
  aside,
  className,
}: AdminSectionHeaderProps) {
  return (
    <div className={joinClassNames(styles.sectionHeader, className)}>
      <div className={styles.sectionHeaderCopy}>
        {eyebrow ? <p className={styles.sectionEyebrow}>{eyebrow}</p> : null}
        <h2 className={styles.sectionHeading}>{title}</h2>
        {description ? <p className={styles.sectionText}>{description}</p> : null}
      </div>
      {aside ? <div className={styles.sectionHeaderAside}>{aside}</div> : null}
    </div>
  );
}

export function AdminMetricStrip({ items, className }: AdminMetricStripProps) {
  const visibleItems = items.filter((item) => item && (item.label || item.value));

  if (!visibleItems.length) {
    return null;
  }

  return (
    <div className={joinClassNames(styles.metricStrip, className)}>
      {visibleItems.map((item, index) => (
        <div key={index} className={styles.metricChip}>
          <span className={styles.metricChipLabel}>{item.label}</span>
          <strong className={styles.metricChipValue}>{item.value}</strong>
        </div>
      ))}
    </div>
  );
}

export const adminTableStyles = {
  tableWrap: styles.tableWrap,
  table: styles.table,
  mono: styles.mono,
  numeric: styles.numeric,
  empty: styles.tableEmpty,
};

export const adminPageStyles = {
  page: styles.page,
  pageGrid: styles.pageGrid,
  pageHero: styles.pageHero,
  pageHeroHead: styles.pageHeroHead,
  pageHeroAside: styles.pageHeroAside,
  pageTitleGroup: styles.pageTitleGroup,
  pageEyebrow: styles.pageEyebrow,
  pageTitle: styles.pageTitle,
  pageDescription: styles.pageDescription,
  pageBadge: styles.pageBadge,
  pageMeta: styles.pageMeta,
  pageMetaItem: styles.pageMetaItem,
};
