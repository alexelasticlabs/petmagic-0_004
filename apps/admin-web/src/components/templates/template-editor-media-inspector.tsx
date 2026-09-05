import { useRef, useState } from "react";

import styles from "@/components/templates/template-editor-assets.module.css";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { Button } from "@/components/ui/button";
import type { Dictionary } from "@/lib/i18n";

export function TemplateEditorMediaInspector({
  url,
  kind,
  title,
  text,
  disabled,
}: {
  url: string;
  kind: "image" | "video";
  title: string;
  text: Dictionary;
  disabled: boolean;
}) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [isOpen, setIsOpen] = useState(false);
  return (
    <>
      <Button
        type="button"
        variant="secondary"
        disabled={disabled}
        onClick={() => {
          setIsOpen(true);
          dialogRef.current?.showModal();
        }}
      >
        {text.editorInspectMedia}
      </Button>
      <dialog
        ref={dialogRef}
        className={styles.mediaDialog}
        aria-label={title}
        onClose={() => setIsOpen(false)}
        onClick={(event) => {
          if (event.target === event.currentTarget) dialogRef.current?.close();
        }}
      >
        <div className={styles.mediaDialogContent}>
          <header>
            <strong>{title} · 2:3</strong>
            <Button type="button" variant="secondary" onClick={() => dialogRef.current?.close()}>
              {text.editorCloseMedia}
            </Button>
          </header>
          {isOpen ? (
            <TemplateSecureMedia
              url={url}
              kind={kind}
              alt={title}
              className={styles.mediaDialogPreview}
              controls={kind === "video"}
              playsInline
              loading="eager"
            />
          ) : null}
        </div>
      </dialog>
    </>
  );
}
