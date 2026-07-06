"use client";

import Link from "next/link";
import { useEffect, useId, useRef, useState } from "react";

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
  const menuId = useId();
  const copy = getAdminChromeCopy(locale).langDropdown;
  const languageLabel = copy.languageLabel;
  const triggerLabel = copy.triggerLabel;
  const currentLabel = copy.currentLabel;
  const languageOptions = [
    { value: "ru" as const, href: ruPath, label: copy.ruOption },
    { value: "en" as const, href: enPath, label: copy.enOption },
  ];

  useEffect(() => {
    if (!open) {
      return;
    }

    function handlePointerDown(event: MouseEvent) {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        setOpen(false);
      }
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setOpen(false);
      }
    }

    document.addEventListener("mousedown", handlePointerDown);
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("mousedown", handlePointerDown);
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [open]);

  return (
    <div className={styles.localeRoot} ref={ref}>
      <button
        type="button"
        className={styles.localeTrigger}
        onClick={() => setOpen((current) => !current)}
        aria-expanded={open}
        aria-haspopup="listbox"
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
        <ul id={menuId} className={styles.localeMenu} role="listbox" aria-label={languageLabel}>
          {languageOptions.map((option) => {
            const isCurrent = option.value === locale;

            return (
              <li key={option.value} role="option" aria-selected={isCurrent}>
                <Link
                  href={option.href}
                  className={`${styles.localeOption}${isCurrent ? ` ${styles.localeOptionActive}` : ""}`}
                  onClick={() => setOpen(false)}
                >
                  <span>{option.label}</span>
                  {isCurrent ? (
                    <span className={styles.localeCheck} aria-label={currentLabel}>
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
