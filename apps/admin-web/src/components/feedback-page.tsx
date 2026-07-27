"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { CancelCircleIcon, CaretDownIcon } from "@/components/admin/admin-icons";
import { AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/feedback-page.module.css";
import {
  DetailsPanel,
  FeedbackQueue,
  FeedbackSelectField,
  FeedbackTextField,
  priorityOptions,
  statusOptions,
  typeOptions,
} from "@/components/feedback-page.sections";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  ADMIN_FEEDBACK_CATEGORY_FILTER_MAX_LENGTH,
  ADMIN_FEEDBACK_LOOKUP_ID_MAX_LENGTH,
  ADMIN_FEEDBACK_PLATFORM_FILTER_MAX_LENGTH,
  fetchAdminFeedback,
  fetchAdminFeedbackDetails,
  isAdminFeedbackLookupId,
  normalizeAdminFeedbackQuery,
  useAuthSession,
  type FeedbackPriority,
  type FeedbackStatus,
  type FeedbackType,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

import { getFeedbackPageText } from "./feedback-page.content";

type FeedbackPageProps = {
  locale: Locale;
};

type LookupField = "userId" | "templateId" | "generationId";
type FeedbackToast = { message: string; type: "success" | "error" };
type ActiveFilterId =
  "status" | "priority" | "type" | "lookup" | "category" | "platform" | "fromUtc" | "toUtc";
type ActiveFilter = { id: ActiveFilterId; label: string };
type RelatedFeedbackAction = {
  id: "user" | "generation" | "template";
  label: string;
  onClick: () => void;
};

const PAGE_SIZE = 25;

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

function dateInputToUtcStart(value: string): string | undefined {
  if (!value) {
    return undefined;
  }

  const localBoundary = new Date(`${value}T00:00:00.000`);
  return Number.isNaN(localBoundary.valueOf()) ? undefined : localBoundary.toISOString();
}

function dateInputToUtcEnd(value: string): string | undefined {
  if (!value) {
    return undefined;
  }

  const localBoundary = new Date(`${value}T23:59:59.999`);
  return Number.isNaN(localBoundary.valueOf()) ? undefined : localBoundary.toISOString();
}

export function FeedbackPage({ locale }: FeedbackPageProps) {
  const text = getFeedbackPageText(locale);
  const router = useRouter();
  const session = useAuthSession();
  const canView =
    session?.user.roles.some((role) => role === "Admin" || role === "Moderator") ?? false;
  const canViewUserProfile = session?.user.roles.includes("Admin") ?? false;
  const [status, setStatus] = useState<FeedbackStatus | "All">("All");
  const [priority, setPriority] = useState<FeedbackPriority | "All">("All");
  const [type, setType] = useState<FeedbackType | "All">("All");
  const [category, setCategory] = useState("");
  const [platform, setPlatform] = useState("");
  const [lookupField, setLookupField] = useState<LookupField>("userId");
  const [lookupValue, setLookupValue] = useState("");
  const [fromUtc, setFromUtc] = useState("");
  const [toUtc, setToUtc] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const [areAdvancedFiltersOpen, setAreAdvancedFiltersOpen] = useState(false);
  const [toast, setToast] = useState<FeedbackToast | null>(null);
  const [hasUnsavedDetailsChanges, setHasUnsavedDetailsChanges] = useState(false);
  const [pendingDiscardAction, setPendingDiscardAction] = useState<(() => void) | null>(null);
  const inspectorRef = useRef<HTMLDivElement>(null);
  const lastMobileSelectionRef = useRef<string | null>(null);
  const debouncedCategory = useDebouncedValue(category, 350);
  const debouncedPlatform = useDebouncedValue(platform, 350);
  const debouncedLookupValue = useDebouncedValue(lookupValue, 350);
  const isDateRangeInvalid = Boolean(fromUtc && toUtc && fromUtc > toUtc);
  const isLookupValueInvalid = Boolean(lookupValue.trim()) && !isAdminFeedbackLookupId(lookupValue);
  const filterValidationMessage = isDateRangeInvalid
    ? text.invalidDateRange
    : isLookupValueInvalid
      ? text.invalidLookupValue
      : null;
  const lookupValidationId = "feedback-lookup-validation";
  const dateRangeValidationId = "feedback-date-range-validation";

  useEffect(() => {
    ensureAdminSession(locale, router);
  }, [locale, router, session]);

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timeoutId = window.setTimeout(() => setToast(null), 4_000);
    return () => window.clearTimeout(timeoutId);
  }, [toast]);

  useEffect(() => {
    if (!hasUnsavedDetailsChanges || typeof window === "undefined") {
      return;
    }

    const handleBeforeUnload = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = "";
    };

    window.addEventListener("beforeunload", handleBeforeUnload);
    return () => window.removeEventListener("beforeunload", handleBeforeUnload);
  }, [hasUnsavedDetailsChanges]);

  const query = useMemo(
    () =>
      normalizeAdminFeedbackQuery({
        status,
        priority,
        type,
        category: debouncedCategory,
        platform: debouncedPlatform,
        userId: lookupField === "userId" ? debouncedLookupValue : undefined,
        templateId: lookupField === "templateId" ? debouncedLookupValue : undefined,
        generationId: lookupField === "generationId" ? debouncedLookupValue : undefined,
        fromUtc: dateInputToUtcStart(fromUtc),
        toUtc: dateInputToUtcEnd(toUtc),
        skip: page * PAGE_SIZE,
        take: PAGE_SIZE,
      }),
    [
      debouncedCategory,
      debouncedLookupValue,
      debouncedPlatform,
      fromUtc,
      lookupField,
      page,
      priority,
      status,
      toUtc,
      type,
    ]
  );
  const feedbackQuery = useQuery({
    queryKey: adminQueryKeys.feedback(query),
    queryFn: ({ signal }) => fetchAdminFeedback(query, signal),
    enabled: canView && !filterValidationMessage,
    placeholderData: keepPreviousData,
  });
  const detailsQuery = useQuery({
    queryKey: selectedId
      ? adminQueryKeys.feedbackDetails(selectedId)
      : ["admin", "feedback", "none"],
    queryFn: ({ signal }) => fetchAdminFeedbackDetails(selectedId!, signal),
    enabled: canView && Boolean(selectedId),
  });
  const pageData = feedbackQuery.data;
  const visiblePageData = filterValidationMessage ? undefined : pageData;
  const visibleFeedbackItems = useMemo(() => visiblePageData?.items ?? [], [visiblePageData]);
  const isFeedbackRefreshing = feedbackQuery.isFetching && Boolean(pageData);
  const isFeedbackFetching = feedbackQuery.isFetching;
  const isInitialFeedbackLoading = feedbackQuery.isFetching && !pageData;
  const isFeedbackSelectionLocked = isInitialFeedbackLoading || feedbackQuery.isPlaceholderData;
  const areFeedbackFiltersLocked = isInitialFeedbackLoading;
  const queueRefreshLabel = feedbackQuery.isPlaceholderData
    ? text.applyingFilters
    : text.refreshing;
  const isDetailsFetching = detailsQuery.isFetching;
  const visibleFeedbackIds = useMemo(
    () => new Set(visibleFeedbackItems.map((item) => item.id)),
    [visibleFeedbackItems]
  );
  const activeFilters = useMemo<ActiveFilter[]>(
    () =>
      [
        status !== "All"
          ? { id: "status", label: `${text.status}: ${text.statusOptions[status]}` }
          : null,
        priority !== "All"
          ? { id: "priority", label: `${text.priority}: ${text.priorityOptions[priority]}` }
          : null,
        type !== "All" ? { id: "type", label: `${text.type}: ${text.typeOptions[type]}` } : null,
        lookupValue.trim()
          ? { id: "lookup", label: `${text.lookupOptions[lookupField]}: ${lookupValue.trim()}` }
          : null,
        category.trim() ? { id: "category", label: `${text.category}: ${category.trim()}` } : null,
        platform.trim() ? { id: "platform", label: `${text.platform}: ${platform.trim()}` } : null,
        fromUtc ? { id: "fromUtc", label: `${text.from}: ${fromUtc}` } : null,
        toUtc ? { id: "toUtc", label: `${text.to}: ${toUtc}` } : null,
      ].filter((filter): filter is ActiveFilter => Boolean(filter)),
    [category, fromUtc, lookupField, lookupValue, platform, priority, status, text, toUtc, type]
  );
  const activeAdvancedFilters = useMemo(
    () =>
      activeFilters.filter(
        (filter) =>
          filter.id === "category" ||
          filter.id === "platform" ||
          filter.id === "fromUtc" ||
          filter.id === "toUtc"
      ),
    [activeFilters]
  );
  const advancedFilterCount = activeAdvancedFilters.length;
  const firstVisibleResult = visibleFeedbackItems.length > 0 ? page * PAGE_SIZE + 1 : 0;
  const lastVisibleResult = firstVisibleResult + Math.max(visibleFeedbackItems.length - 1, 0);
  const hasFeedbackResults = (visiblePageData?.totalCount ?? 0) > 0;
  const isFeedbackPageOutOfRange =
    hasFeedbackResults && visibleFeedbackItems.length === 0 && page > 0;
  const queuePagePosition =
    visiblePageData && !isFeedbackPageOutOfRange
      ? text.pagePosition(
          page + 1,
          firstVisibleResult,
          lastVisibleResult,
          visiblePageData.totalCount
        )
      : "";
  const shouldShowFeedbackPager =
    hasFeedbackResults &&
    (visibleFeedbackItems.length > 0 || page > 0 || Boolean(visiblePageData?.hasMore));

  const clearFeedbackSelection = useCallback(() => {
    setSelectedId(null);
    setHasUnsavedDetailsChanges(false);
  }, []);

  const requestDiscardOrRun = useCallback(
    (action: () => void) => {
      if (hasUnsavedDetailsChanges) {
        setPendingDiscardAction(() => action);
        return;
      }

      action();
    },
    [hasUnsavedDetailsChanges]
  );

  const applyFeedbackFilterChange = useCallback(
    (change: () => void) => {
      requestDiscardOrRun(() => {
        clearFeedbackSelection();
        change();
      });
    },
    [clearFeedbackSelection, requestDiscardOrRun]
  );

  const confirmDiscardChanges = useCallback(() => {
    const action = pendingDiscardAction;
    setPendingDiscardAction(null);
    setHasUnsavedDetailsChanges(false);
    action?.();
  }, [pendingDiscardAction]);

  const resetFilters = useCallback(() => {
    setStatus("All");
    setPriority("All");
    setType("All");
    setCategory("");
    setPlatform("");
    setLookupField("userId");
    setLookupValue("");
    setFromUtc("");
    setToUtc("");
    setAreAdvancedFiltersOpen(false);
    setPage(0);
    clearFeedbackSelection();
  }, [clearFeedbackSelection]);

  const requestResetFilters = useCallback(() => {
    requestDiscardOrRun(resetFilters);
  }, [requestDiscardOrRun, resetFilters]);

  const removeActiveFilter = useCallback((filterId: ActiveFilterId) => {
    switch (filterId) {
      case "status":
        setStatus("All");
        break;
      case "priority":
        setPriority("All");
        break;
      case "type":
        setType("All");
        break;
      case "lookup":
        setLookupValue("");
        break;
      case "category":
        setCategory("");
        break;
      case "platform":
        setPlatform("");
        break;
      case "fromUtc":
        setFromUtc("");
        break;
      case "toUtc":
        setToUtc("");
        break;
    }

    setPage(0);
  }, []);

  const applyRelatedFeedbackFilter = useCallback(
    (field: LookupField, value: string) => {
      if (!value) {
        return;
      }

      setStatus("All");
      setPriority("All");
      setType("All");
      setCategory("");
      setPlatform("");
      setLookupField(field);
      setLookupValue(value);
      setFromUtc("");
      setToUtc("");
      setAreAdvancedFiltersOpen(false);
      setPage(0);
      clearFeedbackSelection();
    },
    [clearFeedbackSelection]
  );

  const requestRelatedFeedbackFilter = useCallback(
    (field: LookupField, value: string) => {
      requestDiscardOrRun(() => applyRelatedFeedbackFilter(field, value));
    },
    [applyRelatedFeedbackFilter, requestDiscardOrRun]
  );

  useEffect(() => {
    if (
      !visiblePageData ||
      feedbackQuery.isPlaceholderData ||
      !selectedId ||
      visibleFeedbackIds.has(selectedId) ||
      hasUnsavedDetailsChanges
    ) {
      return;
    }

    let isActive = true;
    queueMicrotask(() => {
      if (isActive) {
        clearFeedbackSelection();
      }
    });

    return () => {
      isActive = false;
    };
  }, [
    clearFeedbackSelection,
    feedbackQuery.isPlaceholderData,
    hasUnsavedDetailsChanges,
    selectedId,
    visibleFeedbackIds,
    visiblePageData,
  ]);

  const requestFeedbackSelection = useCallback(
    (feedbackId: string) => {
      if (feedbackId === selectedId) {
        return;
      }

      requestDiscardOrRun(() => {
        clearFeedbackSelection();
        setSelectedId(feedbackId);
      });
    },
    [clearFeedbackSelection, requestDiscardOrRun, selectedId]
  );

  const requestCloseSelection = useCallback(() => {
    requestDiscardOrRun(clearFeedbackSelection);
  }, [clearFeedbackSelection, requestDiscardOrRun]);

  const relatedFeedbackActions = useMemo<RelatedFeedbackAction[]>(() => {
    const details = detailsQuery.data;
    if (!details) {
      return [];
    }

    const userId = details.userId;
    const generationId = details.generation?.generationId;
    const templateId = details.generation?.templateId;

    return [
      userId
        ? {
            id: "user" as const,
            label: text.relatedUserFeedback,
            onClick: () => requestRelatedFeedbackFilter("userId", userId),
          }
        : null,
      generationId
        ? {
            id: "generation" as const,
            label: text.relatedGenerationFeedback,
            onClick: () => requestRelatedFeedbackFilter("generationId", generationId),
          }
        : null,
      templateId
        ? {
            id: "template" as const,
            label: text.relatedTemplateFeedback,
            onClick: () => requestRelatedFeedbackFilter("templateId", templateId),
          }
        : null,
    ].filter((action): action is RelatedFeedbackAction => Boolean(action));
  }, [detailsQuery.data, requestRelatedFeedbackFilter, text]);

  useEffect(() => {
    if (!selectedId || typeof window === "undefined") {
      lastMobileSelectionRef.current = null;
      return;
    }

    if (lastMobileSelectionRef.current === selectedId) {
      return;
    }

    const mobileMediaQuery = window.matchMedia("(max-width: 1280px)");
    if (!mobileMediaQuery.matches) {
      return;
    }

    const inspector = inspectorRef.current;
    if (!inspector) {
      return;
    }

    lastMobileSelectionRef.current = selectedId;
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    inspector.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "start" });
    const timeoutId = window.setTimeout(
      () => inspector.focus({ preventScroll: true }),
      reduceMotion ? 0 : 250
    );

    return () => window.clearTimeout(timeoutId);
  }, [selectedId]);

  function requestFeedbackPageChange(nextPage: number) {
    if (isFeedbackFetching || nextPage < 0) {
      return;
    }

    if (nextPage > page && !visiblePageData?.hasMore) {
      return;
    }

    requestDiscardOrRun(() => {
      clearFeedbackSelection();
      setPage(nextPage);
    });
  }

  function requestPreviousFeedbackPage() {
    const lastPage = Math.max(0, Math.ceil((visiblePageData?.totalCount ?? 0) / PAGE_SIZE) - 1);
    requestFeedbackPageChange(Math.max(0, Math.min(page - 1, lastPage)));
  }

  function requestFeedbackRetry() {
    if (isFeedbackFetching) {
      return;
    }

    void feedbackQuery.refetch().catch(() => undefined);
  }

  function requestDetailsRetry() {
    if (isDetailsFetching) {
      return;
    }

    void detailsQuery.refetch().catch(() => undefined);
  }

  const notify = useCallback((message: string, type: FeedbackToast["type"]) => {
    setToast({ message, type });
  }, []);

  if (!canView) {
    return (
      <main className={styles.page}>
        <AdminStateCard title={text.loading} />
      </main>
    );
  }

  return (
    <main className={styles.page}>
      <AdminCard title={text.filters} className={styles.filtersCard} padding="md">
        <div className={styles.filterTabs} role="group" aria-label={text.status}>
          {statusOptions.map((option) => (
            <button
              key={option}
              type="button"
              className={status === option ? styles.filterTabActive : styles.filterTab}
              aria-pressed={status === option}
              disabled={areFeedbackFiltersLocked}
              onClick={() =>
                applyFeedbackFilterChange(() => {
                  setStatus(option);
                  setPage(0);
                })
              }
            >
              {text.statusOptions[option]}
            </button>
          ))}
        </div>
        <div className={styles.filterBar}>
          <FeedbackSelectField
            label={text.priority}
            value={priority}
            options={priorityOptions.map((option) => ({
              value: option,
              label: text.priorityOptions[option],
            }))}
            disabled={areFeedbackFiltersLocked}
            onChange={(value) =>
              applyFeedbackFilterChange(() => {
                setPriority(value as FeedbackPriority | "All");
                setPage(0);
              })
            }
          />
          <FeedbackSelectField
            label={text.type}
            value={type}
            options={typeOptions.map((option) => ({
              value: option,
              label: text.typeOptions[option],
            }))}
            disabled={areFeedbackFiltersLocked}
            onChange={(value) =>
              applyFeedbackFilterChange(() => {
                setType(value as FeedbackType | "All");
                setPage(0);
              })
            }
          />
          <FeedbackSelectField
            label={text.lookupField}
            value={lookupField}
            options={Object.entries(text.lookupOptions).map(([value, label]) => ({ value, label }))}
            disabled={areFeedbackFiltersLocked}
            onChange={(value) =>
              applyFeedbackFilterChange(() => {
                setLookupField(value as LookupField);
                setLookupValue("");
                setPage(0);
              })
            }
          />
          <FeedbackTextField
            label={text.lookupOptions[lookupField]}
            value={lookupValue}
            maxLength={ADMIN_FEEDBACK_LOOKUP_ID_MAX_LENGTH}
            invalid={isLookupValueInvalid}
            describedBy={isLookupValueInvalid ? lookupValidationId : undefined}
            disabled={areFeedbackFiltersLocked}
            placeholder={text.lookupPlaceholder(text.lookupOptions[lookupField])}
            onChange={(value) =>
              applyFeedbackFilterChange(() => {
                setLookupValue(value);
                setPage(0);
              })
            }
          />
        </div>
        {isDateRangeInvalid ? (
          <p id={dateRangeValidationId} className={styles.filterValidation} role="alert">
            {text.invalidDateRange}
          </p>
        ) : null}
        {isLookupValueInvalid ? (
          <p id={lookupValidationId} className={styles.filterValidation} role="alert">
            {text.invalidLookupValue}
          </p>
        ) : null}
        <div className={styles.filterFooter}>
          <Button
            variant="ghost"
            size="sm"
            disabled={areFeedbackFiltersLocked}
            aria-expanded={areAdvancedFiltersOpen}
            aria-controls="feedback-advanced-filters"
            onClick={() => setAreAdvancedFiltersOpen((isOpen) => !isOpen)}
          >
            {areAdvancedFiltersOpen
              ? text.hideAdvancedFilters
              : text.advancedFiltersWithCount(advancedFilterCount)}
          </Button>
          {activeFilters.length > 0 ? (
            <Button
              variant="ghost"
              size="sm"
              disabled={areFeedbackFiltersLocked}
              onClick={requestResetFilters}
            >
              {text.resetFilters}
            </Button>
          ) : null}
        </div>
        {areAdvancedFiltersOpen ? (
          <div id="feedback-advanced-filters" className={styles.advancedFilterBar}>
            <FeedbackTextField
              label={text.from}
              value={fromUtc}
              type="date"
              max={toUtc || undefined}
              invalid={isDateRangeInvalid}
              describedBy={isDateRangeInvalid ? dateRangeValidationId : undefined}
              disabled={areFeedbackFiltersLocked}
              onChange={(value) =>
                applyFeedbackFilterChange(() => {
                  setFromUtc(value);
                  setPage(0);
                })
              }
            />
            <FeedbackTextField
              label={text.to}
              value={toUtc}
              type="date"
              min={fromUtc || undefined}
              invalid={isDateRangeInvalid}
              describedBy={isDateRangeInvalid ? dateRangeValidationId : undefined}
              disabled={areFeedbackFiltersLocked}
              onChange={(value) =>
                applyFeedbackFilterChange(() => {
                  setToUtc(value);
                  setPage(0);
                })
              }
            />
            <FeedbackTextField
              label={text.category}
              value={category}
              maxLength={ADMIN_FEEDBACK_CATEGORY_FILTER_MAX_LENGTH}
              disabled={areFeedbackFiltersLocked}
              onChange={(value) =>
                applyFeedbackFilterChange(() => {
                  setCategory(value);
                  setPage(0);
                })
              }
            />
            <FeedbackTextField
              label={text.platform}
              value={platform}
              maxLength={ADMIN_FEEDBACK_PLATFORM_FILTER_MAX_LENGTH}
              disabled={areFeedbackFiltersLocked}
              onChange={(value) =>
                applyFeedbackFilterChange(() => {
                  setPlatform(value);
                  setPage(0);
                })
              }
            />
          </div>
        ) : null}
        {activeAdvancedFilters.length > 0 ? (
          <div className={styles.activeFilters} aria-label={text.filters}>
            {activeAdvancedFilters.map((filter) => (
              <button
                key={filter.id}
                className={styles.filterChip}
                type="button"
                disabled={areFeedbackFiltersLocked}
                aria-label={text.removeFilter(filter.label)}
                onClick={() => applyFeedbackFilterChange(() => removeActiveFilter(filter.id))}
              >
                <span>{filter.label}</span>
                <CancelCircleIcon aria-hidden="true" className={styles.filterChipIcon} />
              </button>
            ))}
          </div>
        ) : null}
      </AdminCard>

      <div className={styles.workspace}>
        <AdminCard
          className={styles.queueCard}
          title={text.queue}
          action={
            <div className={styles.queueHeadingMeta}>
              <span className={styles.pagerStatus}>{queuePagePosition}</span>
              {isFeedbackRefreshing ? (
                <span className={styles.refreshingLabel} role="status">
                  {queueRefreshLabel}
                </span>
              ) : null}
              <Button
                variant="ghost"
                size="sm"
                disabled={isFeedbackFetching}
                onClick={requestFeedbackRetry}
              >
                {text.refresh}
              </Button>
            </div>
          }
        >
          {filterValidationMessage ? (
            <AdminStateCard tone="warning" title={filterValidationMessage} />
          ) : isInitialFeedbackLoading ? (
            <AdminStateCard tone="info" title={text.loading} />
          ) : feedbackQuery.isError && !visiblePageData ? (
            <AdminStateCard
              tone="danger"
              title={text.error}
              description={getAdminErrorMessage(feedbackQuery.error, text.error)}
              action={
                <Button
                  variant="secondary"
                  size="sm"
                  disabled={isFeedbackFetching}
                  onClick={requestFeedbackRetry}
                >
                  {text.retry}
                </Button>
              }
            />
          ) : (
            <>
              {feedbackQuery.isError && visiblePageData ? (
                <div className={styles.queueRefreshError} role="alert">
                  <span>{text.queueRefreshError}</span>
                  <Button
                    variant="ghost"
                    size="sm"
                    disabled={isFeedbackFetching}
                    onClick={requestFeedbackRetry}
                  >
                    {text.retry}
                  </Button>
                </div>
              ) : null}
              {visibleFeedbackItems.length === 0 ? (
                <AdminStateCard
                  tone="info"
                  title={text.empty}
                  description={activeFilters.length > 0 ? text.emptyFilteredDescription : undefined}
                  action={
                    activeFilters.length > 0 ? (
                      <Button variant="secondary" size="sm" onClick={requestResetFilters}>
                        {text.resetFilters}
                      </Button>
                    ) : undefined
                  }
                />
              ) : (
                <FeedbackQueue
                  items={visibleFeedbackItems}
                  selectedId={selectedId}
                  locale={locale}
                  text={text}
                  disabled={isFeedbackSelectionLocked}
                  isBusy={isFeedbackRefreshing}
                  onSelect={requestFeedbackSelection}
                />
              )}
              {shouldShowFeedbackPager ? (
                <div className={styles.queueFooter}>
                  <div className={styles.queueFooterMeta}>
                    <span className={styles.queueMeta}>
                      {visiblePageData
                        ? `${text.updatedAt}: ${formatDateTime(visiblePageData.generatedAtUtc, locale)}`
                        : ""}
                    </span>
                  </div>
                  <div className={styles.pagerActions}>
                    <button
                      className={styles.pagerButton}
                      type="button"
                      disabled={page === 0 || isFeedbackFetching}
                      aria-label={text.previousPageLabel}
                      title={text.previousPageLabel}
                      onClick={requestPreviousFeedbackPage}
                    >
                      <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />
                    </button>
                    <button
                      className={styles.pagerButton}
                      type="button"
                      disabled={!visiblePageData?.hasMore || isFeedbackFetching}
                      aria-label={text.nextPageLabel}
                      title={text.nextPageLabel}
                      onClick={() => requestFeedbackPageChange(page + 1)}
                    >
                      <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
                    </button>
                  </div>
                </div>
              ) : null}
            </>
          )}
        </AdminCard>

        <div
          ref={inspectorRef}
          id="feedback-inspector"
          className={styles.inspectorSlot}
          tabIndex={-1}
        >
          {detailsQuery.data ? (
            <DetailsPanel
              key={[
                detailsQuery.data.id,
                detailsQuery.data.status,
                detailsQuery.data.priority,
                detailsQuery.data.reviewedAtUtc ?? "",
                detailsQuery.data.adminNote ?? "",
                detailsQuery.data.refundUnavailableReason ?? "",
              ].join(":")}
              details={detailsQuery.data}
              isDetailsFetching={isDetailsFetching}
              detailsRefreshError={
                detailsQuery.isError
                  ? getAdminErrorMessage(detailsQuery.error, text.detailsError)
                  : null
              }
              canViewUserProfile={canViewUserProfile}
              locale={locale}
              onNotify={notify}
              onDismiss={requestCloseSelection}
              onDraftStateChange={setHasUnsavedDetailsChanges}
              onRetryDetails={requestDetailsRetry}
              relatedFeedbackActions={relatedFeedbackActions}
            />
          ) : selectedId && detailsQuery.isLoading ? (
            <AdminCard
              title={text.selectedFeedback}
              className={`${styles.inspectorCard} ${styles.inspectorStateCard}`}
            >
              <AdminStateCard tone="info" title={text.detailsLoading} />
            </AdminCard>
          ) : selectedId && detailsQuery.isError ? (
            <AdminCard
              title={text.selectedFeedback}
              className={`${styles.inspectorCard} ${styles.inspectorStateCard}`}
            >
              <AdminStateCard
                tone="danger"
                title={text.detailsError}
                description={getAdminErrorMessage(detailsQuery.error, text.detailsError)}
                action={
                  <Button
                    variant="secondary"
                    size="sm"
                    disabled={isDetailsFetching}
                    onClick={requestDetailsRetry}
                  >
                    {text.retry}
                  </Button>
                }
              />
            </AdminCard>
          ) : (
            <AdminCard
              title={text.selectedFeedback}
              className={`${styles.inspectorCard} ${styles.inspectorStateCard}`}
            >
              <AdminStateCard tone="info" title={text.emptySelection} />
            </AdminCard>
          )}
        </div>
      </div>
      <ConfirmationDialog
        open={Boolean(pendingDiscardAction)}
        title={text.discardChangesTitle}
        description={text.discardChangesDescription}
        confirmLabel={text.discardChanges}
        cancelLabel={text.cancel}
        tone="danger"
        onCancel={() => setPendingDiscardAction(null)}
        onConfirm={confirmDiscardChanges}
      />
      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </main>
  );
}
