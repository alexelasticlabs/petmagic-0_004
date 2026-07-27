"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { type FormEvent, useCallback, useEffect, useMemo, useRef, useState } from "react";

import { ClockIcon } from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminMetricStrip,
  AdminPage,
  AdminPageHero,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { useAdminUrlStateSyncGuard } from "@/components/admin/use-admin-url-state-sync-guard";
import {
  getAuditEventsPageText,
  type AuditCategoryFilter,
  type AuditPeriod,
} from "@/components/audit-events-page.content";
import {
  type AuditEventDeepLink,
  formatAuditIdentity,
  getAuditEventDeepLink,
  getAuditEventPresentation,
  getAuditPeriodRange,
} from "@/components/audit-events-page.helpers";
import styles from "@/components/audit-events-page.module.css";
import { Button } from "@/components/ui/button";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminAuditEvent,
  fetchAdminAuditEvents,
  type AdminAuditCategory,
  type AdminAuditEventDetail,
  type AdminAuditEventListItem,
  useAuthSession,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveMultilineText, sanitizeSensitiveText } from "@/lib/sensitive-display";

type AuditEventsPageProps = {
  locale: Locale;
};

const PAGE_SIZE = 25;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const INSPECTOR_DRAWER_QUERY = "(max-width: 900px)";
const FOCUSABLE_SELECTOR =
  'a[href], button:not(:disabled), textarea:not(:disabled), input:not(:disabled), select:not(:disabled), [tabindex]:not([tabindex="-1"])';
const categoryOrder: readonly AdminAuditCategory[] = [
  "identity",
  "economy",
  "content",
  "support",
  "gamification",
  "system",
];

function readAuditPeriod(value: string | null): AuditPeriod {
  return value === "24h" || value === "30d" ? value : "7d";
}

function readAuditCategory(value: string | null): AuditCategoryFilter {
  return value === "all" || categoryOrder.includes(value as AdminAuditCategory)
    ? (value as AuditCategoryFilter)
    : "all";
}

function readAuditPageIndex(value: string | null): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed - 1 : 0;
}

function readAuditUuid(value: string | null): string {
  const normalized = value?.trim().toLowerCase() ?? "";
  return UUID_PATTERN.test(normalized) ? normalized : "";
}

