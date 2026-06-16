"use client";

import Link from "next/link";
import { useEffect, useId, useRef, useState } from "react";

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
  const languageLabel = locale === "ru" ? "Язык интерфейса" : "Interface language";
  const triggerLabel =
    locale === "ru" ? "Выбрать язык интерфейса" : "Choose interface language";
  const currentLabel = locale === "ru" ? "Текущий язык" : "Current language";

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
        <span>{locale === "ru" ? "Русский" : "English"}</span>
        <CaretDownIcon className={styles.localeIcon} />
      </button>

      {open ? (
        <ul id={menuId} className={styles.localeMenu} role="listbox" aria-label={languageLabel}>
          <li role="option" aria-selected={locale === "ru"}>
            <Link
              href={ruPath}
              className={`${styles.localeOption}${locale === "ru" ? ` ${styles.localeOptionActive}` : ""}`}
              onClick={() => setOpen(false)}
            >
              <span>Русский</span>
              {locale === "ru" ? (
                <span className={styles.localeCheck} aria-label={currentLabel}>
                  <CheckIcon />
                </span>
              ) : null}
            </Link>
          </li>
          <li role="option" aria-selected={locale === "en"}>
            <Link
              href={enPath}
              className={`${styles.localeOption}${locale === "en" ? ` ${styles.localeOptionActive}` : ""}`}
              onClick={() => setOpen(false)}
            >
              <span>English</span>
              {locale === "en" ? (
                <span className={styles.localeCheck} aria-label={currentLabel}>
                  <CheckIcon />
                </span>
              ) : null}
            </Link>
          </li>
        </ul>
      ) : null}
    </div>
  );
}
