"use client";

import { useEffect, useId, useRef, type ReactNode } from "react";

import { Button } from "@/components/ui/button";

import styles from "./support-conversation-details-drawer.module.css";

type SupportConversationDetailsDrawerProps = {
  drawerId: string;
  isDrawerMode: boolean;
  isOpen: boolean;
  title: string;
  closeLabel: string;
  onClose: () => void;
  children: ReactNode;
};

const focusableSelector =
  'a[href], button:not(:disabled), textarea:not(:disabled), input:not(:disabled), select:not(:disabled), [tabindex]:not([tabindex="-1"])';

export function SupportConversationDetailsDrawer({
  drawerId,
  isDrawerMode,
  isOpen,
  title,
  closeLabel,
  onClose,
  children,
}: SupportConversationDetailsDrawerProps) {
  const titleId = useId();
  const drawerRef = useRef<HTMLElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const previouslyFocusedElementRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!isDrawerMode || !isOpen || typeof document === "undefined") {
      return;
    }

    previouslyFocusedElementRef.current =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();

    return () => {
      document.body.style.overflow = previousOverflow;
      previouslyFocusedElementRef.current?.focus();
      previouslyFocusedElementRef.current = null;
    };
  }, [isDrawerMode, isOpen]);

  useEffect(() => {
    if (!isDrawerMode || !isOpen) {
      return;
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        onClose();
        return;
      }

      if (event.key !== "Tab") {
        return;
      }

      const focusableElements = drawerRef.current?.querySelectorAll<HTMLElement>(focusableSelector);
      if (!focusableElements || focusableElements.length === 0) {
        event.preventDefault();
        drawerRef.current?.focus();
        return;
      }

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];
      if (event.shiftKey && document.activeElement === firstElement) {
        event.preventDefault();
        lastElement.focus();
        return;
      }

      if (!event.shiftKey && document.activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [isDrawerMode, isOpen, onClose]);

  const isDialogOpen = isDrawerMode && isOpen;

  return (
    <div
      className={`${styles.detailsSlot} ${isDialogOpen ? styles.detailsSlotDrawerOpen : ""}`}
      aria-hidden={isDrawerMode && !isOpen ? "true" : undefined}
    >
      {isDialogOpen ? (
        <button
          type="button"
          className={styles.detailsBackdrop}
          onClick={onClose}
          tabIndex={-1}
          aria-label={closeLabel}
          data-testid="support-details-backdrop"
        />
      ) : null}
      <aside
        id={drawerId}
        ref={drawerRef}
        className={styles.detailsPanel}
        data-testid="support-details-drawer"
        role={isDialogOpen ? "dialog" : undefined}
        aria-label={isDrawerMode ? undefined : title}
        aria-labelledby={isDialogOpen ? titleId : undefined}
        aria-modal={isDialogOpen ? true : undefined}
        tabIndex={isDialogOpen ? -1 : undefined}
        onClick={(event) => event.stopPropagation()}
      >
        {isDrawerMode ? (
          <header className={styles.drawerHeader}>
            <strong id={titleId}>{title}</strong>
            <Button ref={closeButtonRef} variant="ghost" size="sm" onClick={onClose}>
              {closeLabel}
            </Button>
          </header>
        ) : null}
        {children}
      </aside>
    </div>
  );
}
