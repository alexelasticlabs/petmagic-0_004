import { type HTMLAttributes, type ReactNode } from "react";

import styles from "./admin-queue-layout.module.css";

function joinClassNames(...classNames: Array<string | undefined>) {
  return classNames.filter(Boolean).join(" ");
}

type AdminQueueLayoutProps = Omit<HTMLAttributes<HTMLDivElement>, "children"> & {
  queue: ReactNode;
  queueLabel: string;
  workspaceLabel: string;
  inspector?: ReactNode;
  children: ReactNode;
};

export function AdminQueueLayout({
  queue,
  queueLabel,
  workspaceLabel,
  inspector,
  children,
  className,
  ...rest
}: AdminQueueLayoutProps) {
  return (
    <div
      className={joinClassNames(styles.queueLayout, className)}
      data-has-inspector={inspector ? "true" : "false"}
      {...rest}
    >
      <section className={styles.queuePane} aria-label={queueLabel}>
        {queue}
      </section>
      <section className={styles.workspacePane} aria-label={workspaceLabel}>
        {children}
      </section>
      {inspector ? <div className={styles.inspectorSlot}>{inspector}</div> : null}
    </div>
  );
}

type AdminInspectorBaseProps = Omit<HTMLAttributes<HTMLElement>, "title"> & {
  title: string;
  description?: string;
  actions?: ReactNode;
  footer?: ReactNode;
  children: ReactNode;
};

type AdminInspectorCloseProps =
  { onClose: () => void; closeLabel: string } | { onClose?: undefined; closeLabel?: undefined };

export type AdminInspectorProps = AdminInspectorBaseProps & AdminInspectorCloseProps;

export function AdminInspector({
  title,
  description,
  actions,
  footer,
  children,
  onClose,
  closeLabel,
  className,
  ...rest
}: AdminInspectorProps) {
  return (
    <aside className={joinClassNames(styles.inspector, className)} aria-label={title} {...rest}>
      <header className={styles.inspectorHeader}>
        <div className={styles.inspectorHeading}>
          <h2 className={styles.inspectorTitle}>{title}</h2>
          {description ? <p className={styles.inspectorDescription}>{description}</p> : null}
        </div>
        {actions || onClose ? (
          <div className={styles.inspectorActions}>
            {actions}
            {onClose ? (
              <button
                type="button"
                className={styles.inspectorClose}
                onClick={onClose}
                aria-label={closeLabel}
                title={closeLabel}
              >
                <span aria-hidden="true">×</span>
              </button>
            ) : null}
          </div>
        ) : null}
      </header>
      <div className={styles.inspectorBody}>{children}</div>
      {footer ? <footer className={styles.inspectorFooter}>{footer}</footer> : null}
    </aside>
  );
}
