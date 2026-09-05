"use client";

import { useEffect, useRef } from "react";
import { createPortal } from "react-dom";

import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import styles from "@/components/templates/templates-catalog.module.css";
import { Button } from "@/components/ui/button";

type TemplateCatalogPreviewProps = {
  url: string;
  kind: "image" | "video";
  title: string;
  description: string;
  closeLabel: string;
  errorLabel: string;
  onClose: () => void;
};

export function TemplateCatalogPreview({
  url,
  kind,
  title,
  description,
  closeLabel,
  errorLabel,
  onClose,
}: TemplateCatalogPreviewProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    const returnFocusTo = document.activeElement;
    const previousOverflow = document.body.style.overflow;
    dialog?.showModal();
    document.body.style.overflow = "hidden";
    return () => {
      dialog?.close();
      document.body.style.overflow = previousOverflow;
      queueMicrotask(() => {
        if (returnFocusTo instanceof HTMLElement && returnFocusTo.isConnected) {
          returnFocusTo.focus({ preventScroll: true });
        }
      });
    };
  }, []);

  return createPortal(
    <dialog
      ref={dialogRef}
      className={styles.previewDialog}
      aria-label={title}
      onCancel={onClose}
      onClose={onClose}
      onClick={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div className={styles.previewDialogHeader}>
        <h2>{title}</h2>
        <Button type="button" variant="secondary" size="sm" onClick={onClose}>
          {closeLabel}
        </Button>
      </div>
      <TemplateSecureMedia
        url={url}
        kind={kind}
        alt={title}
        ariaLabel={title}
        className={styles.previewDialogMedia}
        controls={kind === "video"}
        playsInline
        preload="metadata"
        loading="eager"
        fallback={
          <p className={styles.previewDialogDescription} role="status">
            {errorLabel}
          </p>
        }
      />
      {description ? <p className={styles.previewDialogDescription}>{description}</p> : null}
    </dialog>,
    document.body
  );
}
