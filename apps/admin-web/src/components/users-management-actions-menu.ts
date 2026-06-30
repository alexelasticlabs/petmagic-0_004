"use client";

import { useCallback, useEffect, useRef, useState } from "react";

import type { ActionsMenuPosition } from "@/components/users-management-page.types";

const ACTIONS_MENU_TARGET_WIDTH_PX = 250;
const ACTIONS_MENU_VIEWPORT_PADDING_PX = 8;

export function useUsersManagementActionsMenu(canManageRoles: boolean) {
  const [openActionsUserId, setOpenActionsUserId] = useState<string | null>(null);
  const [actionsMenuPosition, setActionsMenuPosition] = useState<ActionsMenuPosition | null>(null);
  const menuRootRef = useRef<HTMLDivElement | null>(null);
  const triggerRefs = useRef<Record<string, HTMLButtonElement | null>>({});

  const closeActionsMenu = useCallback(() => {
    setOpenActionsUserId(null);
    setActionsMenuPosition(null);
  }, []);

  const updateActionsMenuPosition = useCallback(
    (userId: string) => {
      const trigger = triggerRefs.current[userId];
      if (!trigger) {
        closeActionsMenu();
        return;
      }

      const triggerRect = trigger.getBoundingClientRect();
      const gap = 6;
      const viewportPadding = ACTIONS_MENU_VIEWPORT_PADDING_PX;
      const availableWidth = Math.max(0, window.innerWidth - viewportPadding * 2);
      const minWidth = Math.min(ACTIONS_MENU_TARGET_WIDTH_PX, availableWidth);
      const estimatedHeight = canManageRoles ? 356 : 252;
      const availableBelow = window.innerHeight - triggerRect.bottom - gap;
      const availableAbove = triggerRect.top - gap;
      const openUpward = availableBelow < estimatedHeight && availableAbove > availableBelow;
      const top = openUpward ? triggerRect.top - gap : triggerRect.bottom + gap;

      let left = triggerRect.right - minWidth;
      left = Math.max(viewportPadding, left);
      left = Math.min(left, window.innerWidth - minWidth - viewportPadding);

      setActionsMenuPosition({ top, left, minWidth, openUpward });
    },
    [canManageRoles, closeActionsMenu]
  );

  const handleToggleActionsMenu = useCallback(
    (userId: string) => {
      if (openActionsUserId === userId) {
        closeActionsMenu();
        return;
      }

      setOpenActionsUserId(userId);
      requestAnimationFrame(() => {
        updateActionsMenuPosition(userId);
      });
    },
    [closeActionsMenu, openActionsUserId, updateActionsMenuPosition]
  );

  useEffect(() => {
    if (!openActionsUserId) {
      return;
    }

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target;
      if (!(target instanceof Node)) {
        return;
      }

      if (menuRootRef.current?.contains(target)) {
        return;
      }

      if (triggerRefs.current[openActionsUserId]?.contains(target)) {
        return;
      }

      closeActionsMenu();
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        closeActionsMenu();
      }
    };

    document.addEventListener("pointerdown", handlePointerDown, true);
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("pointerdown", handlePointerDown, true);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [closeActionsMenu, openActionsUserId]);

  useEffect(() => {
    if (!openActionsUserId) {
      return;
    }

    const handleViewportChange = () => {
      updateActionsMenuPosition(openActionsUserId);
    };

    window.addEventListener("resize", handleViewportChange);
    window.addEventListener("scroll", handleViewportChange, true);

    return () => {
      window.removeEventListener("resize", handleViewportChange);
      window.removeEventListener("scroll", handleViewportChange, true);
    };
  }, [openActionsUserId, updateActionsMenuPosition]);

  return {
    actionsMenuPosition,
    closeActionsMenu,
    handleToggleActionsMenu,
    menuRootRef,
    openActionsUserId,
    triggerRefs,
  };
}
