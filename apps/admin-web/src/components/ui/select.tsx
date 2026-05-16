"use client";

import styles from "@/components/ui/select.module.css";
import { useEffect, useId, useRef, useState } from "react";

export type SelectOption = {
  value: string;
  label: string;
  description?: string;
  badge?: string;
  tone?: "recommended" | "fast" | "premium" | "neutral";
};

type SelectProps = {
  value: string;
  options: readonly SelectOption[];
  onChange: (value: string) => void;
  ariaLabel?: string;
};

export function Select({ value, options, onChange, ariaLabel }: SelectProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [focusedIndex, setFocusedIndex] = useState(0);
  const rootRef = useRef<HTMLDivElement | null>(null);
  const triggerRef = useRef<HTMLButtonElement | null>(null);
  const optionRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const listboxId = useId();
  const selectedOption = options.find((option) => option.value === value) ?? options[0];
  const selectedIndex = Math.max(0, options.findIndex((option) => option.value === selectedOption?.value));

  useEffect(() => {
    function handlePointerDown(event: PointerEvent) {
      if (!rootRef.current?.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }

    function handleEscape(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setIsOpen(false);
      }
    }

    window.addEventListener("pointerdown", handlePointerDown);
    window.addEventListener("keydown", handleEscape);
    return () => {
      window.removeEventListener("pointerdown", handlePointerDown);
      window.removeEventListener("keydown", handleEscape);
    };
  }, []);

  useEffect(() => {
    if (isOpen) {
      optionRefs.current[focusedIndex]?.focus();
    }
  }, [focusedIndex, isOpen]);

  function getBadgeToneClassName(tone?: SelectOption["tone"]) {
    switch (tone) {
      case "recommended":
        return styles.badgeRecommended;
      case "fast":
        return styles.badgeFast;
      case "premium":
        return styles.badgePremium;
      default:
        return styles.badgeNeutral;
    }
  }

  function openMenu(index = selectedIndex) {
    setFocusedIndex(index);
    setIsOpen(true);
  }

  function closeMenu(restoreFocus = false) {
    setIsOpen(false);
    if (restoreFocus) {
      queueMicrotask(() => {
        triggerRef.current?.focus();
      });
    }
  }

  function selectValue(nextValue: string) {
    onChange(nextValue);
    closeMenu(true);
  }

  function moveFocus(nextIndex: number) {
    const boundedIndex = Math.max(0, Math.min(options.length - 1, nextIndex));
    setFocusedIndex(boundedIndex);
  }

  return (
    <div
      ref={rootRef}
      className={styles.root}
      onBlur={(event) => {
        if (!rootRef.current?.contains(event.relatedTarget as Node | null)) {
          setIsOpen(false);
        }
      }}
    >
      <button
        ref={triggerRef}
        type="button"
        className={`${styles.trigger} ${isOpen ? styles.triggerOpen : ""}`.trim()}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        aria-controls={listboxId}
        aria-label={ariaLabel}
        onClick={() => {
          if (isOpen) {
            closeMenu();
            return;
          }

          openMenu();
        }}
        onKeyDown={(event) => {
          switch (event.key) {
            case "ArrowDown":
            case "ArrowUp":
            case "Enter":
            case " ":
              event.preventDefault();
              openMenu();
              break;
            default:
              break;
          }
        }}
      >
        <span className={styles.triggerContent}>
          <span className={styles.triggerTopRow}>
            <span className={styles.value}>{selectedOption?.label ?? value}</span>
            {selectedOption?.badge ? <span className={`${styles.badge} ${getBadgeToneClassName(selectedOption.tone)}`.trim()}>{selectedOption.badge}</span> : null}
          </span>
          {selectedOption?.description ? <span className={styles.triggerDescription}>{selectedOption.description}</span> : null}
        </span>
        <span className={styles.chevron} aria-hidden="true" />
      </button>

      {isOpen ? (
        <div id={listboxId} className={styles.menu} role="listbox" aria-label={ariaLabel}>
          {options.map((option, index) => {
            const isSelected = option.value === value;

            return (
              <button
                ref={(element) => {
                  optionRefs.current[index] = element;
                }}
                key={option.value}
                type="button"
                role="option"
                aria-selected={isSelected}
                tabIndex={focusedIndex === index ? 0 : -1}
                className={`${styles.option} ${isSelected ? styles.optionSelected : ""}`.trim()}
                onMouseEnter={() => setFocusedIndex(index)}
                onClick={() => {
                  selectValue(option.value);
                }}
                onKeyDown={(event) => {
                  switch (event.key) {
                    case "ArrowDown":
                      event.preventDefault();
                      moveFocus(index + 1);
                      break;
                    case "ArrowUp":
                      event.preventDefault();
                      moveFocus(index - 1);
                      break;
                    case "Home":
                      event.preventDefault();
                      moveFocus(0);
                      break;
                    case "End":
                      event.preventDefault();
                      moveFocus(options.length - 1);
                      break;
                    case "Enter":
                    case " ":
                      event.preventDefault();
                      selectValue(option.value);
                      break;
                    case "Escape":
                      event.preventDefault();
                      closeMenu(true);
                      break;
                    case "Tab":
                      closeMenu();
                      break;
                    default:
                      break;
                  }
                }}
              >
                <span className={styles.optionBody}>
                  <span className={styles.optionTopRow}>
                    <span className={styles.optionLabel}>{option.label}</span>
                    <span className={styles.optionMeta}>
                      {option.badge ? <span className={`${styles.badge} ${getBadgeToneClassName(option.tone)}`.trim()}>{option.badge}</span> : null}
                      {isSelected ? <span className={styles.optionIndicator} aria-hidden="true" /> : null}
                    </span>
                  </span>
                  {option.description ? <span className={styles.optionDescription}>{option.description}</span> : null}
                </span>
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}
