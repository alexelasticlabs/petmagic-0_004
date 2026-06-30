"use client";

import { type Dispatch, type FormEvent, type SetStateAction } from "react";

import { PromoCodesActionsMenuPortal } from "@/components/promo-codes-actions-menu-portal";
import { PromoCodesEditorDrawer } from "@/components/promo-codes-editor-drawer";
import { PromoCodesArchiveDialog } from "@/components/promo-codes-view.chrome";
import { type PromoForm, type PromoFormMode } from "@/components/promo-codes-view.helpers";
import { type SelectOption } from "@/components/ui/select";
import { type ActionsMenuPosition } from "@/components/use-promo-actions-menu";
import { type AdminRedeemCode } from "@/lib/api-client";
import { getDictionary } from "@/lib/i18n";

type PromoCodesViewOverlaysProps = {
  actionsMenuCode: AdminRedeemCode | null;
  actionsMenuPosition: ActionsMenuPosition | null;
  text: ReturnType<typeof getDictionary>;
  minWidthPx: number;
  isActionsMenuArchived: boolean;
  isActionsMenuBusy: boolean;
  onViewActivations: (code: AdminRedeemCode) => void;
  onRestore: (code: AdminRedeemCode) => void;
  onCopyCode: (code: string) => Promise<void>;
  onEdit: (code: AdminRedeemCode) => void;
  onToggleState: (code: AdminRedeemCode) => void;
  onArchive: (code: AdminRedeemCode) => void;
  isEditorOpen: boolean;
  panelMode: PromoFormMode;
  form: PromoForm;
  setForm: Dispatch<SetStateAction<PromoForm>>;
  formStatusOptions: SelectOption[];
  selectedCode: AdminRedeemCode | null;
  isMutating: boolean;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onCloseEditor: () => void;
  onResetEditor: () => void;
  onGenerateCode: () => void;
  codePendingArchive: AdminRedeemCode | null;
  archiveActionLabel: string;
  archiveCancelLabel: string;
  archiveConfirmText: string;
  busyCodeId: string | null;
  onCancelArchive: () => void;
  onConfirmArchive: () => void;
};

export function PromoCodesViewOverlays({
  actionsMenuCode,
  actionsMenuPosition,
  text,
  minWidthPx,
  isActionsMenuArchived,
  isActionsMenuBusy,
  onViewActivations,
  onRestore,
  onCopyCode,
  onEdit,
  onToggleState,
  onArchive,
  isEditorOpen,
  panelMode,
  form,
  setForm,
  formStatusOptions,
  selectedCode,
  isMutating,
  onSubmit,
  onCloseEditor,
  onResetEditor,
  onGenerateCode,
  codePendingArchive,
  archiveActionLabel,
  archiveCancelLabel,
  archiveConfirmText,
  busyCodeId,
  onCancelArchive,
  onConfirmArchive,
}: PromoCodesViewOverlaysProps) {
  return (
    <>
      <PromoCodesActionsMenuPortal
        actionsMenuCode={actionsMenuCode}
        actionsMenuPosition={actionsMenuPosition}
        text={text}
        minWidthPx={minWidthPx}
        isActionsMenuArchived={isActionsMenuArchived}
        isActionsMenuBusy={isActionsMenuBusy}
        onViewActivations={onViewActivations}
        onRestore={onRestore}
        onCopyCode={onCopyCode}
        onEdit={onEdit}
        onToggleState={onToggleState}
        onArchive={onArchive}
      />

      <PromoCodesEditorDrawer
        isOpen={isEditorOpen}
        panelMode={panelMode}
        text={text}
        form={form}
        setForm={setForm}
        formStatusOptions={formStatusOptions}
        selectedCode={selectedCode}
        isMutating={isMutating}
        onSubmit={onSubmit}
        onClose={onCloseEditor}
        onReset={onResetEditor}
        onGenerateCode={onGenerateCode}
        onToggleCodeState={onToggleState}
      />

      <PromoCodesArchiveDialog
        archiveActionLabel={archiveActionLabel}
        cancelLabel={archiveCancelLabel}
        archiveConfirmText={archiveConfirmText}
        codePendingArchive={codePendingArchive}
        busyCodeId={busyCodeId}
        isMutating={isMutating}
        onCancel={onCancelArchive}
        onConfirm={onConfirmArchive}
      />
    </>
  );
}
