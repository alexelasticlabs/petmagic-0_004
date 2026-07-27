"use client";

import { type ReactNode } from "react";

import { Button } from "@/components/ui/button";

import styles from "./admin-selection-tray.module.css";

export type AdminSelectionTrayItem = {
  id: string;
  label: string;
  description?: string;
  eligible: boolean;
  eligibilityLabel: string;
  removeLabel: string;
};

type AdminSelectionTrayProps = {
  selectedCount: number;
  selectedLabel: string;
  trayLabel: string;
  clearLabel: string;
  onClear: () => void;
  description?: string;
  busy?: boolean;
  items?: readonly AdminSelectionTrayItem[];
  onRemove?: (itemId: string) => void;
  children?: ReactNode;
};

export function AdminSelectionTray({
  selectedCount,
  selectedLabel,
  trayLabel,
  clearLabel,
  onClear,
  description,
  busy = false,
  items = [],
  onRemove,
  children,
}: AdminSelectionTrayProps) {
  if (selectedCount <= 0) {
    return null;
  }

  return (
    <aside className={styles.tray} aria-label={trayLabel} aria-busy={busy}>
      <div className={styles.summary}>
        <output
          className={styles.count}
          aria-live="polite"
          aria-label={`${selectedCount}: ${selectedLabel}`}
        >
          {selectedCount}
        </output>
        <div className={styles.copy}>
          <strong className={styles.label}>{selectedLabel}</strong>
          {description ? <span className={styles.description}>{description}</span> : null}
        </div>
      </div>
      <div className={styles.details}>
        {items.length > 0 ? (
          <ul className={styles.items}>
            {items.map((item) => (
              <li key={item.id} className={styles.item} data-eligible={item.eligible}>
                <span className={styles.itemCopy}>
                  <strong>{item.label}</strong>
                  <span>
                    {item.description ? `${item.description} · ` : ""}
                    {item.eligibilityLabel}
                  </span>
                </span>
                {onRemove ? (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => onRemove(item.id)}
                    disabled={busy}
                    aria-label={`${item.removeLabel}: ${item.label}`}
                    title={`${item.removeLabel}: ${item.label}`}
                  >
                    {item.removeLabel}
                  </Button>
                ) : null}
              </li>
            ))}
          </ul>
        ) : null}
        <div className={styles.actions}>
          {children}
          <Button variant="ghost" size="sm" onClick={onClear} disabled={busy}>
            {clearLabel}
          </Button>
        </div>
      </div>
    </aside>
  );
}
