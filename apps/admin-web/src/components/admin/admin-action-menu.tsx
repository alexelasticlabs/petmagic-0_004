"use client";

import Link from "next/link";
import { useEffect, useId, useRef, useState, type KeyboardEvent } from "react";

import { Button } from "@/components/ui/button";

import styles from "./admin-action-menu.module.css";

type AdminActionMenuItemBase = {
  id: string;
  label: string;
  description?: string;
  disabled?: boolean;
  tone?: "default" | "danger";
};

export type AdminActionMenuItem = AdminActionMenuItemBase &
  ({ href: string; onSelect?: never } | { href?: never; onSelect: () => void });

type AdminActionMenuProps = {
  label: string;
  items: readonly AdminActionMenuItem[];
  align?: "start" | "end";
  disabled?: boolean;
  className?: string;
};

export function AdminActionMenu({
  label,
  items,
  align = "end",
  disabled = false,
  className,
}: AdminActionMenuProps) {
  const [open, setOpen] = useState(false);
  const menuId = useId();
  const rootRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!open) {
      return;
    }

    const focusFrame = window.requestAnimationFrame(() => {
      rootRef.current
        ?.querySelector<HTMLElement>('[role="menuitem"]:not([aria-disabled="true"])')
        ?.focus();
    });

    function handlePointerDown(event: PointerEvent) {
      if (event.target instanceof Node && !rootRef.current?.contains(event.target)) {
        setOpen(false);
      }
    }

    function handleDocumentKeyDown(event: globalThis.KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        setOpen(false);
        triggerRef.current?.focus();
      } else if (event.key === "Tab") {
        setOpen(false);
      }
    }

    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("keydown", handleDocumentKeyDown);
    return () => {
      window.cancelAnimationFrame(focusFrame);
      document.removeEventListener("pointerdown", handlePointerDown);
      document.removeEventListener("keydown", handleDocumentKeyDown);
    };
  }, [open]);

  function handleMenuKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) {
      return;
    }

    const enabledItems = Array.from(
      event.currentTarget.querySelectorAll<HTMLElement>(
        '[role="menuitem"]:not([aria-disabled="true"])'
      )
    );
    if (enabledItems.length === 0) {
      return;
    }

    event.preventDefault();
    const currentIndex = enabledItems.findIndex((item) => item === document.activeElement);
    let nextIndex = currentIndex;
    if (event.key === "Home") {
      nextIndex = 0;
    } else if (event.key === "End") {
      nextIndex = enabledItems.length - 1;
    } else if (event.key === "ArrowDown") {
      nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % enabledItems.length;
    } else {
      nextIndex = currentIndex <= 0 ? enabledItems.length - 1 : currentIndex - 1;
    }
    enabledItems[nextIndex]?.focus();
  }

  function renderMenuItem(item: AdminActionMenuItem) {
    const itemClassName = `${styles.menuItem} ${
      item.tone === "danger" ? styles.menuItemDanger : ""
    }`.trim();
    const content = (
      <>
        <span className={styles.menuItemLabel}>{item.label}</span>
        {item.description ? (
          <span className={styles.menuItemDescription}>{item.description}</span>
        ) : null}
      </>
    );

    if (item.disabled) {
      return (
        <span
          key={item.id}
          className={itemClassName}
          role="menuitem"
          aria-disabled="true"
          tabIndex={-1}
        >
          {content}
        </span>
      );
    }

    if (item.href) {
      return (
        <Link
          key={item.id}
          href={item.href}
          className={itemClassName}
          role="menuitem"
          tabIndex={-1}
          onClick={() => setOpen(false)}
        >
          {content}
        </Link>
      );
    }

    return (
      <button
        key={item.id}
        type="button"
        className={itemClassName}
        role="menuitem"
        tabIndex={-1}
        onClick={() => {
          setOpen(false);
          item.onSelect?.();
        }}
      >
        {content}
      </button>
    );
  }

  const rootClassName = className ? `${styles.root} ${className}` : styles.root;

  return (
    <div ref={rootRef} className={rootClassName}>
      <Button
        ref={triggerRef}
        variant="ghost"
        size="sm"
        className={styles.trigger}
        disabled={disabled || items.length === 0}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        onClick={() => setOpen((current) => !current)}
      >
        <span>{label}</span>
        <span className={styles.triggerGlyph} aria-hidden="true">
          ···
        </span>
      </Button>
      {open ? (
        <div
          id={menuId}
          className={styles.menu}
          data-align={align}
          role="menu"
          aria-label={label}
          onKeyDown={handleMenuKeyDown}
        >
          {items.map((item) => renderMenuItem(item))}
        </div>
      ) : null}
    </div>
  );
}