function formatDateTime(value: string | null | undefined, locale: Locale) {
  if (!value) {
    return "—";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "—";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-BY" : "en-US", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function formatNumber(value: number | undefined, locale: Locale) {
  return value === undefined
    ? "—"
    : new Intl.NumberFormat(locale === "ru" ? "ru-BY" : "en-US").format(value);
}

function categoryTone(category: AdminAuditCategory) {
  const tones: Record<
    AdminAuditCategory,
    "primary" | "info" | "success" | "warning" | "magenta" | "neutral"
  > = {
    identity: "primary",
    economy: "success",
    content: "magenta",
    support: "info",
    gamification: "warning",
    system: "neutral",
  };

  return tones[category];
}

function AuditEventDetails({ detail, locale }: { detail: AdminAuditEventDetail; locale: Locale }) {
  const text = getAuditEventsPageText(locale);
  const presentation = getAuditEventPresentation(detail, locale);
  const deepLink = getAuditEventDeepLink(detail, locale);
  const deepLinkLabels: Record<AuditEventDeepLink["kind"], string> = {
    user: text.openUser,
    support: text.openSupport,
    economy: text.openEconomy,
    promo: text.openPromoCodes,
  };
  const [copyStatus, setCopyStatus] = useState<"idle" | "copied" | "failed">("idle");

  useEffect(() => {
    if (copyStatus === "idle") {
      return;
    }

    const timeoutId = window.setTimeout(() => setCopyStatus("idle"), 2200);
    return () => window.clearTimeout(timeoutId);
  }, [copyStatus]);

  async function copyCorrelationId() {
    if (!detail.correlationId) {
      return;
    }

    try {
      await navigator.clipboard.writeText(detail.correlationId);
      setCopyStatus("copied");
    } catch {
      setCopyStatus("failed");
    }
  }

  const actor = formatAuditIdentity(
    {
      userId: detail.actorUserId,
      displayName: detail.actorDisplayName,
      email: detail.actorEmail,
    },
    detail.actorUserId ? text.unknownActor : text.systemActor
  );
  const subject = formatAuditIdentity(
    {
      userId: detail.subjectUserId,
      displayName: detail.subjectDisplayName,
      email: detail.subjectEmail,
    },
    text.noTarget
  );

  return (
    <div className={styles.detailBody}>
      <div className={styles.detailLead}>
        <AdminBadge tone={categoryTone(detail.category)}>
          {text.categories[detail.category]}
        </AdminBadge>
        <h3>{presentation.title}</h3>
        <code>{presentation.actionCode}</code>
      </div>

      <section className={styles.detailSection}>
        <h4>{text.whoAndWhen}</h4>
        <dl className={styles.definitionList}>
          <div>
            <dt>{text.eventColumns.actor}</dt>
            <dd>{actor}</dd>
          </div>
          <div>
            <dt>{text.actorRole}</dt>
            <dd>{sanitizeSensitiveText(detail.actorRole, 48)}</dd>
          </div>
          <div>
            <dt>{text.occurredAt}</dt>
            <dd>{formatDateTime(detail.occurredAtUtc, locale)}</dd>
          </div>
        </dl>
      </section>

      <section className={styles.detailSection}>
        <h4>{text.object}</h4>
        <dl className={styles.definitionList}>
          <div>
            <dt>{text.object}</dt>
            <dd>{presentation.target}</dd>
          </div>
          {detail.subjectUserId ? (
            <div>
              <dt>{text.subjectUser}</dt>
              <dd>{subject}</dd>
            </div>
          ) : null}
        </dl>
        {deepLink ? (
          <Link className={styles.deepLink} href={deepLink.href}>
            {deepLinkLabels[deepLink.kind]}
            <span aria-hidden="true">↗</span>
          </Link>
        ) : null}
      </section>

      <section className={styles.detailSection}>
        <h4>{text.change}</h4>
        <div className={styles.changeGrid}>
          <div>
            <span>{text.before}</span>
            <pre>{sanitizeSensitiveMultilineText(detail.oldValue, 2000)}</pre>
          </div>
          <div>
            <span>{text.after}</span>
            <pre>{sanitizeSensitiveMultilineText(detail.newValue, 2000)}</pre>
          </div>
        </div>
      </section>

      <section className={styles.detailSection}>
        <h4>{text.reason}</h4>
        <p className={styles.detailText}>{sanitizeSensitiveMultilineText(detail.details, 3000)}</p>
      </section>

      {detail.correlationId ? (
        <section className={styles.detailSection}>
          <h4>{text.correlationId}</h4>
          <div className={styles.copyRow}>
            <code>{sanitizeSensitiveText(detail.correlationId, 128)}</code>
            <Button size="sm" variant="ghost" onClick={() => void copyCorrelationId()}>
              {text.copyCorrelationId}
            </Button>
          </div>
          <span className={styles.copyStatus} role="status" aria-live="polite">
            {copyStatus === "copied" ? text.copied : copyStatus === "failed" ? text.copyFailed : ""}
          </span>
        </section>
      ) : null}

      <details className={styles.technicalDetails}>
        <summary>{text.technicalContext}</summary>
        <dl className={styles.definitionList}>
          <div>
            <dt>{text.ipAddress}</dt>
            <dd>{sanitizeSensitiveText(detail.ipAddress, 96)}</dd>
          </div>
          <div>
            <dt>{text.userAgent}</dt>
            <dd>{sanitizeSensitiveText(detail.userAgent, 320)}</dd>
          </div>
          <div>
            <dt>{text.createdAt}</dt>
            <dd>{formatDateTime(detail.createdAtUtc, locale)}</dd>
          </div>
          <div>
            <dt>ID</dt>
            <dd className={styles.mono}>{sanitizeSensitiveText(detail.auditEventId, 64)}</dd>
          </div>
        </dl>
      </details>
    </div>
  );
}

function AuditEventRow({
  event,
  locale,
  selected,
  onSelect,
}: {
  event: AdminAuditEventListItem;
  locale: Locale;
  selected: boolean;
  onSelect: (trigger: HTMLButtonElement) => void;
}) {
  const text = getAuditEventsPageText(locale);
  const presentation = getAuditEventPresentation(event, locale);
  const actor = formatAuditIdentity(
    {
      userId: event.actorUserId,
      displayName: event.actorDisplayName,
      email: event.actorEmail,
    },
    event.actorUserId ? text.unknownActor : text.systemActor
  );

  return (
    <button
      type="button"
      className={styles.eventRow}
      data-selected={selected || undefined}
      aria-pressed={selected}
      aria-controls="audit-event-inspector"
      onClick={(clickEvent) => onSelect(clickEvent.currentTarget)}
    >
      <time dateTime={event.occurredAtUtc}>{formatDateTime(event.occurredAtUtc, locale)}</time>
      <span className={styles.eventSummary}>
        <strong>{presentation.title}</strong>
        <code>{presentation.actionCode}</code>
      </span>
      <span className={styles.eventActor}>{actor}</span>
      <span className={styles.eventTarget}>{presentation.target}</span>
      <AdminBadge tone={categoryTone(event.category)}>{text.categories[event.category]}</AdminBadge>
    </button>
  );
}

export function AuditEventsPage({ locale }: AuditEventsPageProps) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const session = useAuthSession();
  const canViewAudit = session?.user.roles.includes("Admin") ?? false;
  const text = useMemo(() => getAuditEventsPageText(locale), [locale]);
  const [period, setPeriod] = useState<AuditPeriod>(() =>
    readAuditPeriod(searchParams.get("period"))
  );
  const [category, setCategory] = useState<AuditCategoryFilter>(() =>
    readAuditCategory(searchParams.get("category"))
  );
  const [searchDraft, setSearchDraft] = useState(() =>
    (searchParams.get("search") ?? "").trim().slice(0, 120)
  );
  const [search, setSearch] = useState(() =>
    (searchParams.get("search") ?? "").trim().slice(0, 120)
  );
  const [actorDraft, setActorDraft] = useState(() => readAuditUuid(searchParams.get("actor")));
  const [actorUserId, setActorUserId] = useState(() => readAuditUuid(searchParams.get("actor")));
  const [actorError, setActorError] = useState<string | null>(null);
  const [pageIndex, setPageIndex] = useState(() => readAuditPageIndex(searchParams.get("page")));
  const [rangeAnchor, setRangeAnchor] = useState(() => new Date());
  const [selectedEventId, setSelectedEventId] = useState<string | null>(
    () => readAuditUuid(searchParams.get("event")) || null
  );
  const [isInspectorOpen, setIsInspectorOpen] = useState(() =>
    Boolean(readAuditUuid(searchParams.get("event")))
  );
  const [isInspectorDrawerMode, setIsInspectorDrawerMode] = useState(false);
  const inspectorRef = useRef<HTMLElement | null>(null);
  const closeInspectorRef = useRef<HTMLButtonElement | null>(null);
  const selectedTriggerRef = useRef<HTMLButtonElement | null>(null);
  const closeInspector = useCallback(() => {
    setIsInspectorOpen(false);
    setSelectedEventId(null);
  }, []);
  const currentSearchParams = searchParams.toString();
  const { consumeUrlStateApplication, markUrlStateWritten } = useAdminUrlStateSyncGuard({
    currentSearch: currentSearchParams,
    applyUrlState: (nextSearchParams) => {
      const nextPeriod = readAuditPeriod(nextSearchParams.get("period"));
      if (nextPeriod !== period) {
        setRangeAnchor(new Date());
      }
      setPeriod(nextPeriod);
      setCategory(readAuditCategory(nextSearchParams.get("category")));
      const nextSearch = (nextSearchParams.get("search") ?? "").trim().slice(0, 120);
      setSearchDraft(nextSearch);
      setSearch(nextSearch);
      const nextActor = readAuditUuid(nextSearchParams.get("actor"));
      setActorDraft(nextActor);
      setActorUserId(nextActor);
      setActorError(null);
      setPageIndex(readAuditPageIndex(nextSearchParams.get("page")));
      const nextEventId = readAuditUuid(nextSearchParams.get("event")) || null;
      setSelectedEventId(nextEventId);
      setIsInspectorOpen(Boolean(nextEventId));
    },
  });

  const range = useMemo(() => getAuditPeriodRange(period, rangeAnchor), [period, rangeAnchor]);
  const query = useMemo(
    () => ({
      skip: pageIndex * PAGE_SIZE,
      take: PAGE_SIZE,
      search: search || undefined,
      category: category === "all" ? undefined : category,
      actorUserId: actorUserId || undefined,
      fromUtc: range.fromUtc,
      toUtc: range.toUtc,
    }),
    [actorUserId, category, pageIndex, range.fromUtc, range.toUtc, search]
  );

  const eventsQuery = useQuery({
    queryKey: adminQueryKeys.auditEvents(query),
    queryFn: ({ signal }) => fetchAdminAuditEvents(query, signal),
    enabled: canViewAudit,
    placeholderData: keepPreviousData,
    staleTime: 30_000,
  });
  const events = eventsQuery.data?.items ?? [];
  const activeSelectedEventId = selectedEventId ?? events[0]?.auditEventId ?? null;
  const detailQuery = useQuery({
    queryKey: adminQueryKeys.auditEvent(activeSelectedEventId ?? "disabled"),
    queryFn: ({ signal }) => fetchAdminAuditEvent(activeSelectedEventId ?? "", signal),
    enabled: canViewAudit && Boolean(activeSelectedEventId),
    staleTime: 60_000,
  });

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  useEffect(() => {
    if (consumeUrlStateApplication()) {
      return;
    }

    const next = new URLSearchParams(searchParams.toString());
    const setOptional = (key: string, value: string, defaultValue = "") => {
      if (!value || value === defaultValue) {
        next.delete(key);
      } else {
        next.set(key, value);
      }
    };

    setOptional("period", period, "7d");
    setOptional("category", category, "all");
    setOptional("search", search);
    setOptional("actor", actorUserId);
    setOptional("page", pageIndex > 0 ? String(pageIndex + 1) : "");
    setOptional("event", selectedEventId ?? "");

    const nextSearch = next.toString();
    if (nextSearch === searchParams.toString()) {
      return;
    }

    markUrlStateWritten(nextSearch);
    router.replace(nextSearch ? `${pathname}?${nextSearch}` : pathname, { scroll: false });
  }, [
    actorUserId,
    category,
    consumeUrlStateApplication,
    markUrlStateWritten,
    pageIndex,
    pathname,
    period,
    router,
    search,
    searchParams,
    selectedEventId,
  ]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    const media = window.matchMedia(INSPECTOR_DRAWER_QUERY);
    const syncDrawerMode = () => {
      setIsInspectorDrawerMode(media.matches);
      if (!media.matches) {
        setIsInspectorOpen(false);
      }
    };

    syncDrawerMode();
    media.addEventListener("change", syncDrawerMode);
    return () => media.removeEventListener("change", syncDrawerMode);
  }, []);

  useEffect(() => {
    const inspector = inspectorRef.current;
    if (!isInspectorDrawerMode || !isInspectorOpen || !inspector) {
      return;
    }
    const focusTrapInspector: HTMLElement = inspector;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const focusCloseButton = () => closeInspectorRef.current?.focus({ preventScroll: true });
    focusCloseButton();
    const focusTimer = window.setTimeout(focusCloseButton, 200);

    function handleDrawerKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        closeInspector();
        return;
      }

      if (event.key !== "Tab") {
        return;
      }

      const focusableElements =
        focusTrapInspector.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR);
      if (focusableElements.length === 0) {
        event.preventDefault();
        focusTrapInspector.focus();
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

    document.addEventListener("keydown", handleDrawerKeyDown);
    return () => {
      window.clearTimeout(focusTimer);
      document.removeEventListener("keydown", handleDrawerKeyDown);
      document.body.style.overflow = previousOverflow;
      selectedTriggerRef.current?.focus({ preventScroll: true });
    };
  }, [closeInspector, isInspectorDrawerMode, isInspectorOpen]);

  function applyFilters(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalizedActor = actorDraft.trim().toLowerCase();
    if (normalizedActor && !UUID_PATTERN.test(normalizedActor)) {
      setActorError(text.actorInvalid);
      return;
    }

    setActorError(null);
    setSearch(searchDraft.trim().slice(0, 120));
    setActorUserId(normalizedActor);
    setPageIndex(0);
    setRangeAnchor(new Date());
  }

  function resetFilters() {
    setPeriod("7d");
    setCategory("all");
    setSearchDraft("");
    setSearch("");
    setActorDraft("");
    setActorUserId("");
    setActorError(null);
    setPageIndex(0);
    setRangeAnchor(new Date());
    setSelectedEventId(null);
    setIsInspectorOpen(false);
  }

  function selectEvent(eventId: string, trigger: HTMLButtonElement) {
    selectedTriggerRef.current = trigger;
    setSelectedEventId(eventId);
    setIsInspectorOpen(true);
  }

  const summary = eventsQuery.data?.summary;
  const totalCount = eventsQuery.data?.totalCount ?? 0;
  const totalPages = Math.max(1, Math.ceil(totalCount / PAGE_SIZE));
  const currentPage = Math.min(pageIndex + 1, totalPages);
  const isInitialLoading = eventsQuery.isPending && !eventsQuery.data;
  const isStaleError = eventsQuery.isError && Boolean(eventsQuery.data);
  const lastUpdated = eventsQuery.dataUpdatedAt
    ? formatDateTime(new Date(eventsQuery.dataUpdatedAt).toISOString(), locale)
    : null;
  const isInspectorDialogOpen = isInspectorDrawerMode && isInspectorOpen;

  return (
    <AdminPage className={styles.page}>
      <AdminPageHero
        title={text.title}
        description={text.description}
        badge={<AdminBadge tone="success">{text.accessBadge}</AdminBadge>}
        actions={
          <Button
            type="button"
            variant="secondary"
            disabled={!canViewAudit || eventsQuery.isFetching}
            onClick={() => setRangeAnchor(new Date())}
          >
            {eventsQuery.isFetching ? text.refreshing : text.refresh}
          </Button>
        }
        metaItems={lastUpdated ? [text.lastUpdated(lastUpdated)] : []}
      />

      {eventsQuery.data ? (
        <AdminMetricStrip
          items={[
            { label: text.metrics.total, value: formatNumber(summary?.totalEvents, locale) },
            { label: text.metrics.operators, value: formatNumber(summary?.uniqueActors, locale) },
            { label: text.metrics.access, value: formatNumber(summary?.accessEvents, locale) },
            { label: text.metrics.system, value: formatNumber(summary?.systemEvents, locale) },
          ]}
        />
      ) : null}

      <AdminCard
        title={text.filtersTitle}
        description={text.filtersDescription}
        className={styles.filterCard}
      >
        <form className={styles.filters} onSubmit={applyFilters} noValidate>
          <label className={styles.fieldWide}>
            <span>{text.searchLabel}</span>
            <input
              type="search"
              value={searchDraft}
              maxLength={120}
              placeholder={text.searchPlaceholder}
              onChange={(event) => setSearchDraft(event.target.value)}
            />
          </label>
          <label>
            <span>{text.actorLabel}</span>
            <input
              type="text"
              value={actorDraft}
              maxLength={36}
              placeholder={text.actorPlaceholder}
              aria-invalid={Boolean(actorError)}
              aria-describedby={actorError ? "audit-actor-error" : undefined}
              onChange={(event) => {
                setActorDraft(event.target.value);
                if (actorError) {
                  setActorError(null);
                }
              }}
            />
            {actorError ? (
              <small id="audit-actor-error" className={styles.fieldError} role="alert">
                {actorError}
              </small>
            ) : null}
          </label>
          <label>
            <span>{text.periodLabel}</span>
            <select
              value={period}
              onChange={(event) => {
                setPeriod(event.target.value as AuditPeriod);
                setPageIndex(0);
                setRangeAnchor(new Date());
              }}
            >
              {(Object.keys(text.periods) as AuditPeriod[]).map((value) => (
                <option key={value} value={value}>
                  {text.periods[value]}
                </option>
              ))}
            </select>
          </label>
          <label>
            <span>{text.categoryLabel}</span>
            <select
              value={category}
              onChange={(event) => {
                setCategory(event.target.value as AuditCategoryFilter);
                setPageIndex(0);
              }}
            >
              <option value="all">{text.categories.all}</option>
              {categoryOrder.map((value) => (
                <option key={value} value={value}>
                  {text.categories[value]}
                </option>
              ))}
            </select>
          </label>
          <div className={styles.filterActions}>
            <Button
              type="submit"
              variant="primary"
              disabled={!canViewAudit || eventsQuery.isFetching}
            >
              {text.applySearch}
            </Button>
            <Button type="button" variant="ghost" onClick={resetFilters}>
              {text.resetFilters}
            </Button>
          </div>
        </form>
      </AdminCard>

      {isStaleError ? (
        <AdminStateCard
          tone="warning"
          title={text.staleTitle}
          description={getAdminErrorMessage(eventsQuery.error, text.staleDescription)}
          action={
            <Button
              variant="secondary"
              disabled={eventsQuery.isFetching}
              onClick={() => void eventsQuery.refetch()}
            >
              {text.retry}
            </Button>
          }
        />
      ) : null}

      <div className={styles.workspace}>
        <section
          className={styles.timelinePanel}
          aria-labelledby="audit-timeline-title"
          inert={isInspectorDialogOpen ? true : undefined}
        >
          <header className={styles.panelHeader}>
            <div>
              <h2 id="audit-timeline-title">{text.eventsTitle}</h2>
              <p>{text.eventsDescription}</p>
            </div>
            <span className={styles.resultCount}>{text.resultCount(totalCount)}</span>
          </header>

          {isInitialLoading || !canViewAudit ? (
            <AdminStateCard
              tone="info"
              title={text.loadingTitle}
              description={text.loadingDescription}
            />
          ) : eventsQuery.isError && !eventsQuery.data ? (
            <AdminStateCard
              tone="danger"
              title={text.errorTitle}
              description={getAdminErrorMessage(eventsQuery.error, text.errorDescription)}
              action={
                <Button
                  variant="secondary"
                  disabled={eventsQuery.isFetching}
                  onClick={() => void eventsQuery.refetch()}
                >
                  {text.retry}
                </Button>
              }
            />
          ) : events.length === 0 ? (
            <div className={styles.emptyState}>
              <ClockIcon />
              <strong>{text.emptyTitle}</strong>
              <p>{text.emptyDescription}</p>
            </div>
          ) : (
            <>
              <div className={styles.eventHeader} aria-hidden="true">
                <span>{text.eventColumns.time}</span>
                <span>{text.eventColumns.event}</span>
                <span>{text.eventColumns.actor}</span>
                <span>{text.eventColumns.target}</span>
                <span>{text.eventColumns.category}</span>
              </div>
              <div className={styles.eventList} aria-busy={eventsQuery.isFetching}>
                {events.map((event) => (
                  <AuditEventRow
                    key={event.auditEventId}
                    event={event}
                    locale={locale}
                    selected={event.auditEventId === activeSelectedEventId}
                    onSelect={(trigger) => selectEvent(event.auditEventId, trigger)}
                  />
                ))}
              </div>
              <footer className={styles.pagination}>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={pageIndex === 0 || eventsQuery.isFetching}
                  onClick={() => setPageIndex((value) => Math.max(0, value - 1))}
                >
                  {text.previousPage}
                </Button>
                <span>{text.page(currentPage, totalPages)}</span>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={!eventsQuery.data?.hasMore || eventsQuery.isFetching}
                  onClick={() => setPageIndex((value) => value + 1)}
                >
                  {text.nextPage}
                </Button>
              </footer>
            </>
          )}
        </section>

        {isInspectorDialogOpen ? (
          <button
            type="button"
            className={styles.drawerBackdrop}
            data-open="true"
            tabIndex={-1}
            aria-label={text.closeDetails}
            onClick={closeInspector}
          />
        ) : null}
        <aside
          id="audit-event-inspector"
          ref={inspectorRef}
          className={styles.inspector}
          data-open={isInspectorDialogOpen || undefined}
          role={isInspectorDialogOpen ? "dialog" : undefined}
          aria-modal={isInspectorDialogOpen ? true : undefined}
          aria-hidden={isInspectorDrawerMode && !isInspectorOpen ? true : undefined}
          inert={isInspectorDrawerMode && !isInspectorOpen ? true : undefined}
          aria-labelledby="audit-detail-title"
          tabIndex={isInspectorDialogOpen ? -1 : undefined}
        >
          <header className={styles.inspectorHeader}>
            <div>
              <h2 id="audit-detail-title">{text.detailsTitle}</h2>
              <p>{text.detailsDescription}</p>
            </div>
            <Button
              ref={closeInspectorRef}
              size="sm"
              variant="ghost"
              className={styles.closeInspector}
              aria-label={text.closeDetails}
              onClick={closeInspector}
            >
              <span aria-hidden="true">×</span>
            </Button>
          </header>
          {!activeSelectedEventId ? (
            <div className={styles.detailEmpty}>
              <ClockIcon />
              <strong>{text.detailsEmptyTitle}</strong>
              <p>{text.detailsEmptyDescription}</p>
            </div>
          ) : detailQuery.isPending ? (
            <div className={styles.detailEmpty} role="status">
              <span className={styles.loadingDot} aria-hidden="true" />
              <strong>{text.detailsLoading}</strong>
            </div>
          ) : detailQuery.isError || !detailQuery.data ? (
            <div className={styles.detailEmpty} role="alert">
              <strong>{text.detailsError}</strong>
              <Button variant="secondary" size="sm" onClick={() => void detailQuery.refetch()}>
                {text.retry}
              </Button>
            </div>
          ) : (
            <AuditEventDetails detail={detailQuery.data} locale={locale} />
          )}
        </aside>
      </div>
    </AdminPage>
  );
}
