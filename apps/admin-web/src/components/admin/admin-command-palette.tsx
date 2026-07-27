"use client";

import { useQuery } from "@tanstack/react-query";
import { usePathname, useRouter } from "next/navigation";
import {
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent as ReactKeyboardEvent,
} from "react";
import { createPortal } from "react-dom";

import { getAdminChromeCopy } from "@/components/admin/admin-chrome.content";
import {
  ADMIN_COMMAND_USER_RESULT_LIMIT,
  ADMIN_COMMAND_USER_SEARCH_DEBOUNCE_MS,
  ADMIN_COMMAND_USER_SEARCH_MIN_LENGTH,
  buildAdminCommandPaletteResults,
  canSearchAdminCommandUsers,
  getAdminCommandPaletteOptionId,
  getNextAdminCommandPaletteIndex,
  normalizeAdminCommandUserSearch,
  type AdminCommandPaletteResult,
} from "@/components/admin/admin-command-palette.helpers";
import styles from "@/components/admin/admin-command-palette.module.css";
import { CaretDownIcon, SearchIcon } from "@/components/admin/admin-icons";
import {
  filterAdminCommandItems,
  getAdminCommandItems,
  matchesAdminPath,
} from "@/lib/admin-navigation";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchUsers } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

type AdminCommandPaletteProps = {
  locale: Locale;
  roles: readonly string[];
  onClose: () => void;
};

