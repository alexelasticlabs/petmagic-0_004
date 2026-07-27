import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const pagePath = fileURLToPath(new URL("./audit-events-page.tsx", import.meta.url));
const stylesPath = fileURLToPath(new URL("./audit-events-page.module.css", import.meta.url));
const routePath = fileURLToPath(new URL("../app/[locale]/audit/page.tsx", import.meta.url));

describe("audit-events-page production contract", () => {
  it("uses the Admin-only server contracts with independent list and detail queries", () => {
    const source = readFileSync(pagePath, "utf8");

    expect(source).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');
    expect(source).toContain("fetchAdminAuditEvents(query, signal)");
    expect(source).toContain('fetchAdminAuditEvent(activeSelectedEventId ?? "", signal)');
    expect(source).toContain("placeholderData: keepPreviousData");
    expect(source).toContain("enabled: canViewAudit && Boolean(activeSelectedEventId)");
  });

  it("keeps persisted audit context sanitized and list data intentionally compact", () => {
    const source = readFileSync(pagePath, "utf8");

    expect(source).toContain("sanitizeSensitiveMultilineText(detail.oldValue, 2000)");
    expect(source).toContain("sanitizeSensitiveMultilineText(detail.newValue, 2000)");
    expect(source).toContain("sanitizeSensitiveMultilineText(detail.details, 3000)");
    expect(source).toContain("formatAuditIdentity");
    expect(source).not.toContain("dangerouslySetInnerHTML");
  });

  it("provides explicit loading, stale, error, empty, retry, and pagination states", () => {
    const source = readFileSync(pagePath, "utf8");

    expect(source).toContain("isInitialLoading");
    expect(source).toContain("isStaleError");
    expect(source).toContain("text.emptyTitle");
    expect(source).toContain("detailQuery.isError");
    expect(source).toContain("eventsQuery.data?.hasMore");
    expect(source).toContain("aria-busy={eventsQuery.isFetching}");
  });

  it("uses a desktop inspector and accessible mobile drawer without nested cards", () => {
    const source = readFileSync(pagePath, "utf8");
    const css = readFileSync(stylesPath, "utf8");

    expect(source).toContain('id="audit-event-inspector"');
    expect(source).toContain('aria-controls="audit-event-inspector"');
    expect(source).toContain('event.key === "Escape"');
    expect(source).toContain("window.matchMedia(INSPECTOR_DRAWER_QUERY)");
    expect(source).toContain("useSearchParams()");
    expect(source).toContain("useAdminUrlStateSyncGuard({");
    expect(source).toContain("setPeriod(nextPeriod)");
    expect(source).toContain("setSelectedEventId(nextEventId)");
    expect(source).toContain("consumeUrlStateApplication()");
    expect(source).toContain("router.replace(nextSearch ? `${pathname}?${nextSearch}` : pathname");
    expect(source).toContain('setOptional("event", selectedEventId ?? "")');
    expect(source).toContain("const closeInspector = useCallback(() => {");
    expect(source).toContain("setSelectedEventId(null);");
    expect(source).toContain("onClick={closeInspector}");
    expect(source).toContain("closeInspector();");
    expect(source).toContain('event.key !== "Tab"');
    expect(source).toContain('role={isInspectorDialogOpen ? "dialog" : undefined}');
    expect(source).toContain("aria-modal={isInspectorDialogOpen ? true : undefined}");
    expect(source).toContain("inert={isInspectorDialogOpen ? true : undefined}");
    expect(source).toContain(
      "inert={isInspectorDrawerMode && !isInspectorOpen ? true : undefined}"
    );
    expect(css).toContain(".inspector {");
    expect(css).toContain("position: sticky;");
    expect(css).toContain("@media (max-width: 900px)");
    expect(css).toContain("position: fixed;");
    expect(css).toContain("@media (prefers-reduced-motion: reduce)");
    expect(source).not.toContain("<AdminCard\n          title={text.detailsTitle}");
  });

  it("labels audit deep links for each operational destination", () => {
    const source = readFileSync(pagePath, "utf8");

    expect(source).toContain("user: text.openUser");
    expect(source).toContain("support: text.openSupport");
    expect(source).toContain("economy: text.openEconomy");
    expect(source).toContain("promo: text.openPromoCodes");
    expect(source).toContain("deepLinkLabels[deepLink.kind]");
  });

  it("registers the localized app route instead of an isolated prototype", () => {
    const route = readFileSync(routePath, "utf8");

    expect(route).toContain('import { AuditEventsPage } from "@/components/audit-events-page";');
    expect(route).toContain("if (!isLocale(locale))");
    expect(route).toContain("<AuditEventsPage locale={locale} />");
  });
});
