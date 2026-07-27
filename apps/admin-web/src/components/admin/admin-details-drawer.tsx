"use client";

import {
  useEffect,
  useId,
  useRef,
  useSyncExternalStore,
  type ReactNode,
  type RefObject,
} from "react";
import { createPortal } from "react-dom";

import styles from "./admin-details-drawer.module.css";

const focusableSelector =
  'a[href], button:not(:disabled), textarea:not(:disabled), input:not(:disabled), select:not(:disabled), [tabindex]:not([tabindex="-1"])';
const subscribeToClientReady = () => () => undefined;
const getClientReadySnapshot = () => true;
const getServerReadySnapshot = () => false;

type AdminDetailsDrawerProps = {
  id?: string;
  open: boolean;
  title: string;
  description?: string;
  closeLabel: string;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
  initialFocusRef?: RefObject<HTMLElement | null>;
};

export function AdminDetailsDrawer({
  id,
  open,
  title,
  description,
  closeLabel,
  onClose,
  children,
  footer,
  initialFocusRef,
}: AdminDetailsDrawerProps) {
  const clientReady = useSyncExternalStore(
    subscribeToClientReady,
    getClientReadySnapshot,
    getServerReadySnapshot
  );
  const generatedTitleId = useId();
  const generatedDescriptionId = useId();
  const drawerRef = useRef<HTMLElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const previouslyFocusedElementRef = useRef<HTMLElement | null>(null);
  const onCloseRef = useRef(onClose);

  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    if (!clientReady || !open) {
      return;
    }

    previouslyFocusedElementRef.current =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const focusFrame = window.requestAnimationFrame(() => {
      initialFocusRef?.current?.focus();
      if (!initialFocusRef?.current) {
        closeButtonRef.current?.focus();
      }
    });

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        onCloseRef.current();
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
      } else if (!event.shiftKey && document.activeElement === lastElement) {
        event.preventDefault();
        firstElement.focus();
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      window.cancelAnimationFrame(focusFrame);
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousOverflow;
      const previouslyFocusedElement = previouslyFocusedElementRef.current;
      if (previouslyFocusedElement?.isConnected) {
        previouslyFocusedElement.focus();
      }
      previouslyFocusedElementRef.current = null;
    };
  }, [clientReady, initialFocusRef, open]);

  if (!clientReady || !open) {
    return null;
  }

  return createPortal(
    <div className={styles.drawerRoot}>
      <button
        type="button"
        className={styles.backdrop}
        onClick={onClose}
        aria-label={closeLabel}
        tabIndex={-1}
      />
      <aside
        id={id}
        ref={drawerRef}
        className={styles.drawer}
        role="dialog"
        aria-modal="true"
        aria-labelledby={generatedTitleId}
        aria-describedby={description ? generatedDescriptionId : undefined}
        tabIndex={-1}
      >
        <header className={styles.header}>
          <div className={styles.heading}>
            <h2 id={generatedTitleId} className={styles.title}>
              {title}
            </h2>
            {description ? (
              <p id={generatedDescriptionId} className={styles.description}>
                {description}
              </p>
            ) : null}
          </div>
          <button
            ref={closeButtonRef}
            type="button"
            className={styles.closeButton}
            onClick={onClose}
            aria-label={closeLabel}
            title={closeLabel}
          >
            <span aria-hidden="true">×</span>
          </button>
        </header>
        <div className={styles.body}>{children}</div>
        {footer ? <footer className={styles.footer}>{footer}</footer> : null}
      </aside>
    </div>,
    document.body
  );
}
