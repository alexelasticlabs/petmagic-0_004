"use client";

import { useEffect, type ReactNode } from "react";
import { createPortal } from "react-dom";

import styles from "@/components/admin/confirmation-dialog.module.css";
import { Button } from "@/components/ui/button";

type ConfirmationDialogProps = {
  open: boolean;
  title: string;
  description: string;
  confirmLabel: string;
  cancelLabel: string;
  confirmDisabled?: boolean;
  children?: ReactNode;
  isSubmitting?: boolean;
  tone?: "danger" | "primary";
  onCancel: () => void;
  onConfirm: () => void;
};

export function ConfirmationDialog({
  open,
  title,
  description,
  confirmLabel,
  cancelLabel,
  confirmDisabled = false,
  children,
  isSubmitting = false,
  tone = "danger",
  onCancel,
  onConfirm,
}: ConfirmationDialogProps) {
  useEffect(() => {
    if (!open || isSubmitting) {
      return;
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        onCancel();
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [isSubmitting, onCancel, open]);

  if (!open || typeof document === "undefined") {
    return null;
  }

  return createPortal(
    <div className={styles.backdrop} onClick={isSubmitting ? undefined : onCancel}>
      <section
        className={styles.dialog}
        role="dialog"
        aria-modal="true"
        aria-labelledby="admin-confirmation-title"
        aria-describedby="admin-confirmation-description"
        onClick={(event) => event.stopPropagation()}
      >
        <h2 id="admin-confirmation-title" className={styles.title}>
          {title}
        </h2>
        <p id="admin-confirmation-description" className={styles.description}>
          {description}
        </p>
        {children}
        <div className={styles.actions}>
          <Button variant="ghost" size="sm" onClick={onCancel} disabled={isSubmitting}>
            {cancelLabel}
          </Button>
          <Button
            variant={tone === "danger" ? "danger" : "primary"}
            size="sm"
            onClick={onConfirm}
            disabled={isSubmitting || confirmDisabled}
          >
            {confirmLabel}
          </Button>
        </div>
      </section>
    </div>,
    document.body
  );
}
