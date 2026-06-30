"use client";

import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import type { TemplatesCatalogViewText } from "@/components/templates/templates-catalog-view.content";
import type { AdminTemplateListItem } from "@/lib/api-client";
import type { Dictionary } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplatesCatalogDialogsProps = {
  copy: TemplatesCatalogViewText;
  isTemplateActionLocked: boolean;
  onCancelArchive: () => void;
  onCancelDelete: () => void;
  onConfirmArchive: () => void;
  onConfirmDelete: () => void;
  templatePendingArchiveId: string | null;
  templatePendingDeleteId: string | null;
  templates: AdminTemplateListItem[];
  text: Dictionary;
};

export function TemplatesCatalogDialogs({
  copy,
  isTemplateActionLocked,
  onCancelArchive,
  onCancelDelete,
  onConfirmArchive,
  onConfirmDelete,
  templatePendingArchiveId,
  templatePendingDeleteId,
  templates,
  text,
}: TemplatesCatalogDialogsProps) {
  return (
    <>
      <ConfirmationDialog
        open={templatePendingArchiveId !== null}
        title={text.archive}
        description={
          templatePendingArchiveId
            ? copy.archiveConfirmDescription(
                formatTemplateActionLabel(templates, templatePendingArchiveId)
              )
            : ""
        }
        confirmLabel={text.archive}
        cancelLabel={copy.cancel}
        tone="danger"
        isSubmitting={Boolean(templatePendingArchiveId && isTemplateActionLocked)}
        onCancel={() => {
          if (!isTemplateActionLocked) {
            onCancelArchive();
          }
        }}
        onConfirm={onConfirmArchive}
      />
      <ConfirmationDialog
        open={templatePendingDeleteId !== null}
        title={text.deleteTemplate}
        description={
          templatePendingDeleteId
            ? `${formatTemplateActionLabel(templates, templatePendingDeleteId)}: ${text.confirmDeleteTemplate}`
            : ""
        }
        confirmLabel={text.deleteTemplate}
        cancelLabel={copy.cancel}
        isSubmitting={Boolean(templatePendingDeleteId && isTemplateActionLocked)}
        onCancel={() => {
          if (!isTemplateActionLocked) {
            onCancelDelete();
          }
        }}
        onConfirm={onConfirmDelete}
      />
    </>
  );
}

export function formatTemplateActionLabel(
  templates: AdminTemplateListItem[],
  templateId: string
): string {
  const template = templates.find((item) => item.templateId === templateId);
  return sanitizeSensitiveText(template?.title ?? templateId, 96);
}
