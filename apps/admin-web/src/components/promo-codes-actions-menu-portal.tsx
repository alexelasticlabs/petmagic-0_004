"use client";

import { createPortal } from "react-dom";

import { type ActionsMenuPosition } from "@/components/use-promo-actions-menu";
import { type AdminRedeemCode } from "@/lib/api-client";
import { getDictionary } from "@/lib/i18n";

import styles from "@/components/promo-codes-view.module.css";

type PromoCodesActionsMenuPortalProps = {
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
};

export function PromoCodesActionsMenuPortal({
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
}: PromoCodesActionsMenuPortalProps) {
    if (!actionsMenuCode || !actionsMenuPosition || typeof window === "undefined") {
        return null;
    }

    return createPortal(
        <div
            className={styles.actionsMenuPortal}
            style={{
                top: actionsMenuPosition.top,
                left: actionsMenuPosition.left,
                minWidth: minWidthPx,
                transform: actionsMenuPosition.openUpward ? "translateY(-100%)" : undefined,
            }}
            role="menu"
            aria-label={text.promoCodesActionsMenuLabel}
            data-promo-actions-root
        >
            <div className={`${styles.actionsMenuList} ${styles.actionsMenuListPortal}`}>
                {isActionsMenuArchived ? (
                    <>
                        <button
                            type="button"
                            className={styles.actionsMenuItem}
                            onClick={() => onViewActivations(actionsMenuCode)}
                        >
                            {text.promoCodesViewActivationsAction}
                        </button>
                        <button
                            type="button"
                            className={styles.actionsMenuItem}
                            onClick={() => onRestore(actionsMenuCode)}
                            disabled={isActionsMenuBusy}
                        >
                            {text.promoCodesRestoreAction}
                        </button>
                    </>
                ) : (
                    <>
                        <button
                            type="button"
                            className={styles.actionsMenuItem}
                            onClick={() =>
                                void onCopyCode(actionsMenuCode.code || `${actionsMenuCode.codePrefix}...`)
                            }
                        >
                            {text.promoCodesCopyAction}
                        </button>
                        <button
                            type="button"
                            className={styles.actionsMenuItem}
                            onClick={() => onEdit(actionsMenuCode)}
                        >
                            {text.editTemplate}
                        </button>
                        <button
                            type="button"
                            className={styles.actionsMenuItem}
                            onClick={() => onViewActivations(actionsMenuCode)}
                        >
                            {text.promoCodesViewActivationsAction}
                        </button>
                        <button
                            type="button"
                            className={styles.actionsMenuItem}
                            onClick={() => onToggleState(actionsMenuCode)}
                            disabled={isActionsMenuBusy}
                        >
                            {actionsMenuCode.isActive ? text.promoCodesPauseAction : text.promoCodesResumeAction}
                        </button>
                        <button
                            type="button"
                            className={`${styles.actionsMenuItem} ${styles.actionsMenuItemDanger}`}
                            onClick={() => onArchive(actionsMenuCode)}
                            disabled={!actionsMenuCode.isActive || isActionsMenuBusy}
                        >
                            {text.archive}
                        </button>
                    </>
                )}
            </div>
        </div>,
        document.body
    );
}