function useDebouncedValue(value: string, delayMs: number) {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebouncedValue(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debouncedValue;
}

export function AdminCommandPalette({ locale, roles, onClose }: AdminCommandPaletteProps) {
  const router = useRouter();
  const pathname = usePathname();
  const copy = useMemo(() => getAdminChromeCopy(locale).commandPalette, [locale]);
  const items = useMemo(() => getAdminCommandItems(locale, roles), [locale, roles]);
  const [query, setQuery] = useState("");
  const filteredItems = useMemo(() => filterAdminCommandItems(items, query), [items, query]);
  const [activeIndex, setActiveIndex] = useState(0);
  const canSearchUsers = roles.includes("Admin");
  const normalizedUserQuery = normalizeAdminCommandUserSearch(query);
  const debouncedUserQuery = useDebouncedValue(
    normalizedUserQuery,
    ADMIN_COMMAND_USER_SEARCH_DEBOUNCE_MS
  );
  const isUserSearchActive = canSearchAdminCommandUsers(roles, normalizedUserQuery);
  const isUserSearchPending = isUserSearchActive && normalizedUserQuery !== debouncedUserQuery;
  const isUserSearchQueryEnabled = isUserSearchActive && !isUserSearchPending;
  const userSearchQueryParams = useMemo(
    () => ({
      search: debouncedUserQuery,
      skip: 0,
      take: ADMIN_COMMAND_USER_RESULT_LIMIT,
    }),
    [debouncedUserQuery]
  );
  const userSearchQuery = useQuery({
    queryKey: adminQueryKeys.commandUsers(debouncedUserQuery),
    queryFn: ({ signal }) => fetchUsers(userSearchQueryParams, signal),
    enabled: canSearchUsers && isUserSearchQueryEnabled,
    staleTime: 30_000,
    retry: 1,
  });
  const paletteResults = useMemo(
    () =>
      buildAdminCommandPaletteResults(
        filteredItems,
        isUserSearchQueryEnabled ? (userSearchQuery.data?.items ?? []) : [],
        locale
      ),
    [filteredItems, isUserSearchQueryEnabled, locale, userSearchQuery.data?.items]
  );
  const navigationResults = paletteResults.slice(0, filteredItems.length);
  const userResults = paletteResults.slice(filteredItems.length);
  const effectiveActiveIndex =
    activeIndex >= 0 && activeIndex < paletteResults.length ? activeIndex : 0;
  const activeResult = paletteResults[effectiveActiveIndex];
  const isUserSearchLoading =
    isUserSearchActive &&
    (isUserSearchPending ||
      (isUserSearchQueryEnabled &&
        (userSearchQuery.isPending || (userSearchQuery.isFetching && !userSearchQuery.data))));
  const isUserSearchError =
    isUserSearchActive && !isUserSearchPending && !isUserSearchLoading && userSearchQuery.isError;
  const isUserSearchEmpty =
    isUserSearchActive &&
    !isUserSearchPending &&
    userSearchQuery.isSuccess &&
    userResults.length === 0;
  const isUserQueryTooShort =
    canSearchUsers &&
    normalizedUserQuery.length > 0 &&
    normalizedUserQuery.length < ADMIN_COMMAND_USER_SEARCH_MIN_LENGTH;
  const isUserSearchBusy =
    isUserSearchLoading || (isUserSearchQueryEnabled && userSearchQuery.isFetching);
  const searchLabel = canSearchUsers ? copy.userSearchLabel : copy.searchLabel;
  const searchPlaceholder = canSearchUsers ? copy.userSearchPlaceholder : copy.searchPlaceholder;
  const dialogRef = useRef<HTMLElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const previouslyFocusedElementRef = useRef<HTMLElement | null>(null);
  const titleId = useId();
  const resultsId = useId();
  const resultsLabelId = useId();
  const sectionsLabelId = useId();
  const usersLabelId = useId();
  const hintId = useId();
  const activeResultKey = activeResult?.key;
  const activeOptionId = activeResultKey
    ? getAdminCommandPaletteOptionId(resultsId, activeResultKey)
    : undefined;

  useEffect(() => {
    previouslyFocusedElementRef.current =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    searchInputRef.current?.focus();

    return () => {
      document.body.style.overflow = previousOverflow;
      previouslyFocusedElementRef.current?.focus();
      previouslyFocusedElementRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (!activeOptionId) {
      return;
    }

    document.getElementById(activeOptionId)?.scrollIntoView({ block: "nearest" });
  }, [activeOptionId, activeResultKey]);

  useEffect(() => {
    function handleDialogKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        onClose();
        return;
      }

      if (event.key !== "Tab") {
        return;
      }

      const focusableElements = dialogRef.current?.querySelectorAll<HTMLElement>(
        'button:not(:disabled):not([tabindex="-1"]), input:not(:disabled), [tabindex]:not([tabindex="-1"])'
      );
      if (!focusableElements || focusableElements.length === 0) {
        event.preventDefault();
        dialogRef.current?.focus();
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

    document.addEventListener("keydown", handleDialogKeyDown);
    return () => document.removeEventListener("keydown", handleDialogKeyDown);
  }, [onClose]);

  function navigateToResult(result: AdminCommandPaletteResult) {
    router.push(result.href);
    onClose();
  }

  function handleSearchKeyDown(event: ReactKeyboardEvent<HTMLInputElement>) {
    if (event.nativeEvent.isComposing) {
      return;
    }

    if (event.key === "ArrowDown" && paletteResults.length > 0) {
      event.preventDefault();
      setActiveIndex((current) =>
        getNextAdminCommandPaletteIndex(current, 1, paletteResults.length)
      );
      return;
    }

    if (event.key === "ArrowUp" && paletteResults.length > 0) {
      event.preventDefault();
      setActiveIndex((current) =>
        getNextAdminCommandPaletteIndex(current, -1, paletteResults.length)
      );
      return;
    }

    if (event.key === "Enter" && activeResult) {
      event.preventDefault();
      navigateToResult(activeResult);
    }
  }

  function renderResult(result: AdminCommandPaletteResult, index: number) {
    const isActive = index === effectiveActiveIndex;
    const isCurrent = matchesAdminPath(pathname, result.href);

    return (
      <button
        key={result.key}
        id={getAdminCommandPaletteOptionId(resultsId, result.key)}
        type="button"
        className={`${styles.resultItem} ${isActive ? styles.resultItemActive : ""}`}
        role="option"
        aria-selected={isActive}
        tabIndex={-1}
        onMouseEnter={() => setActiveIndex(index)}
        onClick={() => navigateToResult(result)}
      >
        <span className={styles.resultLead}>
          <span className={styles.resultLabel}>{result.label}</span>
          {result.secondaryLabel ? (
            <span className={styles.resultGroup}>{result.secondaryLabel}</span>
          ) : null}
        </span>
        <span className={styles.resultMeta}>
          {isCurrent ? <span className={styles.currentPill}>{copy.currentPage}</span> : null}
          <CaretDownIcon className={styles.resultArrow} />
        </span>
      </button>
    );
  }

  return createPortal(
    <div className={styles.backdrop} onMouseDown={onClose}>
      <section
        ref={dialogRef}
        className={styles.dialog}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={hintId}
        tabIndex={-1}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <div className={styles.header}>
          <div className={styles.heading}>
            <span className={styles.eyebrow}>PetMagic Admin</span>
            <h2 id={titleId}>{copy.dialogTitle}</h2>
          </div>
          <button type="button" className={styles.closeButton} onClick={onClose}>
            {copy.closeLabel}
            <kbd>Esc</kbd>
          </button>
        </div>

        <label className={styles.searchField}>
          <span className={styles.searchLabel}>{searchLabel}</span>
          <span className={styles.searchControl}>
            <SearchIcon className={styles.searchIcon} />
            <input
              ref={searchInputRef}
              value={query}
              placeholder={searchPlaceholder}
              autoComplete="off"
              spellCheck={false}
              role="combobox"
              aria-label={searchLabel}
              aria-autocomplete="list"
              aria-haspopup="listbox"
              aria-expanded={true}
              aria-controls={resultsId}
              aria-activedescendant={activeOptionId}
              onChange={(event) => {
                setQuery(event.target.value);
                setActiveIndex(0);
              }}
              onKeyDown={handleSearchKeyDown}
            />
            <kbd>Ctrl K</kbd>
          </span>
        </label>

        <div className={styles.resultsHeader}>
          <span id={resultsLabelId}>{copy.resultsLabel}</span>
          <span>{paletteResults.length}</span>
        </div>

        <div className={styles.resultsViewport}>
          <div
            id={resultsId}
            className={styles.results}
            role="listbox"
            aria-labelledby={resultsLabelId}
            aria-busy={isUserSearchBusy}
          >
            {navigationResults.length > 0 ? (
              <div className={styles.resultSection} role="group" aria-labelledby={sectionsLabelId}>
                <div id={sectionsLabelId} className={styles.sectionLabel}>
                  {copy.sectionsLabel}
                </div>
                {navigationResults.map((result, index) => renderResult(result, index))}
              </div>
            ) : null}

            {userResults.length > 0 ? (
              <div className={styles.resultSection} role="group" aria-labelledby={usersLabelId}>
                <div id={usersLabelId} className={styles.sectionLabel}>
                  {copy.usersLabel}
                </div>
                {userResults.map((result, index) =>
                  renderResult(result, navigationResults.length + index)
                )}
              </div>
            ) : null}
          </div>

          {isUserQueryTooShort ? (
            <div className={styles.userSearchState} role="status">
              <strong>{copy.usersLabel}</strong>
              <p>{copy.userSearchMinimum}</p>
            </div>
          ) : isUserSearchLoading ? (
            <div className={styles.userSearchState} role="status">
              <span className={styles.loadingIndicator} aria-hidden="true" />
              <strong>{copy.usersLoading}</strong>
              <p>{copy.usersLoadingMessage}</p>
            </div>
          ) : isUserSearchError ? (
            <div
              className={`${styles.userSearchState} ${styles.userSearchStateError}`}
              role="alert"
            >
              <strong>{copy.usersErrorTitle}</strong>
              <p>{copy.usersErrorMessage}</p>
              <button
                type="button"
                className={styles.retryButton}
                disabled={userSearchQuery.isFetching}
                onClick={() => void userSearchQuery.refetch()}
              >
                {copy.retryLabel}
              </button>
            </div>
          ) : isUserSearchEmpty ? (
            <div className={styles.userSearchState} role="status">
              <strong>{copy.usersEmptyTitle}</strong>
              <p>{copy.usersEmptyMessage}</p>
            </div>
          ) : null}

          {navigationResults.length === 0 &&
          (!canSearchUsers || normalizedUserQuery.length === 0) ? (
            <div className={styles.emptyState} role="status">
              <strong>{copy.emptyTitle}</strong>
              <p>{copy.emptyMessage}</p>
            </div>
          ) : null}
        </div>

        <p id={hintId} className={styles.hint}>
          {copy.navigateHint}
        </p>
      </section>
    </div>,
    document.body
  );
}
