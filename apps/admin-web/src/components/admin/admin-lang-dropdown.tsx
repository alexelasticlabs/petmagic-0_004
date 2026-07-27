"use client";

import Link from "next/link";
import {
  useCallback,
  useEffect,
  useId,
  useRef,
  useState,
  type KeyboardEvent as ReactKeyboardEvent,
} from "react";

import { getAdminChromeCopy } from "@/components/admin/admin-chrome.content";
import { CaretDownIcon, CheckIcon, GlobeIcon } from "@/components/admin/admin-icons";
import styles from "@/components/admin/admin-shell.module.css";
import { type Locale } from "@/lib/i18n";

type AdminLangDropdownProps = {
  locale: Locale;
  ruPath: string;
  enPath: string;
};

export function AdminLangDropdown({ locale, ruPath, enPath }: AdminLangDropdownProps) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement | null>(null);
  const triggerRef = useRef<HTMLButtonElement | null>(null);
  const optionRefs = useRef<Array<HTMLAnchorElement | null>>([]);
  const pendingFocusIndexRef = useRef(0);
  const menuId = useId();
  const copy = getAdminChromeCopy(locale).langDropdown;
  const languageLabel = copy.languageLabel;
  const triggerLabel = copy.triggerLabel;
  const currentLabel = copy.currentLabel;
  const languageOptions = [
    { value: "ru" as const, href: ruPath, label: copy.ruOption },
    { value: "en" as const, href: enPath, label: copy.enOption },
  ];
  const currentOptionIndex = Math.max(
    0,
    languageOptions.findIndex((option) => option.value === locale)
  );

  const focusOption = useCallback((index: number) => {
    const optionCount = optionRefs.current.length;
    if (optionCount === 0) {
      return;
    }

    const normalizedIndex = (index + optionCount) % optionCount;
    pendingFocusIndexRef.current = normalizedIndex;
    optionRefs.current[normalizedIndex]?.focus();
  }, []);

  const openMenu = useCallback((focusIndex: number) => {
    pendingFocusIndexRef.current = focusIndex;
    setOpen(true);
  }, []);

  const closeMenu = useCallback((restoreFocus = false) => {
    setOpen(false);

    if (restoreFocus && typeof window !== "undefined") {
      window.requestAnimationFrame(() => triggerRef.current?.focus());
    }
  }, []);

  useEffect(() => {
    if (!open) {
      return;
    }

    function handlePointerDown(event: MouseEvent) {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        closeMenu();
      }
    }

    function handleFocusIn(event: FocusEvent) {
      if (ref.current && event.target instanceof Node && !ref.current.contains(event.target)) {
        closeMenu();
      }
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        closeMenu(true);
      }
    }

    const focusFrame = window.requestAnimationFrame(() => {
      focusOption(pendingFocusIndexRef.current);
    });
    document.addEventListener("mousedown", handlePointerDown);
    document.addEventListener("focusin", handleFocusIn);
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.cancelAnimationFrame(focusFrame);
      document.removeEventListener("mousedown", handlePointerDown);
      document.removeEventListener("focusin", handleFocusIn);
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [closeMenu, focusOption, open]);

  function handleTriggerKeyDown(event: ReactKeyboardEvent<HTMLButtonElement>) {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      openMenu(0);
      return;
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      openMenu(languageOptions.length - 1);
    }
  }

  function handleMenuKeyDown(event: ReactKeyboardEvent<HTMLUListElement>) {
    const focusedIndex = optionRefs.current.findIndex(
      (option) => option === document.activeElement
    );

    if (event.key === "ArrowDown") {
      event.preventDefault();
      focusOption(focusedIndex >= 0 ? focusedIndex + 1 : 0);
      return;
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      focusOption(focusedIndex >= 0 ? focusedIndex - 1 : languageOptions.length - 1);
      return;
    }

    if (event.key === "Home") {
      event.preventDefault();
      focusOption(0);
      return;
    }

    if (event.key === "End") {
      event.preventDefault();
      focusOption(languageOptions.length - 1);
      return;
    }

    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      closeMenu(true);
      return;
    }

    if (event.key === " " && focusedIndex >= 0) {
      event.preventDefault();
      optionRefs.current[focusedIndex]?.click();
    }
  }

  return (
    <div className={styles.localeRoot} ref={ref}>
      <button
        ref={triggerRef}
        type="button"
        className={styles.localeTrigger}
        onClick={() => {
          if (open) {
            closeMenu();
            return;
          }

          openMenu(currentOptionIndex);
        }}
        onKeyDown={handleTriggerKeyDown}
        aria-expanded={open}
        aria-haspopup="menu"
        aria-controls={open ? menuId : undefined}
        aria-label={triggerLabel}
        title={triggerLabel}
      >
        <GlobeIcon className={styles.localeIcon} />
        <span>
          {languageOptions.find((option) => option.value === locale)?.label ??
            copy.currentLanguageName}
        </span>
        <CaretDownIcon className={styles.localeIcon} />
      </button>

      {open ? (
        <ul
          id={menuId}
          className={styles.localeMenu}
          role="menu"
          aria-label={languageLabel}
          onKeyDown={handleMenuKeyDown}
        >
          {languageOptions.map((option, index) => {
            const isCurrent = option.value === locale;

            return (
              <li key={option.value} role="none">
                <Link
                  ref={(element) => {
                    optionRefs.current[index] = element;
                  }}
                  href={option.href}
                  role="menuitemradio"
                  aria-checked={isCurrent}
                  aria-label={isCurrent ? `${option.label}, ${currentLabel}` : option.label}
                  tabIndex={-1}
                  className={`${styles.localeOption}${isCurrent ? ` ${styles.localeOptionActive}` : ""}`}
                  onClick={() => closeMenu()}
                >
                  <span>{option.label}</span>
                  {isCurrent ? (
                    <span className={styles.localeCheck} aria-hidden="true">
                      <CheckIcon />
                    </span>
                  ) : null}
                </Link>
              </li>
            );
          })}
        </ul>
      ) : null}
    </div>
  );
}
