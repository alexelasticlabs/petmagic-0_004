"use client";

import { useCallback, useEffect, useState } from "react";

const ACTIONS_MENU_WIDTH_PX = 220;
const ACTIONS_MENU_HEIGHT_ESTIMATE_PX = 236;
const ACTIONS_MENU_GAP_PX = 8;

export type ActionsMenuPosition = {
  top: number;
  left: number;
  openUpward: boolean;
};

export function usePromoActionsMenu() {
  const [actionsMenuCodeId, setActionsMenuCodeId] = useState<string | null>(null);
  const [actionsMenuPosition, setActionsMenuPosition] = useState<ActionsMenuPosition | null>(null);

  const closeActionsMenu = useCallback(() => {
    setActionsMenuCodeId(null);
    setActionsMenuPosition(null);
  }, []);

  const getActionsMenuPosition = useCallback((trigger: HTMLElement): ActionsMenuPosition => {
    const rect = trigger.getBoundingClientRect();
    const openUpward = window.innerHeight - rect.bottom < ACTIONS_MENU_HEIGHT_ESTIMATE_PX;
    const maxLeft = Math.max(
      ACTIONS_MENU_GAP_PX,
      window.innerWidth - ACTIONS_MENU_WIDTH_PX - ACTIONS_MENU_GAP_PX
    );

    return {
      top: openUpward ? rect.top - ACTIONS_MENU_GAP_PX : rect.bottom + ACTIONS_MENU_GAP_PX,
      left: Math.min(Math.max(ACTIONS_MENU_GAP_PX, rect.right - ACTIONS_MENU_WIDTH_PX), maxLeft),
      openUpward,
    };
  }, []);

  const handleToggleActionsMenu = useCallback(
    (codeId: string, trigger: HTMLElement) => {
      if (actionsMenuCodeId === codeId) {
        closeActionsMenu();
        return;
      }

      setActionsMenuCodeId(codeId);
      setActionsMenuPosition(getActionsMenuPosition(trigger));
    },
    [actionsMenuCodeId, closeActionsMenu, getActionsMenuPosition]
  );

  useEffect(() => {
    if (!actionsMenuCodeId) {
      return;
    }

    function handlePointerDown(event: PointerEvent) {
      const target = event.target as HTMLElement | null;
      if (target?.closest("[data-promo-actions-root]")) {
        return;
      }

      closeActionsMenu();
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        closeActionsMenu();
      }
    }

    function handleViewportChange() {
      closeActionsMenu();
    }

    window.addEventListener("pointerdown", handlePointerDown);
    window.addEventListener("keydown", handleKeyDown);
    window.addEventListener("resize", handleViewportChange);
    window.addEventListener("scroll", handleViewportChange, true);

    return () => {
      window.removeEventListener("pointerdown", handlePointerDown);
      window.removeEventListener("keydown", handleKeyDown);
      window.removeEventListener("resize", handleViewportChange);
      window.removeEventListener("scroll", handleViewportChange, true);
    };
  }, [actionsMenuCodeId, closeActionsMenu]);

  return {
    actionsMenuCodeId,
    actionsMenuPosition,
    closeActionsMenu,
    handleToggleActionsMenu,
  };
}
