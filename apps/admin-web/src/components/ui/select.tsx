"use client";

import { useEffect, useId, useRef, useState } from "react";

import styles from "@/components/ui/select.module.css";

export type SelectOption = {
  value: string;
  label: string;
  description?: string;
  badge?: string;
  tone?: "recommended" | "fast" | "premium" | "neutral";
  price?: string;
};

type SelectProps = {
  value: string;
  options: readonly SelectOption[];
  onChange: (value: string) => void;
  ariaLabel?: string;
  showSelectedDescription?: boolean;
  menuMode?: "overlay" | "inline";
  disabled?: boolean;
};

export function Select({
  value,
  options,
  onChange,
  ariaLabel,
  showSelectedDescription = true,
  menuMode = "overlay",
  disabled = false,
}: SelectProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [focusedIndex, setFocusedIndex] = useState(0);
  const rootRef = useRef<HTMLDivElement | null>(null);
  const triggerRef = useRef<HTMLButtonElement | null>(null);
  const optionRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const listboxId = useId();
  const hasOptions = options.length > 0;
  const isSelectDisabled = disabled || !hasOptions;
  const selectedOption = options.find((option) => option.value === value) ?? options[0];
  const effectiveAriaLabel = ariaLabel ?? selectedOption?.label ?? "Select";
  const selectedIndex = Math.max(
    0,
    options.findIndex((option) => option.value === selectedOption?.value)
  );
  const isMenuOpen = isOpen && !isSelectDisabled;

  useEffect(() => {
    if (!isSelectDisabled) {
      return;
    }

    let isCurrent = true;
    queueMicrotask(() => {
      if (!isCurrent) {
        return;
      }

      setIsOpen(false);
    });

    return () => {
      isCurrent = false;
    };
  }, [isSelectDisabled]);

  useEffect(() => {
    if (!isMenuOpen) {
      return;
    }

    function handlePointerDown(event: PointerEvent) {
      if (!rootRef.current?.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }

    function handleEscape(event: KeyboardEvent) {
      if (event.key === "Escape") {
        closeMenu(true);
      }
    }

    window.addEventListener("pointerdown", handlePointerDown);
    window.addEventListener("keydown", handleEscape);
    return () => {
      window.removeEventListener("pointerdown", handlePointerDown);
      window.removeEventListener("keydown", handleEscape);
    };
  }, [isMenuOpen]);

  useEffect(() => {
    if (isMenuOpen) {
      optionRefs.current[focusedIndex]?.focus();
    }
  }, [focusedIndex, isMenuOpen]);

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
    if (isSelectDisabled) {
      return;
    }

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
    if (isSelectDisabled) {
      return;
    }

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
      className={`${styles.root} ${isMenuOpen ? styles.rootOpen : ""}`.trim()}
      onBlur={(event) => {
        if (!rootRef.current?.contains(event.relatedTarget as Node | null)) {
          setIsOpen(false);
        }
      }}
    >
      <button
        ref={triggerRef}
        type="button"
        className={`${styles.trigger} ${isMenuOpen ? styles.triggerOpen : ""}`.trim()}
        aria-haspopup="listbox"
        aria-expanded={isMenuOpen}
        aria-controls={isMenuOpen ? listboxId : undefined}
        aria-label={effectiveAriaLabel}
        title={effectiveAriaLabel}
        disabled={isSelectDisabled}
        onClick={() => {
          if (isSelectDisabled) {
            return;
          }

          if (isMenuOpen) {
            closeMenu();
            return;
          }

          openMenu();
        }}
        onKeyDown={(event) => {
          if (isSelectDisabled) {
            return;
          }

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
            <span className={styles.triggerMeta}>
              {selectedOption?.price ? (
                <span className={styles.triggerPrice}>{selectedOption.price}</span>
              ) : null}
              {selectedOption?.badge ? (
                <span
                  className={`${styles.badge} ${getBadgeToneClassName(selectedOption.tone)}`.trim()}
                >
                  {selectedOption.badge}
                </span>
              ) : null}
            </span>
          </span>
          {showSelectedDescription && selectedOption?.description ? (
            <span className={styles.triggerDescription}>{selectedOption.description}</span>
          ) : null}
        </span>
        <span className={styles.chevron} aria-hidden="true" />
      </button>

      {isMenuOpen ? (
        <div
          id={listboxId}
          className={`${styles.menu} ${menuMode === "inline" ? styles.menuInline : ""}`.trim()}
          role="listbox"
          aria-label={effectiveAriaLabel}
        >
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
                      {option.price ? (
                        <span className={styles.optionPrice}>{option.price}</span>
                      ) : null}
                      {option.badge ? (
                        <span
                          className={`${styles.badge} ${getBadgeToneClassName(option.tone)}`.trim()}
                        >
                          {option.badge}
                        </span>
                      ) : null}
                      {isSelected ? (
                        <span className={styles.optionIndicator} aria-hidden="true" />
                      ) : null}
                    </span>
                  </span>
                  {option.description ? (
                    <span className={styles.optionDescription}>{option.description}</span>
                  ) : null}
                </span>
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}
